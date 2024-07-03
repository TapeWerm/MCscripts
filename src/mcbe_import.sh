#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_import.sh [OPTION]... SERVER_DIR INSTANCE'
update=true
version=current
zips_dir=~mc/bedrock_zips

args=$(getopt -l help,no-update,preview -o hnp -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Import Minecraft Bedrock Edition server to ~mc/bedrock/INSTANCE.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo "-n, --no-update  don't update minecraft bedrock edition server"
		echo '-p, --preview    use preview instead of current version'
		exit
		;;
	--no-update|-n)
		update=false
		shift
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

import=$(realpath -- "$1")

instance=$2
if [ "$instance" != "$(systemd-escape -- "$instance")" ]; then
	>&2 echo INSTANCE should be indentical to systemd-escape INSTANCE
	exit 1
fi
server_dir=~mc/bedrock/$instance
if [ -d "$server_dir" ]; then
	>&2 echo "Server directory $server_dir already exists"
	exit 1
fi

if [ -h "$zips_dir/$version" ]; then
	minecraft_zip=$(realpath "$zips_dir/$version")
else
	>&2 echo "No bedrock-server ZIP $zips_dir/$version"
	exit 1
fi

mkdir -p ~mc/bedrock
chown mc:mc ~mc/bedrock

echo "Enter Y if you stopped the server to import"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

trap 'rm -rf "$server_dir"' ERR
cp -r "$import" "$server_dir"
# Convert DOS line endings to UNIX line endings
for file in "$server_dir"/*.{json,properties}; do
	if [ -f "$file" ]; then
		sed -i 's/\r$//' "$file"
	fi
done
chown -R mc:mc "$server_dir"
if [ "$update" = true ]; then
	# mcbe_update.sh reads y asking if you stopped the server
	echo y | runuser -u mc -- /opt/MCscripts/bin/mcbe_update.sh -- "$server_dir" "$minecraft_zip"
fi
trap - ERR
rm -r "$import"
echo "@@@ Remember to edit $server_dir/server.properties @@@"
