#!/usr/bin/env bash

set -e
# Exit if error
dir=$(dirname "$0")
# $0 is this script

if [ -z "$1" ] || [ -z "$2" ] || [ "$1" = -h ] || [ "$1" = --help ]; then
	>&2 echo "If the ZIP of the current version isn't in ~mc, download it, remove outdated ZIPs in ~mc, and update and restart service of Minecraft Bedrock Edition server."
	>&2 echo '`./MCBEautoUpdate.sh $server_dir $service`'
	exit 1
fi

if service "$2" status 2>&1 | grep 'could not be found'; then
	exit 2
fi

webpage=$(wget https://www.minecraft.net/en-us/download/server/bedrock/ -O -)
url=$(echo "$webpage" | grep -Eo 'https://[^ ]+bin-linux/bedrock-server-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.zip')
current_ver=$(basename "$url")
installed_ver=$(ls ~mc/bedrock-server*.zip || true)
# ls fails if there's no match

if ! echo "$installed_ver" | grep -q "$current_ver"; then
# There might be more than one ZIP
	sudo wget "$url" -O ~mc/"$current_ver"
	sudo service "$2" stop
	echo y | sudo "$dir/MCBEupdate.sh" "$1" ~mc/"$current_ver"
	# MCBEupdate.sh reads y asking if you stopped the server
	sudo chown -R mc:nogroup "$1" ~mc/"$current_ver"
	sudo service "$2" start
	sudo rm -f $installed_ver
fi
