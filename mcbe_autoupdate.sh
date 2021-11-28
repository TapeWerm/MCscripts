#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_autoupdate.sh [OPTION]... SERVER_DIR'

args=$(getopt -l help,service: -o hs: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and restart service of Minecraft Bedrock Edition server. If there's no service, make and chown mc SERVER_DIR."
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

server_dir=$(realpath "$1")
# cat fails if there's no file $server_dir/version
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)
# There might be more than one ZIP in ~mc
minecraft_zip=$(find ~mc/bedrock-server-*.zip 2> /dev/null | xargs -0rd '\n' ls -t | head -n 1)
if [ -z "$minecraft_zip" ]; then
	>&2 echo 'No bedrock-server ZIP found in ~mc'
	exit 1
fi
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

if [ -n "$service" ]; then
	if ! systemctl is-active --quiet "$service"; then
		>&2 echo "Service $service not active"
		exit 1
	fi
fi
# Trim off $service before last @
instance=${service##*@}

if [ -n "$service" ]; then
	if [ "$installed_ver" = fail ]; then
		echo "Previous update failed, rm $server_dir/version and try again"
		exit 1
	elif [ "$installed_ver" != "$current_ver" ]; then
		trap 'echo fail > "$server_dir/version"' ERR
		systemctl start "mcbe-backup@$instance"
		systemctl stop "$service.socket"
		trap 'systemctl start "$service"' ERR
		# mcbe_update.sh reads y asking if you stopped the server
		su mc -s /bin/bash -c "echo y | ~/mcbe_update.sh $server_dir $minecraft_zip"
		systemctl start "$service"
	fi
else
	if [ -d "$server_dir" ]; then
		>&2 echo "Server directory $server_dir already exists"
		exit 1
	fi
	# Test extracting $minecraft_zip partially quietly
	unzip -tq "$minecraft_zip"
	trap 'rm -rf "$server_dir"' ERR
	unzip -q "$minecraft_zip" -d "$server_dir"
	echo "$current_ver" > "$server_dir/version"
	chown -R mc:nogroup "$server_dir"
	echo "@@@ Don't forget to edit $server_dir/server.properties @@@"
fi
