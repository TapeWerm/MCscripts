#!/usr/bin/env python3
"""Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE."""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import zipfile

ZIPS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock_zips"))

PARSER = argparse.ArgumentParser(
    description="Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE."
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mcbe@MCBE")
PARSER.add_argument(
    "-p",
    "--preview",
    action="store_true",
    help="use preview instead of current version",
)
ARGS = PARSER.parse_args()

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
    sys.exit("INSTANCE should be identical to systemd-escape INSTANCE")
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")
MCSCRIPTS_DIR = pathlib.Path(SERVER_DIR, ".MCscripts")

if ARGS.preview:
    VERSION = "preview"
else:
    VERSION = "current"

if pathlib.Path(ZIPS_DIR, VERSION).is_symlink():
    MINECRAFT_ZIP = pathlib.Path(ZIPS_DIR, VERSION).resolve()
else:
    sys.exit(f"No bedrock-server ZIP {pathlib.Path(ZIPS_DIR, VERSION)}")
CURRENT_VER = MINECRAFT_ZIP.stem

pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")), "mc", "mc")
with zipfile.ZipFile(MINECRAFT_ZIP, "r") as minecraft_zipfile:
    if minecraft_zipfile.testzip():
        sys.exit("minecraft_zipfile test failed")
    try:
        minecraft_zipfile.extractall(SERVER_DIR)
        MCSCRIPTS_DIR.mkdir()
        pathlib.Path(MCSCRIPTS_DIR, "version").write_text(
            CURRENT_VER + "\n", encoding="utf-8"
        )
        for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
            shutil.chown(file, "mc", "mc")
    except:
        try:
            shutil.rmtree(SERVER_DIR)
        except FileNotFoundError:
            pass
        raise
print(f"@@@ Remember to edit {pathlib.Path(SERVER_DIR, 'server.properties')} @@@")
