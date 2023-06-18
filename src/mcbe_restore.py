#!/usr/bin/env python3
"""
Restore backup for Minecraft Bedrock Edition server.
"""

import argparse
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
WORLD = None
with pathlib.Path(SERVER_DIR, "server.properties").open(
    "r", encoding="utf-8"
) as properties:
    for line in properties:
        if line.startswith("level-name="):
            WORLD = "=".join(line.split("=")[1:]).rstrip("\n")
            WORLD = pathlib.Path(WORLD).name
            break
if not WORLD:
    sys.exit("No level-name in server.properties")
WORLDS_DIR = pathlib.Path(SERVER_DIR, "worlds")

BACKUP = ARGS.BACKUP.resolve()
with zipfile.ZipFile(BACKUP, "r") as backup_zipfile:
    if backup_zipfile.testzip():
        sys.exit("backup_zipfile test failed")

print("Enter Y if you stopped the server to restore")
if input().lower() != "y":
    sys.exit("input != y")

shutil.rmtree(pathlib.Path(WORLDS_DIR, WORLD), ignore_errors=True)
with zipfile.ZipFile(BACKUP, "r") as backup_zipfile:
    backup_zipfile.extractall(WORLDS_DIR)
for file in [pathlib.Path(WORLDS_DIR, WORLD)] + list(
    pathlib.Path(WORLDS_DIR, WORLD).rglob("*")
):
    shutil.chown(file, "mc", "nogroup")
