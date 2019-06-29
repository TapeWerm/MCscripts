#!/usr/bin/env bash

set -e
# Exit if error
syntax='`./MCBEgetZIP.sh`'

case $1 in
--help|-h)
	echo "If the ZIP of the current version isn't in ~, download it, and remove outdated ZIPs in ~."
	echo "$syntax"
	exit
	;;
esac
if [ "$#" -gt 1 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

webpage=$(wget --prefer-family=IPv4 https://www.minecraft.net/en-us/download/server/bedrock/ -O -)
url=$(echo "$webpage" | grep -Eo 'https://[^ ]+bin-linux/bedrock-server-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.zip')
current_ver=$(basename "$url")
installed_ver=$(ls ~/bedrock-server-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\.zip 2> /dev/null || true)
# ls fails if there's no match

if ! echo "$installed_ver" | grep -q "$current_ver"; then
# There might be more than one ZIP in ~
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

	trap 'sudo rm -f ~/"$current_ver"' ERR
	wget --prefer-family=IPv4 "$url" -O ~/"$current_ver"
	trap - ERR
	# Do not remove $current_ver if wget succeeded, below fails will repeat
	rm -f $installed_ver
fi
