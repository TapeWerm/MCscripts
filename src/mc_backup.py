#!/usr/bin/env python3
"""Back up Minecraft Java Edition server running in service."""

import argparse
import datetime
import os
import pathlib
import re
import subprocess
import sys
import time
import typing
import zipfile

import toml
import systemd.journal

BACKUP_DIR = pathlib.Path.home()
BACKUP_TIME = datetime.datetime.now().astimezone()


def server_do(cmd: str) -> typing.Optional[str]:
    """
    :param cmd: Write to SERVICE input
    :return: systemd cursor for server_read
    """
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


def server_read(cmd_cursor: typing.Optional[str]) -> str:
    """
    :param cmd_cursor: Returned by server_do
    :return: Output of SERVICE after cmd_cursor
    """
    # Wait for output
    time.sleep(1)
    journal = systemd.journal.Reader()
    journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
    if cmd_cursor:
        journal.seek_cursor(cmd_cursor)
        journal.get_next()
    return os.linesep.join([entry["MESSAGE"] for entry in journal])


PARSER = argparse.ArgumentParser(
    description="Back up Minecraft Java Edition server running in service.",
    epilog=(
        "Backups are java_backups/SERVER_DIR/WORLD/YYYY/MM/DD_HH-MM.zip in BACKUP_DIR."
    ),
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft java edition server directory"
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
PARSER.add_argument(
    "-b",
    "--backup-dir",
    type=pathlib.Path,
    help="directory backups go in. defaults to ~. best on another drive",
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
if not pathlib.Path(SERVER_DIR, WORLD).is_dir():
    sys.exit(
        f"No world {WORLD} in {SERVER_DIR}, check level-name in server.properties too"
    )

SERVICE = ARGS.SERVICE
# Trim off SERVICE after last .service
if SERVICE.endswith(".service"):
    SERVICE = SERVICE[: -len(".service")]
if subprocess.run(
    ["systemctl", "is-active", "-q", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")
# Trim off SERVICE before last @
INSTANCE = SERVICE.split("@")[-1]

CONFIG_FILES = (
    pathlib.Path("/etc/MCscripts/mc-backup.toml"),
    pathlib.Path("/etc/MCscripts/mc-backup", f"{INSTANCE}.toml"),
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
BACKUP_DIR = pathlib.Path(
    BACKUP_DIR,
    "java_backups",
    SERVER_DIR.name,
    WORLD,
    BACKUP_TIME.strftime("%Y"),
    BACKUP_TIME.strftime("%m"),
)
BACKUP_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_ZIP = pathlib.Path(BACKUP_DIR, BACKUP_TIME.strftime("%d_%H-%M.zip"))

# Disable autosave
server_do("save-off")
try:
    # Pause and save the server
    query_cursor = server_do("save-all flush")
    timeout = datetime.datetime.now().astimezone() + datetime.timedelta(minutes=1)
    QUERY = ""
    # Minecraft Java Edition says [HH:MM:SS] [Server thread/INFO]: Saved the game
    while "Saved the game" not in QUERY:
        if datetime.datetime.now().astimezone() >= timeout:
            sys.exit("save query timeout")
        QUERY = server_read(query_cursor)
        # Filter out chat
        QUERY = os.linesep.join(
            [line for line in QUERY.split(os.linesep) if not re.findall("<.+>", line)]
        )

    # zip restores path of directory given to it (WORLD), not just the directory itself
    os.chdir(SERVER_DIR)
    try:
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
    server_do("save-on")
print(f"Backup is {BACKUP_ZIP}")
