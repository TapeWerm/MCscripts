#!/usr/bin/env bash

# Exit if error
set -e
# $0 is this script
dir=$(dirname "$0")
syntax='Usage: MCBEautoUpdate.sh [OPTION] ... SERVER_DIR'

args=$(getopt -l help,service: -o hs: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'If $server_dir/version '"isn't the same as the ZIP in ~mc, update and restart service of Minecraft Bedrock Edition server. If there's no service, make and chown mc "'$server_dir.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-s, --service=SERVICE  service of Minecraft Bedrock Edition server'
		exit
		;;
	--service|-s)
		service=$2
		shift 2
		;;
	esac
done
shift

if [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$1
# cat fails if there's no file $server_dir/version
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)
# There might be more than one ZIP in ~mc
# ls fails if there's no match
minecraft_zip=$(find ~mc/bedrock-server-[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\.zip 2> /dev/null | head -n 1 || true)
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

if [ -n "$service" ]; then
	status=$(systemctl status "$service" | cut -d $'\n' -f 3 | awk '{print $2}')
	if [ "$status" != active ]; then
		>&2 echo "Service $service not active"
		exit 3
	fi
fi

if [ -n "$service" ]; then
	if [ "$installed_ver" = fail ]; then
		echo Previous update failed, rm "$server_dir/version" and try again
		exit 3
	elif [ "$installed_ver" != "$current_ver" ]; then
		sudo systemctl stop "$service"
		trap 'sudo chown -R mc:nogroup "$server_dir"; sudo systemctl start "$service"' ERR
		# MCBEupdate.sh reads y asking if you stopped the server
		echo y | sudo "$dir/MCBEupdate.sh" "$server_dir" "$minecraft_zip"
		sudo chown -R mc:nogroup "$server_dir"
		sudo systemctl start "$service"
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
