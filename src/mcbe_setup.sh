#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_setup.sh [OPTION]... INSTANCE'
version=current
zips_dir=~mc/bedrock_zips

args=$(getopt -l help,preview -o hp -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-p, --preview  use preview instead of current version'
		exit
		;;
	--preview|-p)
		version=preview
		shift
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

instance=$1
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
	>&2 echo No "$version" bedrock-server ZIP found in '~mc'
	exit 1
fi
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

mkdir -p ~mc/bedrock
chown mc:mc ~mc/bedrock
# Test extracting $minecraft_zip partially quietly
unzip -tq "$minecraft_zip"
trap 'rm -rf "$server_dir"' ERR
unzip -q "$minecraft_zip" -d "$server_dir"
echo "$current_ver" > "$server_dir/version"
chown -R mc:mc "$server_dir"
echo "@@@ Remember to edit $server_dir/server.properties @@@"
