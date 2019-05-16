#!/usr/bin/env bash

set -e
# Exit if error
files='worlds whitelist.json permissions.json server.properties'
pack_dirs='resource_packs behavior_packs'
syntax='`./MCBEupdate.sh $server_dir $minecraft_zip`'

case $1 in
--help|-h)
	echo 'Update Minecraft Bedrock Edition server keeping packs, worlds, whitelist, permissions, and properties. You can convert a Windows $server_dir to Ubuntu and vice versa.'
	echo "$syntax"
	echo '$minecraft_zip cannot be in $server_dir. Remember to stop server before updating.'
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
backup_dir=/tmp/$(basename "$server_dir")
if [ -f "$backup_dir" ]; then
	>&2 echo "Backup dir $backup_dir already exists, check and remove it"
	exit 7
fi

minecraft_zip=$(realpath "$2")
if [ -n "$(find "$server_dir" -wholename "$minecraft_zip")" ]; then
	>&2 echo '$minecraft_zip cannot be in $server_dir'
	exit 6
fi
unzip -tq "$minecraft_zip"
# Test extracting $minecraft_zip partially quietly

echo "Enter Y if you stopped the server you're updating"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 5
fi

cd "$server_dir"
trap 'rm -rf "$backup_dir"' ERR
cp -r . "$backup_dir"
trap 'cp -rn "$backup_dir"/* .; rm -rf "$backup_dir"' ERR
rm -r ./*
trap 'rm -r ./*; cp -r "$backup_dir"/* .; rm -rf "$backup_dir"' ERR
unzip "$minecraft_zip"

for pack_dir in $pack_dirs; do
	packs=$(ls "$backup_dir/$pack_dir" | grep -Ev 'vanilla|chemistry' || true)
	# 3rd party packs
	# grep fails if there's no match
	echo "$packs" | while read -r pack; do
	# Escape \ while reading line from $packs
		cp -r "$backup_dir/$pack_dir/$pack" "$pack_dir/"
	done
done
for file in $files; do
	cp -r "$backup_dir/$file" .
done
rm -r "$backup_dir"
