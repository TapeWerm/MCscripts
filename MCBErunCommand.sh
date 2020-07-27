#!/bin/bash

syntax='Usage: MCBErunCommand.sh SERVICE COMMAND...'

case $1 in
--help|-h)
	echo "$syntax"
	echo "Run a command in the Minecraft server console"
	exit
	;;
esac
if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
fi

service=$1
shift
if ! systemctl is-active --quiet "$service"; then
    >&2 echo "Service $service not active"
    exit 1
fi

cursor_file=$(mktemp runcommand.XXXXXX)
if ! journalctl -n -u "$service" --cursor-file "$cursor_file" > /dev/null
then
    >&2 echo "Failed to get journal cursor"
    exit 2
fi

echo "$@" > "/run/$service"
sleep 1
journalctl -u "$service" --cursor-file "$cursor_file" -o cat
rm "$cursor_file"