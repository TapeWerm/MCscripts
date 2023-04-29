#!/usr/bin/env python3
"""
Restore backup for Minecraft Bedrock Edition server.
"""

import argparse
import os
import pathlib
import shutil
import sys
import zipfile

PARSER = argparse.ArgumentParser(
    description="Restore backup for Minecraft Bedrock Edition server."
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft bedrock edition server directory"
)
PARSER.add_argument(
    "BACKUP", type=pathlib.Path, help="minecraft bedrock edition backup"
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

BACKUP = ARGS.BACKUP.resolve()
with zipfile.ZipFile(BACKUP, "r") as BACKUP_ZIPFILE:
    if BACKUP_ZIPFILE.testzip():
        sys.exit("MINECRAFT_ZIP test failed")

print("Enter Y if you stopped the server to restore")
if input().lower() != "y":
    sys.exit("input != y")

shutil.rmtree(pathlib.Path(WORLDS_DIR, WORLD), ignore_errors=True)
with zipfile.ZipFile(BACKUP, "r") as BACKUP_ZIPFILE:
    BACKUP_ZIPFILE.extractall(WORLDS_DIR)
for file in [pathlib.Path(WORLDS_DIR, WORLD)] + list(
    pathlib.Path(WORLDS_DIR, WORLD).rglob("*")
):
    shutil.chown(file, "mc", "nogroup")
