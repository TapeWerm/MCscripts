#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_autoupdate.sh [OPTION]... SERVER_DIR SERVICE'
version=current
zips_dir=~mc/bedrock_zips

args=$(getopt -l help,preview -o hp -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "If SERVER_DIR/version isn't the same as the ZIP in ~mc, back up, update, and restart service of Minecraft Bedrock Edition server."
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-p, --preview  update to preview instead of current version'
		exit
		;;
	--preview|-p)
		version=preview
		shift
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

server_dir=$(realpath -- "$1")
# cat fails if there's no file $server_dir/version
installed_ver=$(cat "$server_dir/version" 2> /dev/null || true)

# Trim off $2 after last .service
service=${2%.service}
if ! systemctl is-active -q -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi
# Trim off $service before last @
instance=${service##*@}

if [ -h "$zips_dir/$version" ]; then
	minecraft_zip=$(realpath "$zips_dir/$version")
else
	>&2 echo "No bedrock-server ZIP $zips_dir/$version"
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
	runuser -l mc -s /bin/bash -c "$(printf 'echo y | /opt/MCscripts/bin/mcbe_update.sh -- %q %q' "$server_dir" "$minecraft_zip")"
fi
