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
		import=$(realpath "$2")
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
if [ "$instance" != "$(systemd-escape "$instance")" ]; then
	>&2 echo INSTANCE should be indentical to systemd-escape INSTANCE
	exit 1
fi
server_dir=~mc/bedrock/$instance

mkdir -p ~mc/bedrock
if [ -n "$import" ]; then
	echo "Enter Y if you stopped the server to import"
	read -r input
	input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
	if [ "$input" != y ]; then
		>&2 echo "$input != y"
		exit 1
	fi

	mv "$import" "$server_dir"
	trap 'mv "$server_dir" "$import"' ERR
	systemctl start mcbe-getzip
	# There might be more than one ZIP in ~mc
	minecraft_zip=$(find ~mc/bedrock-server-*.zip 2> /dev/null | xargs -0rd '\n' ls -t | head -n 1)
	# mcbe_update.sh reads y asking if you stopped the server
	echo y | ~mc/mcbe_update.sh "$server_dir" "$minecraft_zip"
	# Convert DOS line endings to UNIX line endings
	for file in "$server_dir"/*.{json,properties}; do
		sed -i s/$'\r'$// "$file"
	done
	chown -R mc:nogroup "$server_dir"
else
	su mc -s /bin/bash -c '~mc/mcbe_getzip.sh'
	~mc/mcbe_autoupdate.sh "$server_dir"
fi
