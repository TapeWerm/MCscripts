#!/usr/bin/env python3
"""Back up Minecraft Bedrock Edition server running in service."""

import argparse
import datetime
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
import typing
import zipfile

import toml
import systemd.journal

BACKUP_DIR = pathlib.Path.home()
BACKUP_TIME = datetime.datetime.now().astimezone()


def server_do(cmd: str) -> typing.Union[str, None, datetime.datetime]:
    """
    :param cmd: Write to SERVICE input
    :return: systemd cursor or time for server_read
    """
    if ARGS.docker:
        # Escape r'][(){}‘’:,!\"\n' for socat address specifications
        no_escape = re.sub(r"\\", r"\\\\\\\\", SERVICE)
        no_escape = re.sub(r'([][(){}‘’:,!"])', r"\\\1", no_escape)
        cmd_cursor = datetime.datetime.now().astimezone()
        subprocess.run(
            ["socat", "-", f"EXEC:docker attach -- {no_escape},pty"],
            check=True,
            input=cmd + "\n",
            stdout=subprocess.DEVNULL,
            encoding="utf-8",
        )
    else:
        journal = systemd.journal.Reader()
        journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
        journal.seek_tail()
        cmd_cursor = journal.get_previous()
        if cmd_cursor:
            cmd_cursor = cmd_cursor["__CURSOR"]
        else:
            cmd_cursor = None
        pathlib.Path("/run", SERVICE).write_text(cmd + "\n", encoding="utf-8")
    return cmd_cursor


def server_read(cmd_cursor: typing.Union[str, None, datetime.datetime]) -> str:
    """
    :param cmd_cursor: Returned by server_do
    :return: Output of SERVICE after cmd_cursor
    """
    # Wait for output
    time.sleep(1)
    if ARGS.docker:
        return subprocess.run(
            ["docker", "logs", "--since", cmd_cursor.isoformat(), SERVICE],
            check=True,
            stdout=subprocess.PIPE,
            encoding="utf-8",
        ).stdout[: -len(os.linesep)]
    journal = systemd.journal.Reader()
    journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
    if cmd_cursor:
        journal.seek_cursor(cmd_cursor)
        journal.get_next()
    return os.linesep.join([entry["MESSAGE"] for entry in journal])


PARSER = argparse.ArgumentParser(
    description="Back up Minecraft Bedrock Edition server running in service.",
    epilog="Backups are bedrock_backups/SERVER_DIR/WORLD/YYYY/MM/DD_HH-MM.zip in\
        BACKUP_DIR.",
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft bedrock edition server directory"
)
PARSER.add_argument(
    "SERVICE", type=str, help="systemd service or docker container name"
)
PARSER.add_argument(
    "-b",
    "--backup-dir",
    type=pathlib.Path,
    help="directory backups go in. defaults to ~. best on another drive",
)
PARSER.add_argument(
    "-d",
    "--docker",
    action="store_true",
    help="docker run -d -it --name SERVICE -e EULA=TRUE -p 19132:19132/udp -v\
        SERVER_DIR:/data itzg/minecraft-bedrock-server",
)
ARGS = PARSER.parse_args()

SERVER_DIR = ARGS.SERVER_DIR.resolve()
WORLD = None
with pathlib.Path(SERVER_DIR, "server.properties").open(
    "r", encoding="utf-8"
) as properties:
    for line in properties:
        if line.startswith("level-name="):
            WORLD = "=".join(line.split("=")[1:])[:-1]
            WORLD = pathlib.Path(WORLD).name
            break
if not WORLD:
    sys.exit("No level-name in server.properties")
WORLDS_DIR = pathlib.Path(SERVER_DIR, "worlds")
if not pathlib.Path(WORLDS_DIR, WORLD).is_dir():
    sys.exit(
        f"No world {WORLD} in {WORLDS_DIR}, check level-name in server.properties too"
    )
if ARGS.docker:
    TEMP_DIR = pathlib.Path("/tmp/docker_mcbe_backup", SERVER_DIR.parent.name)
else:
    TEMP_DIR = pathlib.Path("/tmp/mcbe_backup", SERVER_DIR.name)

