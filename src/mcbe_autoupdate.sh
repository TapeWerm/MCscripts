#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_autoupdate.sh SERVER_DIR SERVICE'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and restart service of Minecraft Bedrock Edition server."
		exit
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath "$1")
# cat fails if there's no file $server_dir/version
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)

service=$2
if ! systemctl is-active --quiet "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi
# Trim off $service before last @
instance=${service##*@}

# There might be more than one ZIP in ~mc
minecraft_zip=$(find ~mc/bedrock-server-*.zip 2> /dev/null | xargs -0rd '\n' ls -t | head -n 1)
if [ -z "$minecraft_zip" ]; then
	>&2 echo 'No bedrock-server ZIP found in ~mc'
	exit 1
fi
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

if [ "$installed_ver" = fail ]; then
	echo "Previous update failed, rm $server_dir/version and try again"
	exit 1
elif [ "$installed_ver" != "$current_ver" ]; then
	trap 'echo fail > "$server_dir/version"' ERR
	systemctl start "mcbe-backup@$instance"
	trap 'systemctl start "$service"' EXIT
	systemctl stop "$service.socket"
	# mcbe_update.sh reads y asking if you stopped the server
	runuser -l mc -s /bin/bash -c "echo y | $(printf '/opt/MCscripts/mcbe_update.sh %q %q' "$server_dir" "$minecraft_zip")"
fi
