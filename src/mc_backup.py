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
import zipfile

import systemd.journal

BACKUP_TIME = datetime.datetime.now().astimezone()


def server_do(cmd: str) -> datetime.datetime:
    """
    :param cmd: Write to SERVICE input
    :return: Time for server_read
    """
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
    journal = systemd.journal.Reader()
    journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
    journal.seek_realtime(cmd_time)
    return os.linesep.join([entry["MESSAGE"] for entry in journal])


PARSER = argparse.ArgumentParser(
    description="Back up Minecraft Java Edition server running in service.",
    epilog="Backups are java_backups/SERVER_DIR/WORLD/YYYY/MM/DD_HH-MM.zip in\
        BACKUP_DIR.",
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
with pathlib.Path(SERVER_DIR, "server.properties").open(
    "r", encoding="utf-8"
) as properties:
    for line in properties:
        if line.startswith("level-name="):
            WORLD = pathlib.Path("=".join(line.split("=")[1:]).rstrip("\n")).name
            break
if not pathlib.Path(SERVER_DIR, WORLD).is_dir():
    sys.exit(
        f"No world {WORLD} in {SERVER_DIR}, check level-name in server.properties too"
    )

SERVICE = ARGS.SERVICE
# Trim off SERVICE after last .service
if SERVICE.endswith(".service"):
    SERVICE = SERVICE[: -len(".service")]
if subprocess.run(
    ["systemctl", "is-active", "--quiet", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")

if ARGS.backup_dir:
    BACKUP_DIR = ARGS.backup_dir.resolve()
else:
    BACKUP_DIR = pathlib.Path.home()
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
    query_time = server_do("save-all flush")
    timeout = datetime.datetime.now().astimezone() + datetime.timedelta(minutes=1)
    QUERY = ""
    # Minecraft Java Edition says [HH:MM:SS] [Server thread/INFO]: Saved the game
    while "Saved the game" not in QUERY:
        if datetime.datetime.now().astimezone() >= timeout:
            sys.exit("save query timeout")
        QUERY = server_read(query_time)
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
