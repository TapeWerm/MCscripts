#!/usr/bin/env python3
"""
Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE or import SERVER_DIR.
"""

import argparse
import pathlib
import shlex
import shutil
import subprocess
import sys
import zipfile

PARSER = argparse.ArgumentParser(
    description="Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE or\
        import SERVER_DIR."
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mcbe@MCBE")
PARSER.add_argument(
    "-i",
    "--import",
    type=pathlib.Path,
    dest="import_dir",
    metavar="SERVER_DIR",
    help="minecraft bedrock edition server directory to import",
)
PARSER.add_argument(
    "-p",
    "--preview",
    action="store_true",
    help="use preview instead of current version",
)
ARGS = PARSER.parse_args()

INSTANCE = ARGS.INSTANCE
if INSTANCE != subprocess.run(
    ["systemd-escape", "--", INSTANCE],
    check=True,
    stdout=subprocess.PIPE,
    encoding="utf-8",
).stdout.rstrip("\n"):
    sys.exit("INSTANCE should be indentical to systemd-escape INSTANCE")
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")

if ARGS.import_dir:
    IMPORT_DIR = pathlib.Path(ARGS.import_dir).resolve()

if ARGS.preview:
    VERSION = "preview"
else:
    VERSION = "current"

subprocess.run(
    ["runuser", "-l", "mc", "-s", "/bin/bash", "-c", "/opt/MCscripts/mcbe_getzip.py"],
    check=True,
)
ZIPS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock_zips"))
if pathlib.Path(ZIPS_DIR, VERSION).is_symlink():
    MINECRAFT_ZIP = pathlib.Path(ZIPS_DIR, VERSION).resolve()
else:
    sys.exit("No bedrock-server ZIP found in ~mc")
CURRENT_VER = MINECRAFT_ZIP.stem

pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock")), "mc", "nogroup")
if ARGS.import_dir:
    print("Enter Y if you stopped the server to import")
    if input().lower() != "y":
        sys.exit("input != y")

    try:
        shutil.copytree(IMPORT_DIR, SERVER_DIR)
        # Convert DOS line endings to UNIX line endings
        for file in list(SERVER_DIR.glob("*.json")) + list(
            SERVER_DIR.glob("*.properties")
        ):
            file.write_text(
                file.read_text(encoding="utf-8").replace("\r\n", "\n"), encoding="utf-8"
            )
        for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
            shutil.chown(file, "mc", "nogroup")
        # mcbe_update.py reads y asking if you stopped the server
        subprocess.run(
            [
                "runuser",
                "-l",
                "mc",
                "-s",
                "/bin/bash",
                "-c",
                f"echo y | /opt/MCscripts/mcbe_update.py --\
                    {shlex.quote(str(SERVER_DIR))}\
                    {shlex.quote(str(MINECRAFT_ZIP))}",
            ],
            check=True,
        )
    except:
        try:
            shutil.rmtree(SERVER_DIR)
        except FileNotFoundError:
            pass
        raise
    shutil.rmtree(IMPORT_DIR)
else:
    with zipfile.ZipFile(MINECRAFT_ZIP, "r") as minecraft_zipfile:
        if minecraft_zipfile.testzip():
            sys.exit("minecraft_zipfile test failed")
        try:
            minecraft_zipfile.extractall(SERVER_DIR)
            pathlib.Path(SERVER_DIR, "version").write_text(
                CURRENT_VER + "\n", encoding="utf-8"
            )
            for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
                shutil.chown(file, "mc", "nogroup")
            print(
                "@@@ Don't forget to edit",
                f"{pathlib.Path(SERVER_DIR, 'server.properties')} @@@",
            )
        except:
            try:
                shutil.rmtree(SERVER_DIR)
            except FileNotFoundError:
                pass
            raise
