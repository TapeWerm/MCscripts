#!/usr/bin/env python3
"""
Post Minecraft Bedrock Edition server logs running in service to webhooks (Discord and
Rocket Chat).
"""

import argparse
import os
import pathlib
import re
import select
import subprocess
import sys

import requests
import systemd.journal


def send(msg: str):
    """
    :param msg: Message to send to URLs in WEBHOOK_FILE
    """
    if WEBHOOK_FILE.is_file():
        for url in WEBHOOK_FILE.read_text(encoding="utf-8").split(os.linesep):
            match = re.match(r"^https://discord(app)?\.com", url)
            if match:
                post_res = requests.post(
                    match.string,
                    json={"content": msg},
                    timeout=60,
                )
                post_res.raise_for_status()
                continue
			# Rocket Chat can be hosted by any domain
            match = re.match(r"^https://rocket\.", url)
            if match:
                post_res = requests.post(
                    match.string,
                    json={"text": msg},
                    timeout=60,
                )
                post_res.raise_for_status()
                continue


PARSER = argparse.ArgumentParser(
    description="Post Minecraft Bedrock Edition server logs running in service to\
        webhooks (Discord and Rocket Chat).",
    epilog="Logs include server start/stop and player connect/disconnect/kicks.",
)
PARSER.add_argument("SERVICE", type=str, help="systemd service")
ARGS = PARSER.parse_args()

SERVICE = ARGS.SERVICE.removesuffix(".service")
if subprocess.run(
    ["systemctl", "is-active", "--quiet", "--", SERVICE], check=False
).returncode:
    sys.exit(f"Service {SERVICE} not active")

# Trim off SERVICE before last @
INSTANCE = SERVICE.split("@")[-1]
WEBHOOK_FILE = pathlib.Path(pathlib.Path.home(), ".mcbe_log", f"{INSTANCE}_webhook.txt")
WEBHOOK_FILE.chmod(0o600)

send(f"Server {INSTANCE} starting")
journal = systemd.journal.Reader()
journal.add_match(_SYSTEMD_UNIT=SERVICE + ".service")
journal.seek_tail()
journal.get_previous()
journal.process()
poll = select.poll()
poll.register(journal, journal.get_events())
try:
    # Follow log for unit SERVICE
    while poll.poll():
        journal.process()
        for entry in journal:
            line = entry["MESSAGE"]
            if "Player connected" in line:
                # Gamertags can have spaces as long as they're not leading/trailing/contiguous
                player = re.sub(r".*Player connected: (.*),.*", r"\1", line)
                send(f"{player} connected to {INSTANCE}")
            elif "Player disconnected" in line:
                player = re.sub(r".*Player disconnected: (.*),.*", r"\1", line)
                send(f"{player} disconnected from {INSTANCE}")
            elif "Kicked" in line:
                player = re.sub(r".*Kicked (.*) from the game.*", r"\1", line)
                # Trim off leading space from REASON
                reason = re.sub(r".*from the game: '(.*)'.*", r"\1", line).removeprefix(
                    " "
                )
                send(f"{player} was kicked from {INSTANCE} because {reason}")
finally:
    send(f"Server {INSTANCE} stopping")
