#!/usr/bin/env python3
"""
Warn Minecraft Java Edition or Bedrock Edition server running in service 10 seconds
before stopping.
"""

import argparse
import os
import pathlib
import subprocess
import sys
import time


def server_do(cmd: str):
    """
    :param cmd: Write to SERVICE input
    """
    pathlib.Path("/run", SERVICE).write_text(cmd + "\n", encoding="utf-8")


def countdown(seconds: int):
    """
    :param seconds: Countdown X seconds to server and stdout
    """
    warning = f"Server stopping in {seconds} seconds"
    server_do(f"say {warning}")
    print(warning, flush=True)


PARSER = argparse.ArgumentParser(
    description="Warn Minecraft Java Edition or Bedrock Edition server running in\
        service 10 seconds before stopping.",
    epilog="Best ran by systemd before shutdown.",
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
PARSER.add_argument(
    "-s",
    "--seconds",
    type=int,
    default=10,
    help="seconds before stopping. must be between 0 and 60. defaults to 10",
)
ARGS = PARSER.parse_args()

SERVICE = ARGS.SERVICE
# Trim off SERVICE after last .service
if SERVICE.endswith(".service"):
    SERVICE = SERVICE[: -len(".service")]
if "MAINPID" in os.environ:
    MAINPID = os.environ["MAINPID"]
else:
    MAINPID = subprocess.run(
        ["systemctl", "show", "-p", "MainPID", "--value", "--", SERVICE],
        check=True,
        stdout=subprocess.PIPE,
        encoding="utf-8",
    ).stdout.rstrip(os.linesep)
if MAINPID == "0":
    print(f"Service {SERVICE} already stopped")
    sys.exit()

SECONDS = ARGS.seconds
if SECONDS < 0 or SECONDS > 60:
    sys.exit("SECONDS must be between 0 and 60")

if SECONDS > 3:
    countdown(SECONDS)
    time.sleep(SECONDS - 3)

for x in range(3, 0, -1):
    if SECONDS >= x:
        countdown(x)
        time.sleep(1)

server_do("stop")
# Follow /dev/null until MAINPID dies
subprocess.run(["tail", "-f", "--pid", MAINPID, "/dev/null"], check=True)
