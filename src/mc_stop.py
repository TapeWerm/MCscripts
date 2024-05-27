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

import toml

SECONDS = 10


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
    ).stdout[: -len(os.linesep)]
if MAINPID == "0":
    print(f"Service {SERVICE} already stopped")
    sys.exit()
# Trim off SERVICE before last @
INSTANCE = SERVICE.split("@")[-1]
# Trim off SERVICE after first @
TEMPLATE = SERVICE.split("@")[0]

CONFIG_FILES = (
    pathlib.Path("/etc/MCscripts", f"{TEMPLATE}.toml"),
    pathlib.Path("/etc/MCscripts", TEMPLATE, f"{INSTANCE}.toml"),
)
for config_file in CONFIG_FILES:
    if config_file.is_file():
        config = toml.load(config_file)
        if "seconds" in config:
            if not isinstance(config["seconds"], int):
                sys.exit(f"seconds must be TOML integer, check {config_file}")
            SECONDS = config["seconds"]
            if SECONDS < 0 or SECONDS > 60:
                sys.exit(f"seconds must be between 0 and 60, check {config_file}")

if ARGS.seconds is not None:
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
