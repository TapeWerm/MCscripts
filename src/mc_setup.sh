#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mc_setup.sh [OPTION]... INSTANCE'

args=$(getopt -l help,import: -o hi: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Make new Minecraft Java Edition server in ~mc/java/INSTANCE or import SERVER_DIR.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-i, --import=SERVER_DIR  minecraft java edition server directory to import'
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
server_dir=~mc/java/$instance
if [ -d "$server_dir" ]; then
	>&2 echo "Server directory $server_dir already exists"
	exit 1
fi

if [ -n "$import" ]; then
	import=$(realpath -- "$import")
fi

if ! command -v java &> /dev/null; then
	>&2 echo "No command java"
	exit 1
fi

mkdir -p ~mc/java
chown mc:nogroup ~mc/java
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
	# Convert DOS line endings to UNIX line endings
	for file in "$server_dir"/*.{json,properties}; do
		if [ -f "$file" ]; then
			sed -i s/$'\r'$// "$file"
		fi
	done
	echo java -jar server.jar nogui > "$server_dir/start.bat"
	chmod +x "$server_dir/start.bat"
	chown -R mc:nogroup "$server_dir"
	trap - ERR
	rm -r "$import"
else
	trap 'rm -rf "$server_dir"' ERR
	mkdir "$server_dir"
	cd "$server_dir"
	/opt/MCscripts/mc_getjar.sh
	# Minecraft Java Edition makes eula.txt on first run
	java -jar server.jar nogui || true
	echo java -jar server.jar nogui > "$server_dir/start.bat"
	chmod +x "$server_dir/start.bat"
	chown -R mc:nogroup "$server_dir"
fi
