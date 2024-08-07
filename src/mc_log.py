#!/usr/bin/env python3
"""
Post Minecraft Java Edition server logs running in service to webhooks (Discord and
Rocket Chat).
"""

import argparse
import os
import pathlib
import re
import select
import signal
import subprocess
import sys

import requests
import systemd.journal


def send(msg: str):
    """
    :param msg: Message to send to URLs in webhook files
    """
    if DISCORD_FILE.is_file():
        for url in DISCORD_FILE.read_text(encoding="utf-8").split(os.linesep)[:-1]:
            try:
                requests.post(
                    url,
                    json={"content": msg},
                    timeout=60,
                )
            except requests.exceptions.RequestException as err:
                print(type(err), flush=True)
    if ROCKET_FILE.is_file():
        for url in ROCKET_FILE.read_text(encoding="utf-8").split(os.linesep)[:-1]:
            try:
                requests.post(
                    url,
                    json={"text": msg},
                    timeout=60,
                )
            except requests.exceptions.RequestException as err:
                print(type(err), flush=True)


PARSER = argparse.ArgumentParser(
    description=(
        "Post Minecraft Java Edition server logs running in service to webhooks "
        + "(Discord and Rocket Chat)."
    ),
    epilog="Logs include server start/stop and player connect/disconnect/kick.",
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
ARGS = PARSER.parse_args()

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
DISCORD_FILE = pathlib.Path(pathlib.Path.home(), ".mc_log", f"{INSTANCE}_discord.txt")
if DISCORD_FILE.is_file():
    DISCORD_FILE.chmod(0o600)
ROCKET_FILE = pathlib.Path(pathlib.Path.home(), ".mc_log", f"{INSTANCE}_rocket.txt")
if ROCKET_FILE.is_file():
    ROCKET_FILE.chmod(0o600)

send(f"Server {SERVICE} starting")
journal = systemd.journal.Reader()
journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
journal.seek_tail()
journal.get_previous()
poll = select.poll()
poll.register(journal, journal.get_events())
signal.signal(signal.SIGTERM, lambda signalnum, currentframe: sys.exit())
try:
    # Follow log for unit SERVICE
    while poll.poll():
        journal.process()
        for entry in journal:
            line = entry["MESSAGE"]
            # Filter out chat
            if re.search("<.+>", line):
                continue
            connect = re.search("([^: ][^:]*) joined the game", line)
            if connect:
                # Gamertags can have spaces if they're not leading/trailing/consecutive
                player = connect.group(1)
                send(f"{player} connected to {SERVICE}")
                continue
            disconnect = re.search("([^: ][^:]*) left the game", line)
            if disconnect:
                player = disconnect.group(1)
                send(f"{player} disconnected from {SERVICE}")
                continue
            kick = re.search("Kicked ([^:]+): (.*)", line)
            if kick:
                player = kick.group(1)
                reason = kick.group(2)
                # Trim off leading space from reason
                if reason.startswith(" "):
                    reason = reason[1:]
                send(f"{player} was kicked from {SERVICE} because {reason}")
                continue
finally:
    send(f"Server {SERVICE} stopping")
