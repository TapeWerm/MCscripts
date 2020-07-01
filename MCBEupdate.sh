#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: MCBEupdate.sh SERVER_DIR MINECRAFT_ZIP`'

case $1 in
--help|-h)
	echo "$syntax"
	echo Update Minecraft Bedrock Edition server keeping packs, worlds, JSON files, and PROPERTIES files. Other files will be removed. You can convert a Windows SERVER_DIR to Ubuntu and vice versa.
	echo
	echo MINECRAFT_ZIP cannot be in SERVER_DIR. Remember to stop server before updating.
	exit
	;;
esac
if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath "$1")
backup_dir=/tmp/MCBEupdate/$(basename "$server_dir")

minecraft_zip=$(realpath "$2")
if [ -n "$(find "$server_dir" -wholename "$minecraft_zip")" ]; then
	>&2 echo MINECRAFT_ZIP cannot be in SERVER_DIR
	exit 1
fi
# Test extracting $minecraft_zip partially quietly
unzip -tq "$minecraft_zip"

echo "Enter Y if you backed up and stopped the server you're updating"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

mkdir -p "$(dirname "$backup_dir")"
if [ -f "$backup_dir" ]; then
	>&2 echo "Backup dir $backup_dir already exists, check and remove it"
	exit 1
fi
mv "$server_dir" "$backup_dir"
trap 'rm -rf "$server_dir"; mv "$backup_dir" "$server_dir"; echo fail > "$server_dir/version"' ERR
unzip "$minecraft_zip" -d "$server_dir"

cd "$server_dir"
# Trim off $minecraft_zip after last .zip
basename "${minecraft_zip%.zip}" > version
for pack_dir in *_packs; do
	packs=$(ls "$backup_dir/$pack_dir")
	# Escape \ while reading line from $packs
	echo "$packs" | while read -r pack; do
		# Don't clobber 1st party packs
		if [ ! -d "$pack_dir/$pack" ]; then
			cp -r "$backup_dir/$pack_dir/$pack" "$pack_dir/"
		fi
	done
done
for file in worlds *.json *.properties; do
	cp -r "$backup_dir/$file" .
done
rm -r "$backup_dir"
