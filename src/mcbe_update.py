#!/usr/bin/env python3
"""
Update Minecraft Bedrock Edition server keeping packs, worlds, JSON files, and
PROPERTIES files. Other files will be removed. You can convert a Windows SERVER_DIR to
Ubuntu and vice versa if you convert line endings.
"""

import argparse
import itertools
import pathlib
import shutil
import zipfile
import sys

PARSER = argparse.ArgumentParser(
    description="Update Minecraft Bedrock Edition server keeping packs, worlds, JSON\
        files, and PROPERTIES files. Other files will be removed. You can convert a\
        Windows SERVER_DIR to Ubuntu and vice versa if you convert line endings.",
    epilog="MINECRAFT_ZIP cannot be in SERVER_DIR. Remember to stop server before\
        updating.",
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft bedrock edition server directory"
)
PARSER.add_argument(
    "MINECRAFT_ZIP",
    type=pathlib.Path,
    help="minecraft bedrock edition server zip to update to",
)
ARGS = PARSER.parse_args()

SERVER_DIR = ARGS.SERVER_DIR.resolve()
if (
    not pathlib.Path(SERVER_DIR, "bedrock_server").is_file()
    and not pathlib.Path(SERVER_DIR, "bedrock_server.exe").is_file()
):
    sys.exit("SERVER_DIR should have file bedrock_server or bedrock_server.exe")
NEW_DIR = SERVER_DIR.with_name(SERVER_DIR.name + ".new")
OLD_DIR = SERVER_DIR.with_name(SERVER_DIR.name + ".old")

MINECRAFT_ZIP = ARGS.MINECRAFT_ZIP.resolve()
if SERVER_DIR in MINECRAFT_ZIP.parents:
    sys.exit("MINECRAFT_ZIP cannot be in SERVER_DIR")
with zipfile.ZipFile(MINECRAFT_ZIP, "r") as MINECRAFT_ZIPFILE:
    if MINECRAFT_ZIPFILE.testzip():
        sys.exit("MINECRAFT_ZIP test failed")

print("Enter Y if you backed up and stopped the server to update")
if input().lower() != "y":
    sys.exit("input != y")

shutil.rmtree(NEW_DIR, ignore_errors=True)
try:
    with zipfile.ZipFile(MINECRAFT_ZIP, "r") as MINECRAFT_ZIPFILE:
        MINECRAFT_ZIPFILE.extractall(NEW_DIR)

    pathlib.Path(NEW_DIR, "version").write_text(
        MINECRAFT_ZIP.stem + "\n", encoding="utf-8"
    )
    shutil.copytree(pathlib.Path(SERVER_DIR, "worlds"), pathlib.Path(NEW_DIR, "worlds"))

    for file in itertools.chain(
        SERVER_DIR.glob("*.json"), SERVER_DIR.glob("*.properties")
    ):
        shutil.copy2(file, pathlib.Path(NEW_DIR, file.name))

    for packs_dir in SERVER_DIR.glob("*_packs"):
        pathlib.Path(NEW_DIR, packs_dir.name).mkdir(exist_ok=True)
        for pack in packs_dir.iterdir():
            # Don't clobber 1st party packs
            if not pathlib.Path(NEW_DIR, packs_dir.name, pack.name).is_dir():
                shutil.copytree(pack, pathlib.Path(NEW_DIR, packs_dir.name, pack.name))

    shutil.rmtree(OLD_DIR, ignore_errors=True)
    try:
        SERVER_DIR.rename(OLD_DIR)
    finally:
        NEW_DIR.rename(SERVER_DIR)
        shutil.rmtree(OLD_DIR, ignore_errors=True)
except:
    shutil.rmtree(NEW_DIR, ignore_errors=True)
    pathlib.Path(SERVER_DIR, "version").write_text("fail\n", encoding="utf-8")
    raise
