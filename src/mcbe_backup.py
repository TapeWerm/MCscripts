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
import zipfile

import docker
import systemd.journal

BACKUP_TIME = datetime.datetime.now().astimezone()


def server_do(cmd: str) -> datetime.datetime:
    """
    :param cmd: Write to SERVICE input
    :return: Time for server_read
    """
    if ARGS.docker:
        # Escape "][(){}‘’:,!\\\"\\n" for socat address specifications
        no_escape = re.sub(r"([][(){}‘’:,!\\\"])", r"\\\\\\\1", SERVICE)
        cmd_time = datetime.datetime.now().astimezone()
        subprocess.run(
            ["socat", f"EXEC:docker attach -- {no_escape},pty", "STDIN"],
            check=True,
            input=cmd + "\n",
            encoding="utf-8",
        )
    else:
        cmd_time = datetime.datetime.now().astimezone()
        pathlib.Path("/run", SERVICE).write_text(cmd + "\n", encoding="utf-8")
    return cmd_time


def server_read(cmd_time: datetime.datetime) -> str:
    """
    :param cmd_time: Returned by server_do
    :return: Output of SERVICE after cmd_time
    """
    # Wait for output
    time.sleep(1)
    if ARGS.docker:
        return (
            CONTAINER.logs(
                since=cmd_time.astimezone(datetime.timezone.utc).replace(tzinfo=None)
            )
            .decode("utf-8")
            .replace("\r\n", "\n")
            .rstrip("\n")
        )
    journal = systemd.journal.Reader()
    journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
    journal.seek_realtime(cmd_time)
    return os.linesep.join([x["MESSAGE"] for x in journal])


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
with pathlib.Path(SERVER_DIR, "server.properties").open(
    "r", encoding="utf-8"
) as properties:
    for line in properties:
        if line.startswith("level-name="):
            WORLD = pathlib.Path("=".join(line.split("=")[1:]).rstrip(os.linesep)).name
            break
WORLDS_DIR = pathlib.Path(SERVER_DIR, "worlds")
if not pathlib.Path(WORLDS_DIR, WORLD).is_dir():
    sys.exit(
        f"No world {WORLD} in {WORLDS_DIR}, check level-name in server.properties too"
    )
TEMP_DIR = pathlib.Path("/tmp/mcbe_backup", SERVER_DIR.name)

if ARGS.docker:
    SERVICE = ARGS.SERVICE
    CLIENT = docker.from_env()
    CONTAINER = CLIENT.containers.get("SERVICE")
    if CONTAINER.status != "running":
        sys.exit(f"Container {SERVICE} not running")
else:
    SERVICE = ARGS.SERVICE
    if SERVICE.endswith(".service"):
        SERVICE = SERVICE[: -len(".service")]
    if subprocess.run(
        ["systemctl", "is-active", "--quiet", "--", SERVICE], check=False
    ).returncode:
        sys.exit(f"Service {SERVICE} not active")

if ARGS.backup_dir:
    backup_dir = ARGS.backup_dir.resolve()
else:
    backup_dir = pathlib.Path.home()
backup_dir = pathlib.Path(
    backup_dir,
    "bedrock_backups",
    SERVER_DIR.name,
    WORLD,
    BACKUP_TIME.strftime("%Y"),
    BACKUP_TIME.strftime("%m"),
)
backup_dir.mkdir(parents=True, exist_ok=True)
BACKUP_ZIP = pathlib.Path(backup_dir, BACKUP_TIME.strftime("%d_%H-%M.zip"))

# Prepare backup
server_do("save hold")
try:
    # Wait 1 second for Minecraft Bedrock Edition command to avoid infinite loop
    # Only unplayably slow servers take more than 1 second to run a command
    time.sleep(1)
    TIMEOUT = datetime.datetime.now().astimezone() + datetime.timedelta(minutes=1)
    QUERY = ""
    # Minecraft Bedrock Edition says Data saved. Files are now ready to be copied.
    while "Data saved" not in QUERY:
        if datetime.datetime.now().astimezone() >= TIMEOUT:
            sys.exit("save query timeout")
        query_time = server_do("save query")
        QUERY = server_read(query_time)
    # {WORLD}not :...:#...
    # Minecraft Bedrock Edition says FILE:BYTES, FILE:BYTES, ...
    # journald LineMax splits lines so delete newlines
    FILES = re.findall(f"{WORLD}[^:]+:[0-9]+", QUERY.replace(os.linesep, ""))

    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    # zip restores path of directory given to it (WORLD), not just the directory itself
    os.chdir(TEMP_DIR)
    shutil.rmtree(WORLD, ignore_errors=True)
    try:
        for line in FILES:
            # Trim off line after last :
            FILE = pathlib.Path(":".join(line.split(":")[:-1]))
            DIR = FILE.parent
            # Trim off line before last :
            LENGTH = int(line.split(":")[-1])
            DIR.mkdir(parents=True, exist_ok=True)
            shutil.copy2(pathlib.Path(WORLDS_DIR, FILE), DIR)
            os.truncate(FILE, LENGTH)
        with zipfile.ZipFile(
            BACKUP_ZIP, "w", compression=zipfile.ZIP_DEFLATED
        ) as BACKUP_ZIPFILE:
            for world_file in pathlib.Path(WORLD).glob("**/*"):
                BACKUP_ZIPFILE.write(world_file)
    except:
        BACKUP_ZIP.unlink()
        raise
    finally:
        shutil.rmtree(WORLD, ignore_errors=True)
finally:
    server_do("save resume")
print(f"Backup is {BACKUP_ZIP}")
