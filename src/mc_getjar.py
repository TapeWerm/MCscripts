#!/usr/bin/env python3
"""
If the JAR of the current version of Minecraft Java Edition server isn't in ~, download
it, and remove outdated JARs in ~.
"""

import argparse
import pathlib
import sys

import requests
import toml

CLOBBER = True
CONFIG_FILE = pathlib.Path("/etc/MCscripts/mc-getjar.toml")
JARS_DIR = pathlib.Path(pathlib.Path.home(), "java_jars")

PARSER = argparse.ArgumentParser(
    description=(
        "If the JAR of the current version of Minecraft Java Edition server isn't in "
        + "~, download it, and remove outdated JARs in ~."
    )
)
CLOBBER_GROUP = PARSER.add_mutually_exclusive_group()
CLOBBER_GROUP.add_argument(
    "--clobber", action="store_true", help="remove outdated JARs in ~ (default)"
)
CLOBBER_GROUP.add_argument(
    "-n", "--no-clobber", action="store_true", help="don't remove outdated JARs in ~"
)
ARGS = PARSER.parse_args()

if CONFIG_FILE.is_file():
    CONFIG = toml.load(CONFIG_FILE)
    if "clobber" in CONFIG:
        if not isinstance(CONFIG["clobber"], bool):
            sys.exit(f"clobber must be TOML boolean, check {CONFIG_FILE}")
        CLOBBER = CONFIG["clobber"]

if ARGS.clobber:
    CLOBBER = True
elif ARGS.no_clobber:
    CLOBBER = False

JARS_DIR.mkdir(parents=True, exist_ok=True)

webpage_res = requests.get(
    # https://www.minecraft.net/en-us/download/server now uses JS to
    # load the links onto the page, so a simple scrape of that page won't work.
    # But that page does call this API endpoint to get the current Minecraft
    # server downloads.
    "https://net-secondary.web.minecraft-services.net/api/v1.0/download/links",
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Language": "en-US",
    },
    timeout=60,
)
webpage_res.raise_for_status()
urls = webpage_res.json()["result"]["links"]

latest_res = requests.get(
    "https://net-secondary.web.minecraft-services.net/api/v1.0/download/latest",
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Language": "en-US",
    },
    timeout=60,
)
latest_res.raise_for_status()
current_ver = f"minecraft_server.{latest_res.json()['result']}.jar"

print(
    "Enter Y if you agree to the Minecraft End User License Agreement and Privacy",
    "Policy",
)
# Does prompting the EULA seem so official that it violates the EULA?
print("Minecraft End User License Agreement: https://minecraft.net/eula")
print("Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839")
if input().lower() != "y":
    sys.exit("input != y")
for urlx in urls:
    if urlx["downloadType"] == "serverJar":
        url = urlx["downloadUrl"]
        break
# Symlink to current jar
if pathlib.Path(JARS_DIR, "current").is_symlink():
    INSTALLED_VER = pathlib.Path(JARS_DIR, "current").resolve().name
else:
    INSTALLED_VER = None

if not pathlib.Path(JARS_DIR, current_ver).is_file():
    jar_res = requests.get(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
            "Accept-Language": "en-US",
        },
        timeout=60,
        stream=True,
    )
    jar_res.raise_for_status()
    if pathlib.Path(JARS_DIR, current_ver + ".part").is_file():
        pathlib.Path(JARS_DIR, current_ver + ".part").unlink()
    for chunk in jar_res.iter_content(chunk_size=8192):
        pathlib.Path(JARS_DIR, current_ver + ".part").open(mode="ab").write(chunk)
    pathlib.Path(JARS_DIR, current_ver + ".part").rename(
        pathlib.Path(JARS_DIR, current_ver)
    )
if INSTALLED_VER != current_ver:
    if pathlib.Path(JARS_DIR, "current").is_symlink():
        pathlib.Path(JARS_DIR, "current").unlink()
    pathlib.Path(JARS_DIR, "current").symlink_to(pathlib.Path(JARS_DIR, current_ver))
if CLOBBER:
    for jarfile in JARS_DIR.glob("minecraft_server.*.jar"):
        if not jarfile.samefile(pathlib.Path(JARS_DIR, "current")):
            jarfile.unlink()
