#!/usr/bin/env python3
"""
Make new Minecraft Java Edition server in ~mc/java/INSTANCE or import SERVER_DIR.
"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

PARSER = argparse.ArgumentParser(
    description="Make new Minecraft Java Edition server in ~mc/java/INSTANCE or import\
        SERVER_DIR."
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mc@MC")
PARSER.add_argument(
    "-i",
    "--import",
    type=pathlib.Path,
    dest="import_dir",
    metavar="SERVER_DIR",
    help="minecraft java edition server directory to import",
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
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")

if ARGS.import_dir:
    IMPORT_DIR = pathlib.Path(ARGS.import_dir).resolve()

if not shutil.which("java"):
    sys.exit("No command java")

pathlib.Path.expanduser(pathlib.Path("~mc", "java")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "java")), "mc", "nogroup")
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
        pathlib.Path(SERVER_DIR, "start.bat").write_text(
            "java -jar server.jar nogui", encoding="utf-8"
        )
        # chmod +x
        pathlib.Path(SERVER_DIR, "start.bat").chmod(
            pathlib.Path(SERVER_DIR, "start.bat").stat().st_mode | 0o111
        )
        for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
            shutil.chown(file, "mc", "nogroup")
    except:
        shutil.rmtree(SERVER_DIR, ignore_errors=True)
        raise
    shutil.rmtree(IMPORT_DIR)
else:
    try:
        SERVER_DIR.mkdir()
        os.chdir(SERVER_DIR)
        subprocess.run(["/opt/MCscripts/mc_getjar.py"], check=True)
        # Minecraft Java Edition makes eula.txt on first run
        subprocess.run(["java", "-jar", "server.jar", "nogui"], check=False)
        pathlib.Path(SERVER_DIR, "start.bat").write_text(
            "java -jar server.jar nogui", encoding="utf-8"
        )
        # chmod +x
        pathlib.Path(SERVER_DIR, "start.bat").chmod(
            pathlib.Path(SERVER_DIR, "start.bat").stat().st_mode | 0o111
        )
        for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
            shutil.chown(file, "mc", "nogroup")
    except:
        shutil.rmtree(SERVER_DIR, ignore_errors=True)
        raise
