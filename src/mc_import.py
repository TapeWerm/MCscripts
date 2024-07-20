#!/usr/bin/env python3
"""Import Minecraft Java Edition server to ~mc/java/INSTANCE."""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

JARS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java_jars"))

PARSER = argparse.ArgumentParser(
    description="Import Minecraft Java Edition server to ~mc/java/INSTANCE."
)
PARSER.add_argument(
    "IMPORT_DIR",
    type=pathlib.Path,
    metavar="SERVER_DIR",
    help="Minecraft Java Edition server directory to import",
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mc@MC")
PARSER.add_argument(
    "-n",
    "--no-update",
    action="store_true",
    help="don't update Minecraft Java Edition server",
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
    sys.exit("INSTANCE should be identical to systemd-escape INSTANCE")
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")
MCSCRIPTS_DIR = pathlib.Path(SERVER_DIR, ".MCscripts")

if not shutil.which("java"):
    sys.exit("No command java")

if pathlib.Path(JARS_DIR, "current").is_symlink():
    MINECRAFT_JAR = pathlib.Path(JARS_DIR, "current").resolve()
else:
    sys.exit(f"No minecraft_server JAR {pathlib.Path(JARS_DIR, 'current')}")

pathlib.Path.expanduser(pathlib.Path("~mc", "java")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "java")), "mc", "mc")

print("Enter Y if you stopped the server to import")
if input().lower() != "y":
    sys.exit("input != y")

try:
    shutil.copytree(IMPORT_DIR, SERVER_DIR)
    MCSCRIPTS_DIR.mkdir(exist_ok=True)
    # Convert DOS line endings to UNIX line endings
    for file in list(SERVER_DIR.glob("*.json")) + list(SERVER_DIR.glob("*.properties")):
        file.write_text(
            file.read_text(encoding="utf-8").replace("\r\n", "\n"), encoding="utf-8"
        )
    pathlib.Path(MCSCRIPTS_DIR, "start.sh").write_text(
        "#!/bin/bash\n\njava -jar server.jar --nogui\n", encoding="utf-8"
    )
    # chmod +x
    pathlib.Path(MCSCRIPTS_DIR, "start.sh").chmod(
        pathlib.Path(MCSCRIPTS_DIR, "start.sh").stat().st_mode | 0o111
    )
    if not ARGS.no_update:
        shutil.copy2(MINECRAFT_JAR, pathlib.Path(SERVER_DIR, "server.jar"))
    for file in [SERVER_DIR] + list(SERVER_DIR.rglob("*")):
        shutil.chown(file, "mc", "mc")
except:
    try:
        shutil.rmtree(SERVER_DIR)
    except FileNotFoundError:
        pass
    raise
shutil.rmtree(IMPORT_DIR)
print(f"@@@ Remember to edit {pathlib.Path(SERVER_DIR, 'server.properties')} @@@")
