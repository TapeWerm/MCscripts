#!/usr/bin/env bash

set -e
# Exit if error
backup_dir=/tmp
files='worlds whitelist.json permissions.json server.properties'
pack_dirs='resource_packs behavior_packs'

if [ -z "$1" ] || [ -z "$2" ] || [ "$1" = -h ] || [ "$1" = --help ]; then
	>&2 echo 'Update Minecraft Bedrock Edition server keeping packs, worlds, whitelist, permissions, and properties. You can convert a Windows $server_dir to Ubuntu and vice versa.'
	>&2 echo '`./MCBEupdate.sh $server_dir $minecraft_zip`'
	>&2 echo '$minecraft_zip cannot be in $server_dir. Remember to stop server before updating.'
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
if [ "$server_dir" -ef "$backup_dir" ]; then
	>&2 echo '$server_dir cannot be '"$backup_dir"
	exit 4
fi
backup_dir=$backup_dir/$server_dir

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
trap 'rm -r ./*; cp -r "$backup_dir"/* .; rm -r "$backup_dir"' ERR
rm -r ./*
unzip "$minecraft_zip"

for pack_dir in $pack_dirs; do
	packs=$(ls "$backup_dir/$pack_dir" | grep -Ev 'vanilla|chemistry')
	# 3rd party packs
	echo "$packs" | while read -r pack; do
	# Escape \ while reading line from $packs
		cp -r "$backup_dir/$pack_dir/$pack" "$pack_dir/"
	done
done
for file in $files; do
	cp -r "$backup_dir/$file" .
done
rm -r "$backup_dir"
