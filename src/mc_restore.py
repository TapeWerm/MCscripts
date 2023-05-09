#!/usr/bin/env python3
"""
Restore backup for Minecraft Java Edition server.
"""

import argparse
import pathlib
import shutil
import sys
import zipfile

PARSER = argparse.ArgumentParser(
    description="Restore backup for Minecraft Java Edition server."
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft java edition server directory"
)
PARSER.add_argument("BACKUP", type=pathlib.Path, help="minecraft java edition backup")
ARGS = PARSER.parse_args()

SERVER_DIR = ARGS.SERVER_DIR.resolve()
with pathlib.Path(SERVER_DIR, "server.properties").open(
    "r", encoding="utf-8"
) as properties:
    for line in properties:
        if line.startswith("level-name="):
            WORLD = pathlib.Path("=".join(line.split("=")[1:]).rstrip("\n")).name
            break

BACKUP = ARGS.BACKUP.resolve()
with zipfile.ZipFile(BACKUP, "r") as backup_zipfile:
    if backup_zipfile.testzip():
        sys.exit("backup_zipfile test failed")

print("Enter Y if you stopped the server to restore")
if input().lower() != "y":
    sys.exit("input != y")

shutil.rmtree(pathlib.Path(SERVER_DIR, WORLD), ignore_errors=True)
with zipfile.ZipFile(BACKUP, "r") as backup_zipfile:
    backup_zipfile.extractall(SERVER_DIR)
for file in [pathlib.Path(SERVER_DIR, WORLD)] + list(
    pathlib.Path(SERVER_DIR, WORLD).rglob("*")
):
    shutil.chown(file, "mc", "nogroup")
