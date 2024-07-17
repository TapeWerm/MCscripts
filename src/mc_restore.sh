#!/bin/bash

# Exit if error
set -e
syntax='Usage: mc_restore.sh SERVER_DIR BACKUP'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Restore backup for Minecraft Java Edition server.'
		echo
		echo 'Positional arguments:'
		echo 'SERVER_DIR  Minecraft Java Edition server directory'
		echo 'BACKUP      Minecraft Java Edition backup'
		exit
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo 'Not enough arguments'
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo 'Too much arguments'
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath -- "$1")
properties=$server_dir/server.properties
world=$(grep ^level-name= "$properties" | cut -d = -f 2- -s)
# Trim off $world after last carriage return
world=$(basename -- "${world%$'\r'}")
if [ -z "$world" ]; then
	>&2 echo 'No level-name in server.properties'
	exit 1
fi

backup=$(realpath -- "$2")
# Test extracting $backup partially quietly
unzip -tq "$backup"

echo 'Enter Y if you stopped the server to restore'
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

rm -rf "${server_dir:?}/$world"
unzip "$backup" -d "$server_dir"
chown -R mc:mc "$server_dir/$world"
