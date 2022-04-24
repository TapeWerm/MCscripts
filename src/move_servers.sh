#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: move_servers.sh'
temp_dir=/tmp/move_servers

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "Find Minecraft Java Edition or Bedrock Edition servers and their backups in ~mc and move them into the ~mc/java or ~mc/bedrock directory if they're not already there."
		exit
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

while read -r dir; do
	if [ -f ~mc/"$dir"/server.jar ]; then
		java+=("$dir")
	fi
	if [ -f ~mc/"$dir"/bedrock_server ]; then
		bedrock+=("$dir")
	fi
done < <(find ~mc -mindepth 1 -maxdepth 1 -type d -printf '%P\n')

if [ -z "${java[*]}" ] && [ -z "${bedrock[*]}" ]; then
	echo No servers to move
	exit
fi
echo "Java servers to move: ${java[*]}"
echo "Bedrock servers to move: ${bedrock[*]}"
echo "Enter Y if you stopped the servers to move (disable_services.sh stops them)"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

mkdir -p "$temp_dir"
# If $server is named java or bedrock, it will collide with the java/bedrock directory unless you move it
for server in "${java[@]}"; do
	mv ~mc/"$server" "$temp_dir/"
done
for server in "${bedrock[@]}"; do
	mv ~mc/"$server" "$temp_dir/"
done

if [ -n "${java[*]}" ]; then
	mkdir -p ~mc/java
	chown mc:nogroup ~mc/java
	if [ ! ~mc/backup_dir -ef ~mc ]; then
		mkdir -p ~mc/backup_dir/java
		# Some file systems do not have owners
		chown -f mc:nogroup ~mc/backup_dir/java || true
	fi
fi
for server in "${java[@]}"; do
	mv "$temp_dir/$server" ~mc/java/
	if [ -d ~mc/backup_dir/"$server"_Backups ]; then
		mv ~mc/backup_dir/"$server"_Backups ~mc/backup_dir/java/
	fi
done

if [ -n "${bedrock[*]}" ]; then
	mkdir -p ~mc/bedrock
	chown mc:nogroup ~mc/bedrock
	if [ ! ~mc/backup_dir -ef ~mc ]; then
		mkdir -p ~mc/backup_dir/bedrock
		# Some file systems do not have owners
		chown -f mc:nogroup ~mc/backup_dir/bedrock || true
	fi
fi
for server in "${bedrock[@]}"; do
	mv "$temp_dir/$server" ~mc/bedrock/
	if [ -d ~mc/backup_dir/"$server"_Backups ]; then
		mv ~mc/backup_dir/"$server"_Backups ~mc/backup_dir/bedrock/
	fi
done

rmdir "$temp_dir"
