#!/usr/bin/env python3
"""Make new Minecraft Java Edition server in ~mc/java/INSTANCE."""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

JARS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java_jars"))

PARSER = argparse.ArgumentParser(
    description="Make new Minecraft Java Edition server in ~mc/java/INSTANCE."
)
PARSER.add_argument("INSTANCE", help="systemd instance name. ex: mc@MC")
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
    sys.exit("INSTANCE should be indentical to systemd-escape INSTANCE")
SERVER_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java", INSTANCE))
if SERVER_DIR.is_dir():
    sys.exit(f"Server directory {SERVER_DIR} already exists")

if not shutil.which("java"):
    sys.exit("No command java")

if pathlib.Path(JARS_DIR, "current").is_symlink():
    MINECRAFT_JAR = pathlib.Path(JARS_DIR, "current").resolve()
else:
    sys.exit(f"No minecraft_server JAR {pathlib.Path(JARS_DIR, 'current')}")

pathlib.Path.expanduser(pathlib.Path("~mc", "java")).mkdir(exist_ok=True)
shutil.chown(pathlib.Path.expanduser(pathlib.Path("~mc", "java")), "mc", "mc")
try:
    SERVER_DIR.mkdir()
    shutil.copy2(MINECRAFT_JAR, pathlib.Path(SERVER_DIR, "server.jar"))
    os.chdir(SERVER_DIR)
    # Minecraft Java Edition makes eula.txt on first run
    subprocess.run(["java", "-jar", "server.jar", "--nogui"], check=False)
    pathlib.Path(SERVER_DIR, "start.bat").write_text(
        "java -jar server.jar --nogui", encoding="utf-8"
    )
    # chmod +x
    pathlib.Path(SERVER_DIR, "start.bat").chmod(
        pathlib.Path(SERVER_DIR, "start.bat").stat().st_mode | 0o111
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
