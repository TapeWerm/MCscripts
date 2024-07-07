#!/usr/bin/env python3
"""
If SERVER_DIR/.MCscripts/version isn't the same as the JAR in ~mc, back up, update, and
restart service of Minecraft Java Edition server.
"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys

JARS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "java_jars"))

PARSER = argparse.ArgumentParser(
    description=(
        "If SERVER_DIR/.MCscripts/version isn't the same as the JAR in ~mc, back up, "
        + "update, and restart service of Minecraft Java Edition server."
    )
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="Minecraft Java Edition server directory"
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
ARGS = PARSER.parse_args()

SERVER_DIR = ARGS.SERVER_DIR.resolve()
MCSCRIPTS_DIR = pathlib.Path(SERVER_DIR, ".MCscripts")
if pathlib.Path(MCSCRIPTS_DIR, "version").is_file():
    INSTALLED_VER = (
        pathlib.Path(MCSCRIPTS_DIR, "version")
        .read_text(encoding="utf-8")
        .split(os.linesep)[0]
    )
else:
    INSTALLED_VER = None

SERVICE = ARGS.SERVICE
# Trim off SERVICE after last .service
if SERVICE.endswith(".service"):
    SERVICE = SERVICE[: -len(".service")]
if subprocess.run(
    ["systemctl", "is-active", "-q", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")
# Trim off SERVICE before last @
INSTANCE = SERVICE.split("@")[-1]

if pathlib.Path(JARS_DIR, "current").is_symlink():
    MINECRAFT_JAR = pathlib.Path(JARS_DIR, "current").resolve()
else:
    sys.exit(f"No minecraft_server JAR {pathlib.Path(JARS_DIR, 'current')}")
CURRENT_VER = MINECRAFT_JAR.stem

if INSTALLED_VER == "fail":
    sys.exit(
        f"Previous update failed, rm {pathlib.Path(MCSCRIPTS_DIR, 'version')} and try "
        + "again"
    )
elif INSTALLED_VER != CURRENT_VER:
    try:
        subprocess.run(["systemctl", "start", f"mc-backup@{INSTANCE}"], check=True)
        try:
            subprocess.run(["systemctl", "stop", f"{SERVICE}.socket"], check=True)
            shutil.copy2(MINECRAFT_JAR, pathlib.Path(SERVER_DIR, "server.jar"))
            pathlib.Path(MCSCRIPTS_DIR, "version").write_text(
                CURRENT_VER + "\n", encoding="utf-8"
            )
        finally:
            subprocess.run(["systemctl", "start", SERVICE], check=True)
    except:
        pathlib.Path(MCSCRIPTS_DIR, "version").write_text("fail\n", encoding="utf-8")
        raise
