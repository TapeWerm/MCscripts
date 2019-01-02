#!/usr/bin/env bash

files='worlds whitelist.json permissions.json server.properties'

if [ -z "$1" -o -z "$2" -o "$1" = -h -o "$1" = --help ]; then
	>&2 echo Updates Minecraft Bedrock Edition server keeping worlds, whitelist, permissions, and properties.
	>&2 echo '`./MCBEupdate.sh $server_dir $minecraft_zip`'
	>&2 echo '$server_dir cannot be ~. Remember to stop server before updating.'
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
if [ "$server_dir" -ef ~ ]; then
	>&2 echo '$server_dir cannot be ~'
	exit 4
fi
server_dir=`realpath "$server_dir"`

minecraft_zip=$2
if [ ! -r "$minecraft_zip" ]; then
	if [ -f "$minecraft_zip" ]; then
		>&2 echo $minecraft_zip is not readable
		exit 2
	fi
	>&2 echo No file $minecraft_zip
	exit 3
fi
minecraft_zip=`realpath "$minecraft_zip"`

cd $server_dir
for file in $files; do
	if [ ! -w "$file" ]; then
		if [ -f "$file" ]; then
			>&2 echo $file is not writable
			exit 2
		fi
		>&2 echo No file $file
		exit 3
	fi
	mv $file ~
done

rm -r $server_dir/*
unzip $minecraft_zip

for file in $files; do
	mv ~/$file .
done
