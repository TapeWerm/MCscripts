#!/usr/bin/env python3
"""
Update Minecraft Bedrock Edition server keeping packs, worlds, JSON files, and
PROPERTIES files. Other files will be removed. You can convert a Windows SERVER_DIR to
Ubuntu and vice versa if you convert line endings.
"""

import argparse
import pathlib
import shutil
import zipfile
import sys

PARSER = argparse.ArgumentParser(
    description=(
        "Update Minecraft Bedrock Edition server keeping packs, worlds, JSON files, "
        + "and PROPERTIES files. Other files will be removed. You can convert a "
        + "Windows SERVER_DIR to Ubuntu and vice versa if you convert line endings."
    ),
    epilog=(
        "MINECRAFT_ZIP cannot be in SERVER_DIR. Remember to stop server before "
        + "updating."
    ),
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
NEW_SERVER = SERVER_DIR.with_name(SERVER_DIR.name + ".new")
OLD_SERVER = SERVER_DIR.with_name(SERVER_DIR.name + ".old")
MCSCRIPTS_DIR = pathlib.Path(SERVER_DIR, ".MCscripts")
NEW_MCSCRIPTS = pathlib.Path(NEW_SERVER, ".MCscripts")

MINECRAFT_ZIP = ARGS.MINECRAFT_ZIP.resolve()
if SERVER_DIR in MINECRAFT_ZIP.parents:
    sys.exit("MINECRAFT_ZIP cannot be in SERVER_DIR")
with zipfile.ZipFile(MINECRAFT_ZIP, "r") as minecraft_zipfile:
    if minecraft_zipfile.testzip():
        sys.exit("minecraft_zipfile test failed")

print("Enter Y if you backed up and stopped the server to update")
if input().lower() != "y":
    sys.exit("input != y")

try:
    shutil.rmtree(NEW_SERVER)
except FileNotFoundError:
    pass
try:
    with zipfile.ZipFile(MINECRAFT_ZIP, "r") as minecraft_zipfile:
        minecraft_zipfile.extractall(NEW_SERVER)

    NEW_MCSCRIPTS.mkdir()
    pathlib.Path(NEW_MCSCRIPTS, "version").write_text(
        MINECRAFT_ZIP.stem + "\n", encoding="utf-8"
    )
    shutil.copytree(
        pathlib.Path(SERVER_DIR, "worlds"), pathlib.Path(NEW_SERVER, "worlds")
    )

    for file in list(SERVER_DIR.glob("*.json")) + list(SERVER_DIR.glob("*.properties")):
        shutil.copy2(file, NEW_SERVER)

    for packs_dir in SERVER_DIR.glob("*_packs"):
        pathlib.Path(NEW_SERVER, packs_dir.name).mkdir(exist_ok=True)
        for pack in packs_dir.iterdir():
            # Don't clobber 1st party packs
            if not pathlib.Path(NEW_SERVER, packs_dir.name, pack.name).is_dir():
                shutil.copytree(
                    pack, pathlib.Path(NEW_SERVER, packs_dir.name, pack.name)
                )

    try:
        shutil.rmtree(OLD_SERVER)
    except FileNotFoundError:
        pass
    try:
        SERVER_DIR.rename(OLD_SERVER)
    finally:
        NEW_SERVER.rename(SERVER_DIR)
        try:
            shutil.rmtree(OLD_SERVER)
        except FileNotFoundError:
            pass
except:
    try:
        shutil.rmtree(NEW_SERVER)
    except FileNotFoundError:
        pass
    MCSCRIPTS_DIR.mkdir(exist_ok=True)
    pathlib.Path(MCSCRIPTS_DIR, "version").write_text("fail\n", encoding="utf-8")
    raise
