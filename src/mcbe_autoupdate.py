#!/usr/bin/env python3
"""
If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and restart
service of Minecraft Bedrock Edition server.
"""

import argparse
import os
import pathlib
import subprocess
import sys

import toml

VERSION = "current"
ZIPS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock_zips"))

PARSER = argparse.ArgumentParser(
    description=(
        "If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and "
        + "restart service of Minecraft Bedrock Edition server."
    )
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft bedrock edition server directory"
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
VERSION_GROUP = PARSER.add_mutually_exclusive_group()
VERSION_GROUP.add_argument(
    "-c", "--current", action="store_true", help="update to current version (default)"
)
VERSION_GROUP.add_argument(
    "-p", "--preview", action="store_true", help="update to preview version"
)
ARGS = PARSER.parse_args()

SERVER_DIR = ARGS.SERVER_DIR.resolve()
if pathlib.Path(SERVER_DIR, "version").is_file():
    INSTALLED_VER = (
        pathlib.Path(SERVER_DIR, "version")
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

CONFIG_FILES = (
    pathlib.Path("/etc/MCscripts/mcbe-autoupdate.toml"),
    pathlib.Path("/etc/MCscripts/mcbe-autoupdate", f"{INSTANCE}.toml"),
)
for config_file in CONFIG_FILES:
    if config_file.is_file():
        config = toml.load(config_file)
        if "version" in config:
            if config["version"] == "current":
                VERSION = "current"
            elif config["version"] == "preview":
                VERSION = "preview"
            else:
                sys.exit(f"No version {config['version']}, check {config_file}")

if ARGS.current:
    VERSION = "current"
elif ARGS.preview:
    VERSION = "preview"

if pathlib.Path(ZIPS_DIR, VERSION).is_symlink():
    MINECRAFT_ZIP = pathlib.Path(ZIPS_DIR, VERSION).resolve()
else:
    sys.exit(f"No bedrock-server ZIP {pathlib.Path(ZIPS_DIR, VERSION)}")
CURRENT_VER = MINECRAFT_ZIP.stem

if INSTALLED_VER == "fail":
    sys.exit(
        f"Previous update failed, rm {pathlib.Path(SERVER_DIR, 'version')} and try "
        + "again"
    )
elif INSTALLED_VER != CURRENT_VER:
    try:
        subprocess.run(["systemctl", "start", f"mcbe-backup@{INSTANCE}"], check=True)
        try:
            subprocess.run(["systemctl", "stop", f"{SERVICE}.socket"], check=True)
            # mcbe_update.py reads y asking if you stopped the server
            subprocess.run(
                [
                    "runuser",
                    "-u",
                    "mc",
                    "--",
                    "/opt/MCscripts/bin/mcbe_update.py",
                    "--",
                    SERVER_DIR,
                    MINECRAFT_ZIP,
                ],
                check=True,
                input="y\n",
                encoding="utf-8",
            )
        finally:
            subprocess.run(["systemctl", "start", SERVICE], check=True)
    except:
        pathlib.Path(SERVER_DIR, "version").write_text("fail\n", encoding="utf-8")
        raise
