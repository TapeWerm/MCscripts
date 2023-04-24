#!/usr/bin/env python3
"""
If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and restart
service of Minecraft Bedrock Edition server.
"""

import argparse
import os
import pathlib
import shlex
import subprocess
import sys

PARSER = argparse.ArgumentParser(
    description="If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up,\
        update, and restart service of Minecraft Bedrock Edition server."
)
PARSER.add_argument(
    "SERVER_DIR", type=pathlib.Path, help="minecraft bedrock edition server directory"
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
PARSER.add_argument(
    "-p",
    "--preview",
    action="store_true",
    help="update to preview instead of current version",
)
ARGS = PARSER.parse_args()

if ARGS.preview:
    VERSION = "preview"
else:
    VERSION = "current"

SERVER_DIR = ARGS.SERVER_DIR.resolve()
if pathlib.Path(SERVER_DIR, "version").is_file():
    INSTALLED_VER = (
        pathlib.Path(SERVER_DIR, "version")
        .read_text(encoding="utf-8")
        .split(os.linesep)[0]
    )
else:
    INSTALLED_VER = None

SERVICE = ARGS.SERVICE.removesuffix(".service")
if subprocess.run(
    ["systemctl", "is-active", "--quiet", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")
# Trim off SERVICE before last @
INSTANCE = SERVICE.split("@")[-1]

ZIPS_DIR = pathlib.Path.expanduser(pathlib.Path("~mc", "bedrock_zips"))
if pathlib.Path(ZIPS_DIR, VERSION).is_symlink():
    MINECRAFT_ZIP = pathlib.Path(ZIPS_DIR, VERSION).resolve()
else:
    sys.exit("No bedrock-server ZIP found in ~mc")
CURRENT_VER = MINECRAFT_ZIP.stem

if INSTALLED_VER == "fail":
    sys.exit("Previous update failed, rm $server_dir/version and try again")
elif INSTALLED_VER != CURRENT_VER:
    try:
        subprocess.run(["systemctl", "start", f"mcbe-backup@{INSTANCE}"], check=True)
        try:
            subprocess.run(["systemctl", "stop", f"{SERVICE}.socket"], check=True)
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
        finally:
            subprocess.run(["systemctl", "start", SERVICE], check=True)
    except:
        pathlib.Path(SERVER_DIR, "version").write_text("fail\n", encoding="utf-8")
        raise
