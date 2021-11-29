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
server_dir=~mc/java/$instance

mkdir -p ~mc/java
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
else
	mkdir "$server_dir"
	trap 'rm -r "$server_dir"' ERR
	cd "$server_dir"
	~mc/mc_getjar.sh
	# Minecraft Java Edition makes eula.txt on first run
	java -jar server.jar nogui || true
fi
echo java -jar server.jar nogui > "$server_dir/start.bat"
chmod +x "$server_dir/start.bat"
chown -R mc:nogroup "$server_dir"