SERVICE = ARGS.SERVICE
if ARGS.docker:
    if (
        SERVICE
        not in subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            check=True,
            stdout=subprocess.PIPE,
            encoding="utf-8",
        ).stdout.split(os.linesep)[:-1]
    ):
        sys.exit(f"Container {SERVICE} not running")
else:
    # Trim off SERVICE after last .service
    if SERVICE.endswith(".service"):
        SERVICE = SERVICE[: -len(".service")]
    if subprocess.run(
        ["systemctl", "is-active", "-q", "--", SERVICE], check=False
    ).returncode:
        sys.exit(f"Service {SERVICE} not active")
    # Trim off SERVICE before last @
    INSTANCE = SERVICE.split("@")[-1]

if ARGS.docker:
    CONFIG_FILES = (
        pathlib.Path("/etc/MCscripts/docker-mcbe-backup.toml"),
        pathlib.Path("/etc/MCscripts/docker-mcbe-backup", f"{SERVICE}.toml"),
    )
else:
    CONFIG_FILES = (
        pathlib.Path("/etc/MCscripts/mcbe-backup.toml"),
        pathlib.Path("/etc/MCscripts/mcbe-backup", f"{INSTANCE}.toml"),
    )
for config_file in CONFIG_FILES:
    if config_file.is_file():
        config = toml.load(config_file)
        if "backup_dir" in config:
            if not isinstance(config["backup_dir"], str):
                sys.exit(f"backup_dir must be TOML string, check {config_file}")
            BACKUP_DIR = pathlib.Path(config["backup_dir"]).resolve()

if ARGS.backup_dir:
    BACKUP_DIR = ARGS.backup_dir.resolve()
if ARGS.docker:
    BACKUP_DIR = pathlib.Path(
        BACKUP_DIR,
        "docker_bedrock_backups",
        SERVER_DIR.parent.name,
        WORLD,
        BACKUP_TIME.strftime("%Y"),
        BACKUP_TIME.strftime("%m"),
    )
else:
    BACKUP_DIR = pathlib.Path(
        BACKUP_DIR,
        "bedrock_backups",
        SERVER_DIR.name,
        WORLD,
        BACKUP_TIME.strftime("%Y"),
        BACKUP_TIME.strftime("%m"),
    )
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_ZIP = pathlib.Path(BACKUP_DIR, BACKUP_TIME.strftime("%d_%H-%M.zip"))

# Prepare backup
server_do("save hold")
try:
    time.sleep(1)
    query_cursor = server_do("save query")
    QUERY = server_read(query_cursor)
    timeout = datetime.datetime.now().astimezone() + datetime.timedelta(minutes=1)
    while "Data saved. Files are now ready to be copied." not in QUERY:
        if datetime.datetime.now().astimezone() >= timeout:
            sys.exit("save query timeout")
        if "A previous save has not been completed." in QUERY:
            query_cursor = server_do("save query")
        QUERY = server_read(query_cursor)
    # {WORLD}not :...:#...
    # Minecraft Bedrock Edition says file:bytes, file:bytes, ...
    # journald LineMax splits lines so delete newlines
    files = re.findall(f"{WORLD}[^:]+:[0-9]+", QUERY.replace(os.linesep, ""))

    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    # zip restores path of directory given to it (WORLD), not just the directory itself
    os.chdir(TEMP_DIR)
    try:
        shutil.rmtree(WORLD)
    except FileNotFoundError:
        pass
    try:
        for line in files:
            # Trim off line after last :
            file = pathlib.Path(":".join(line.split(":")[:-1]))
            directory = file.parent
            # Trim off line before last :
            length = int(line.split(":")[-1])
            directory.mkdir(parents=True, exist_ok=True)
            shutil.copy2(pathlib.Path(WORLDS_DIR, file), directory)
            os.truncate(file, length)
        with zipfile.ZipFile(
            BACKUP_ZIP, "w", compression=zipfile.ZIP_DEFLATED
        ) as backup_zipfile:
            for world_file in [pathlib.Path(WORLD)] + list(
                pathlib.Path(WORLD).rglob("*")
            ):
                backup_zipfile.write(world_file)
    except:
        if BACKUP_ZIP.is_file():
            BACKUP_ZIP.unlink()
        raise
    finally:
        try:
            shutil.rmtree(WORLD)
        except FileNotFoundError:
            pass
finally:
    server_do("save resume")
print(f"Backup is {BACKUP_ZIP}")
