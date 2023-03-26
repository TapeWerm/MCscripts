#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_setup.sh [OPTION]... INSTANCE'

args=$(getopt -l help,import: -o hi: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Make new Minecraft Bedrock Edition server in ~mc/bedrock/INSTANCE or import SERVER_DIR.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-i, --import=SERVER_DIR  server directory to import'
		exit
		;;
	--import|-i)
		import=$2
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

if [ -n "$import" ]; then
	import=$(realpath -- "$import")
fi

runuser -l mc -s /bin/bash -c '/opt/MCscripts/mcbe_getzip.sh'
# There might be more than one ZIP in ~mc
minecraft_zip=$(find ~mc/bedrock-server-*.zip 2> /dev/null | xargs -0rd '\n' ls -t | head -n 1)
if [ -z "$minecraft_zip" ]; then
	>&2 echo 'No bedrock-server ZIP found in ~mc'
	exit 1
fi
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

mkdir -p ~mc/bedrock
chown mc:nogroup ~mc/bedrock
if [ -n "$import" ]; then
	echo "Enter Y if you stopped the server to import"
	read -r input
	input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
	if [ "$input" != y ]; then
		>&2 echo "$input != y"
		exit 1
	fi

	trap 'rm -rf "$server_dir"' ERR
	cp -r "$import" "$server_dir"
	# mcbe_update.sh reads y asking if you stopped the server
	echo y | /opt/MCscripts/mcbe_update.sh "$server_dir" "$minecraft_zip"
	# Convert DOS line endings to UNIX line endings
	for file in "$server_dir"/*.{json,properties}; do
		if [ -f "$file" ]; then
			if grep -q $'\r'$ "$file"; then
				sed -i s/$'\r'$// "$file"
			fi
		fi
	done
	chown -R mc:nogroup "$server_dir"
	trap - ERR
	rm -r "$import"
else
	# Test extracting $minecraft_zip partially quietly
	unzip -tq "$minecraft_zip"
	trap 'rm -rf "$server_dir"' ERR
	unzip -q "$minecraft_zip" -d "$server_dir"
	echo "$current_ver" > "$server_dir/version"
	chown -R mc:nogroup "$server_dir"
	echo "@@@ Don't forget to edit $server_dir/server.properties @@@"
fi
