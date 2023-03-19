#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mcbe_update.sh SERVER_DIR MINECRAFT_ZIP`'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Update Minecraft Bedrock Edition server keeping packs, worlds, JSON files, and PROPERTIES files. Other files will be removed. You can convert a Windows SERVER_DIR to Ubuntu and vice versa if you convert line endings.
		echo
		echo MINECRAFT_ZIP cannot be in SERVER_DIR. Remember to stop server before updating.
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

server_dir=$(realpath -- "$1")
if [ ! -f "$server_dir/bedrock_server" ] && [ ! -f "$server_dir/bedrock_server.exe" ]; then
	>&2 echo SERVER_DIR should have file bedrock_server or bedrock_server.exe
	exit 1
fi
new_dir=$server_dir.new
old_dir=$server_dir.old

minecraft_zip=$(realpath -- "$2")
if [ -n "$(find "$server_dir" -wholename "$minecraft_zip")" ]; then
	>&2 echo MINECRAFT_ZIP cannot be in SERVER_DIR
	exit 1
fi
# Test extracting $minecraft_zip partially quietly
unzip -tq "$minecraft_zip"

echo "Enter Y if you backed up and stopped the server to update"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

rm -rf "$new_dir"
trap 'rm -rf "$new_dir"; echo fail > "$server_dir/version"' ERR
unzip -q "$minecraft_zip" -d "$new_dir"

# Trim off $minecraft_zip after last .zip
basename "${minecraft_zip%.zip}" > "$new_dir/version"
cp -r "$server_dir/worlds" "$new_dir/"

while read -r file; do
	file=$(basename "$file")
	cp "$server_dir/$file" "$new_dir/"
done < <(ls "$server_dir"/*.{json,properties} 2> /dev/null)

while read -r pack_dir; do
	pack_dir=$(basename "$pack_dir")
	mkdir -p "$new_dir/$pack_dir"
	while read -r pack; do
		# Don't clobber 1st party packs
		if [ ! -d "$new_dir/$pack_dir/$pack" ]; then
			cp -r "$server_dir/$pack_dir/$pack" "$new_dir/$pack_dir/"
		fi
	done < <(ls "$server_dir/$pack_dir")
done < <(ls -d "$server_dir"/*_packs 2> /dev/null)

rm -rf "$old_dir"
trap '' SIGTERM
mv "$server_dir" "$old_dir"
mv "$new_dir" "$server_dir"
rm -rf "$old_dir"
