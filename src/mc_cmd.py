#!/usr/bin/env python3
"""
Run command in the server console of Minecraft Java Edition or Bedrock Edition server
running in service.
"""

import argparse
import os
import pathlib
import subprocess
import sys
import time

import systemd.journal

PARSER = argparse.ArgumentParser(
    description="Run command in the server console of Minecraft Java Edition or Bedrock\
        Edition server running in service."
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
PARSER.add_argument(
    "COMMAND",
    type=str,
    nargs="+",
    help="minecraft java edition or bedrock edition command",
)
ARGS = PARSER.parse_args()

SERVICE = ARGS.SERVICE
# Trim off SERVICE after last .service
if SERVICE.endswith(".service"):
    SERVICE = SERVICE[: -len(".service")]
if subprocess.run(
    ["systemctl", "is-active", "--quiet", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")

journal = systemd.journal.Reader()
journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
journal.seek_tail()
CMD_CURSOR = journal.get_previous()
if CMD_CURSOR:
    CMD_CURSOR = CMD_CURSOR["__CURSOR"]
else:
    CMD_CURSOR = None
pathlib.Path("/run", SERVICE).write_text(
    " ".join(ARGS.COMMAND) + "\n", encoding="utf-8"
)
time.sleep(1)
if CMD_CURSOR:
    journal.seek_cursor(CMD_CURSOR)
    journal.get_next()
OUTPUT = os.linesep.join([entry["MESSAGE"] for entry in journal])
if not OUTPUT:
    print("No output from service after 1 second")
    sys.exit()
subprocess.run(
    ["/opt/MCscripts/mc_color.sed"],
    check=True,
    input=OUTPUT + "\n",
    encoding="utf-8",
)
