#!/usr/bin/env bash

set -e
# Exit if error
dir=$(dirname "$0")
# $0 is this script
syntax='`./MCBEautoUpdate.sh $server_dir [$service]`'

case $1 in
--help|-h)
	echo "If the ZIP of the current version isn't in ~mc, download it, remove outdated ZIPs in ~mc, and update and restart service of Minecraft Bedrock Edition server. If there's no service, make and chown mc "'$server_dir.'
	echo "$syntax"
	exit
	;;
esac
if [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

if [ -n "$2" ] && service "$2" status 2>&1 | grep 'could not be found'; then
# service says Unit $2 could not be found.
	exit 2
fi

webpage=$(wget https://www.minecraft.net/en-us/download/server/bedrock/ -O -)
url=$(echo "$webpage" | grep -Eo 'https://[^ ]+bin-linux/bedrock-server-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.zip')
current_ver=$(basename "$url")
installed_ver=$(ls ~mc/bedrock-server*.zip || true)
# ls fails if there's no match

if ! echo "$installed_ver" | grep -q "$current_ver"; then
# There might be more than one ZIP
	trap 'sudo rm -f ~mc/"$current_ver"' ERR
	sudo wget "$url" -O ~mc/"$current_ver"
	trap - ERR
	# Do not remove $current_ver if wget succeeded, below fails will repeat
	sudo chown -R mc:nogroup ~mc/"$current_ver"
	sudo rm -f $installed_ver

	if [ -n "$2" ]; then
	# If outdated service
		sudo service "$2" stop
		trap 'sudo chown -R mc:nogroup "$1"; sudo service "$2" start' ERR
		echo y | sudo "$dir/MCBEupdate.sh" "$1" ~mc/"$current_ver"
		# MCBEupdate.sh reads y asking if you stopped the server
		sudo chown -R mc:nogroup "$1"
		sudo service "$2" start
	fi
fi

if [ -z "$2" ]; then
# If no service
	mkdir "$1"
	unzip -tq ~mc/"$current_ver"
	# Test extracting $current_ver partially quietly
	unzip ~mc/"$current_ver" -d "$1"
	sudo chown -R mc:nogroup "$1"
fi
