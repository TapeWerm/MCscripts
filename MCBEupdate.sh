#!/usr/bin/env bash

set -e
# Exit if error
backup_dir=/tmp
files='worlds whitelist.json permissions.json server.properties'

if [ -z "$1" ] || [ -z "$2" ] || [ "$1" = -h ] || [ "$1" = --help ]; then
	>&2 echo Update Minecraft Bedrock Edition server keeping worlds, whitelist, permissions, and properties.
	>&2 echo '`./MCBEupdate.sh $server_dir $minecraft_zip`'
	>&2 echo Remember to stop server before updating.
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
if [ "$server_dir" -ef "$backup_dir" ]; then
	>&2 echo '$server_dir cannot be '"$backup_dir"
	exit 4
fi
server_dir=$(realpath "$server_dir")

minecraft_zip=$(realpath "$2")

cd "$server_dir"
for file in $files; do
	mv "$file" "$backup_dir/"
done

rm -r "$server_dir"/*
unzip "$minecraft_zip"

for file in $files; do
	mv "$backup_dir/$file" .
done
