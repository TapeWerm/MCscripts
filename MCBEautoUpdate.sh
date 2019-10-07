#!/usr/bin/env bash

# Exit if error
set -e
# $0 is this script
dir=$(dirname "$0")
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
# cat fails if there's no file $server_dir/version
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)
# There might be more than one ZIP in ~mc
# ls fails if there's no match
minecraft_zip=$(ls ~mc/bedrock-server-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\.zip 2> /dev/null | head -n 1 || true)
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

service=$2
# service says Unit $service could not be found.
if [ -n "$service" ] && service "$service" status 2>&1 | grep 'could not be found'; then
	exit 2
fi

if [ -n "$service" ]; then
	if [ "$installed_ver" = fail ]; then
		echo Previous update failed, rm "$server_dir/version" and try again
		exit 3
	elif [ "$installed_ver" != "$current_ver" ]; then
		sudo systemctl stop "$service"
		trap 'sudo chown -R mc:nogroup "$server_dir"; sudo service "$service" start' ERR
		# MCBEupdate.sh reads y asking if you stopped the server
		echo y | sudo "$dir/MCBEupdate.sh" "$server_dir" "$minecraft_zip"
		sudo chown -R mc:nogroup "$server_dir"
		sudo service "$service" start
		exit
	fi
else
	sudo mkdir "$server_dir"
	trap 'sudo rm -r "$server_dir"' ERR
	# Test extracting $minecraft_zip partially quietly
	unzip -tq "$minecraft_zip"
	unzip "$minecraft_zip" -d "$server_dir"
	echo "$current_ver" | tee "$server_dir/version"
	sudo chown -R mc:nogroup "$server_dir"
fi
