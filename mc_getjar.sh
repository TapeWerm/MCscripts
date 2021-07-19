#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mc_getjar.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo Download and chmod +x the JAR of the current version.
	exit
	;;
esac
if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

webpage=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server)
url=$(echo "$webpage" | grep -Eo 'https://[^ ]+server\.jar' | head -n 1)
curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS "$url" -O
chmod +x server.jar
