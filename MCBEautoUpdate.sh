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

server_dir=$1
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)
# cat fails if there's no file $server_dir/version
minecraft_zip=$(ls ~mc/bedrock-server-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\.zip 2> /dev/null | head -n 1 || true)
# There might be more than one ZIP in ~mc
# ls fails if there's no match
current_ver=$(basename "${minecraft_zip%.zip}")
# Trim off $minecraft_zip after last .zip

service=$2
if [ -n "$service" ] && service "$service" status 2>&1 | grep 'could not be found'; then
# service says Unit $service could not be found.
	exit 2
fi

if [ -n "$service" ]; then
	if [ "$installed_ver" = fail ]; then
		echo Previous update failed, rm "$server_dir/version" and try again
		exit 3
	elif [ "$installed_ver" != "$current_ver" ]; then
		sudo systemctl stop "$service"
		trap 'sudo chown -R mc:nogroup "$server_dir"; sudo service "$service" start' ERR
		echo y | sudo "$dir/MCBEupdate.sh" "$server_dir" "$minecraft_zip"
		# MCBEupdate.sh reads y asking if you stopped the server
		sudo chown -R mc:nogroup "$server_dir"
		sudo service "$service" start
		exit
	fi
else
	sudo mkdir "$server_dir"
	trap 'sudo rm -r "$server_dir"' ERR
	unzip -tq "$minecraft_zip"
	# Test extracting $minecraft_zip partially quietly
	unzip "$minecraft_zip" -d "$server_dir"
	echo "$current_ver" | tee "$server_dir/version"
	sudo chown -R mc:nogroup "$server_dir"
fi
