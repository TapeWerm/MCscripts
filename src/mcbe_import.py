#!/usr/bin/env python3
"""Import Minecraft Bedrock Edition server to ~mc/bedrock/INSTANCE."""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

ZIPS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock_zips"))

PARSER = argparse.ArgumentParser(
    description="Import Minecraft Bedrock Edition server to ~mc/bedrock/INSTANCE."
)
PARSER.add_argument(
    "IMPORT_DIR",
    type=pathlib.Path,
    metavar="SERVER_DIR",
    help="minecraft bedrock edition server directory to import",
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mcbe@MCBE")
PARSER.add_argument(
    "-n",
    "--no-update",
    action="store_true",
    help="don't update minecraft bedrock edition server",
)
PARSER.add_argument(
    "-p",
    "--preview",
    action="store_true",
    help="use preview instead of current version",
)
ARGS = PARSER.parse_args()

IMPORT_DIR = pathlib.Path(ARGS.IMPORT_DIR).resolve()

INSTANCE = ARGS.INSTANCE
if (
    INSTANCE
    != subprocess.run(
        ["systemd-escape", "--", INSTANCE],
        check=True,
        stdout=subprocess.PIPE,
        encoding="utf-8",
    ).stdout[: -len(os.linesep)]
):
    sys.exit("INSTANCE should be indentical to systemd-escape INSTANCE")
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")

if ARGS.preview:
    VERSION = "preview"
else:
    VERSION = "current"

if pathlib.Path(ZIPS_DIR, VERSION).is_symlink():
    MINECRAFT_ZIP = pathlib.Path(ZIPS_DIR, VERSION).resolve()
else:
    sys.exit(f"No bedrock-server ZIP {pathlib.Path(ZIPS_DIR, VERSION)}")

pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")), "mc", "mc")

print("Enter Y if you stopped the server to import")
if input().lower() != "y":
    sys.exit("input != y")

try:
    shutil.copytree(IMPORT_DIR, SERVER_DIR)
    # Convert DOS line endings to UNIX line endings
    for file in list(SERVER_DIR.glob("*.json")) + list(SERVER_DIR.glob("*.properties")):
        file.write_text(
            file.read_text(encoding="utf-8").replace("\r\n", "\n"), encoding="utf-8"
        )
    for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
        shutil.chown(file, "mc", "mc")
    if not ARGS.no_update:
        # mcbe_update.py reads y asking if you stopped the server
        subprocess.run(
            [
                "systemd-run",
                "-PGqp",
                "User=mc",
                "/opt/MCscripts/bin/mcbe_update.py",
                SERVER_DIR,
                MINECRAFT_ZIP,
            ],
            check=True,
            input="y\n",
            encoding="utf-8",
        )
except:
    try:
        shutil.rmtree(SERVER_DIR)
    except FileNotFoundError:
        pass
    raise
shutil.rmtree(IMPORT_DIR)
print(f"@@@ Remember to edit {pathlib.Path(SERVER_DIR, 'server.properties')} @@@")
