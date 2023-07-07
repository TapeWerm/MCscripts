#!/usr/bin/env python3
"""
If the ZIP of the current version of Minecraft Bedrock Edition server isn't in ~,
download it, and remove outdated ZIPs in ~.
"""

import argparse
import pathlib
import re
import sys

import bs4
import requests

PARSER = argparse.ArgumentParser(
    description="If the ZIP of the current version of Minecraft Bedrock Edition server\
        isn't in ~, download it, and remove outdated ZIPs in ~."
)
PARSER.add_argument(
    "-n", "--no-clobber", action="store_true", help="don't remove outdated ZIPs in ~"
)
GROUP = PARSER.add_mutually_exclusive_group()
GROUP.add_argument(
    "-p",
    "--preview",
    action="store_true",
    help="download preview instead of the current version",
)
GROUP.add_argument(
    "-b", "--both", action="store_true", help="download current and preview versions"
)
ARGS = PARSER.parse_args()

if ARGS.both:
    VERSIONS = ("current", "preview")
elif ARGS.preview:
    VERSIONS = ("preview",)
else:
    VERSIONS = ("current",)

ZIPS_DIR = pathlib.Path(pathlib.Path.home(), "bedrock_zips")
ZIPS_DIR.mkdir(parents=True, exist_ok=True)

webpage_res = requests.get(
    "https://www.minecraft.net/en-us/download/server/bedrock",
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Language": "en-US",
    },
    timeout=60,
)
webpage_res.raise_for_status()
webpage = bs4.BeautifulSoup(webpage_res.text, "html.parser")
urls = [link.get("href") for link in webpage.find_all("a")]
urls = [link for link in urls if link]

print(
    "Enter Y if you agree to the Minecraft End User License Agreement and Privacy",
    "Policy",
)
# Does prompting the EULA seem so official that it violates the EULA?
print("Minecraft End User License Agreement: https://minecraft.net/terms")
print("Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839")
if input().lower() != "y":
    sys.exit("input != y")
for version in VERSIONS:
    if version == "current":
        for url in urls:
            url = re.match(r"^https://[^ ]+bin-linux/bedrock-server-[^ ]+\.zip$", url)
            if url:
                url = url.string
                break
    elif version == "preview":
        for url in urls:
            url = re.match(
                r"^https://[^ ]+bin-linux-preview/bedrock-server-[^ ]+\.zip$", url
            )
            if url:
                url = url.string
                break
    else:
        continue
    current_ver = pathlib.Path(url).name
    # Symlink to current/preview zip
    if pathlib.Path(ZIPS_DIR, version).is_symlink():
        INSTALLED_VER = pathlib.Path(ZIPS_DIR, version).resolve().name
    else:
        INSTALLED_VER = None

    if not pathlib.Path(ZIPS_DIR, current_ver).is_file():
        zip_res = requests.get(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
                "Accept-Language": "en-US",
            },
            timeout=60,
        )
        zip_res.raise_for_status()
        pathlib.Path(ZIPS_DIR, current_ver + ".part").write_bytes(zip_res.content)
        pathlib.Path(ZIPS_DIR, current_ver + ".part").rename(
            pathlib.Path(ZIPS_DIR, current_ver)
        )
    if INSTALLED_VER != current_ver:
        if pathlib.Path(ZIPS_DIR, version).is_symlink():
            pathlib.Path(ZIPS_DIR, version).unlink()
        pathlib.Path(ZIPS_DIR, version).symlink_to(pathlib.Path(ZIPS_DIR, current_ver))
if not ARGS.no_clobber:
    for zipfile in ZIPS_DIR.glob("bedrock-server-*.zip"):
        if not zipfile.samefile(
            pathlib.Path(ZIPS_DIR, "current")
        ) and not zipfile.samefile(pathlib.Path(ZIPS_DIR, "preview")):
            zipfile.unlink()
