#!/usr/bin/env bash

set -e
# Exit if error
dir=$(dirname "$0")
# $0 is this script
syntax='`./MCBEautoUpdate.sh $server_dir [$service]`'

case $1 in
--help|-h)
	echo 'If $server_dir/version '"isn't the same as the ZIP in ~mc, update and restart service of Minecraft Bedrock Edition server. If there's no service, make and chown mc "'$server_dir.'
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

installed_ver=$(cat "$1/version" 2> /dev/null || true)
# cat fails if there's no file $1/version
minecraft_zip=$(ls ~mc/bedrock-server-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\.zip 2> /dev/null | head -n 1 || true)
# There might be more than one ZIP in ~mc
# ls fails if there's no match
current_ver=$(basename "${minecraft_zip%.zip}")
# Trim off $minecraft_zip after last .zip

if [ -n "$2" ] && service "$2" status 2>&1 | grep 'could not be found'; then
# service says Unit $2 could not be found.
	exit 2
fi

if [ -n "$2" ]; then
	if [ "$installed_ver" != "$current_ver" ]; then
		sudo service "$2" stop
		trap 'sudo chown -R mc:nogroup "$1"; sudo service "$2" start' ERR
		echo y | sudo "$dir/MCBEupdate.sh" "$1" "$minecraft_zip"
		# MCBEupdate.sh reads y asking if you stopped the server
		sudo chown -R mc:nogroup "$1"
		sudo service "$2" start
		exit
	fi
else
	echo Enter Y if you agree to the Minecraft End User License Agreement and Privacy Policy
	echo Minecraft End User License Agreement: https://minecraft.net/terms
	# Does prompting the EULA seem so official that it violates the EULA?
	echo Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839
	read -r input
	input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
	if [ "$input" != y ]; then
		>&2 echo "$input != y"
		exit 3
	fi

	sudo mkdir "$1"
	trap 'sudo rm -r "$1"' ERR
	unzip -tq "$minecraft_zip"
	# Test extracting $minecraft_zip partially quietly
	sudo unzip "$minecraft_zip" -d "$1"
	echo "$current_ver" | sudo tee "$1/version"
	sudo chown -R mc:nogroup "$1"
fi
