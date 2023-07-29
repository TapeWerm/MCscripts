#!/usr/bin/env python3
"""
If the JAR of the current version of Minecraft Java Edition server isn't in ~, download
it, and remove outdated JARs in ~.
"""

import argparse
import pathlib
import re
import sys

import bs4
import requests

JARS_DIR = pathlib.Path(pathlib.Path.home(), "java_jars")

PARSER = argparse.ArgumentParser(
    description="If the JAR of the current version of Minecraft Java Edition server\
        isn't in ~, download it, and remove outdated JARs in ~."
)
PARSER.add_argument(
    "-n", "--no-clobber", action="store_true", help="don't remove outdated JARs in ~"
)
ARGS = PARSER.parse_args()

JARS_DIR.mkdir(parents=True, exist_ok=True)

webpage_res = requests.get(
    "https://www.minecraft.net/en-us/download/server",
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Language": "en-US",
    },
    timeout=60,
)
webpage_res.raise_for_status()
webpage = bs4.BeautifulSoup(webpage_res.text, "html.parser")
links = webpage.find_all("a")

print(
    "Enter Y if you agree to the Minecraft End User License Agreement and Privacy",
    "Policy",
)
# Does prompting the EULA seem so official that it violates the EULA?
print("Minecraft End User License Agreement: https://minecraft.net/terms")
print("Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839")
if input().lower() != "y":
    sys.exit("input != y")
for link in links:
    url = link.get("href")
    if not url:
        continue
    url = re.match(r"^https://[^ ]+server\.jar$", url)
    if url:
        url = url.string
        current_ver = link.get_text()
        current_ver = pathlib.Path(current_ver).name
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
    )
    jar_res.raise_for_status()
    pathlib.Path(JARS_DIR, current_ver + ".part").write_bytes(jar_res.content)
    pathlib.Path(JARS_DIR, current_ver + ".part").rename(
        pathlib.Path(JARS_DIR, current_ver)
    )
if INSTALLED_VER != current_ver:
    if pathlib.Path(JARS_DIR, "current").is_symlink():
        pathlib.Path(JARS_DIR, "current").unlink()
    pathlib.Path(JARS_DIR, "current").symlink_to(pathlib.Path(JARS_DIR, current_ver))
if not ARGS.no_clobber:
    for jarfile in JARS_DIR.glob("minecraft_server.*.jar"):
        if not jarfile.samefile(pathlib.Path(JARS_DIR, "current")):
            jarfile.unlink()
