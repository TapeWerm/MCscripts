#!/usr/bin/env python3
"""Download the JAR of the current version of Minecraft Java Edition server."""

import argparse
import pathlib
import re
import sys

import bs4
import requests


PARSER = argparse.ArgumentParser(
    description="Download the JAR of the current version of Minecraft Java Edition\
        server."
)
ARGS = PARSER.parse_args()

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
urls = [link.get("href") for link in webpage.find_all("a")]
urls = [link for link in urls if link]

for url in urls:
    url = re.match(r"^https://[^ ]+server\.jar$", url)
    if url:
        url = url.string
        break

print(
    "Enter Y if you agree to the Minecraft End User License Agreement and Privacy",
    "Policy",
)
# Does prompting the EULA seem so official that it violates the EULA?
print("Minecraft End User License Agreement: https://minecraft.net/terms")
print("Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839")
if input().lower() != "y":
    sys.exit("input != y")
jar_res = requests.get(
    url,
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Language": "en-US",
    },
    timeout=60,
)
jar_res.raise_for_status()
pathlib.Path("server.jar.part").write_bytes(jar_res.content)
pathlib.Path("server.jar.part").rename(pathlib.Path("server.jar"))
