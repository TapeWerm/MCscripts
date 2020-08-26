#!/usr/bin/env bash

# Exit if error
set -e
# $0 is the path
dir=$(dirname "$0")
syntax='Usage: MCrunCmd.sh SERVICE COMMAND...'

case $1 in
--help|-h)
	echo "$syntax"
	echo "Run command in the server console of Minecraft Java Edition or Bedrock Edition server running in service."
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

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo "$*" | sudo tee "/run/$service" > /dev/null
sleep 1
# Output of $service since $timestamp with no metadata
buffer=$(journalctl -u "$service" -S "$timestamp" -o cat)
if [ -z "$buffer" ]; then
	echo "No output from service"
	exit
fi
echo "$buffer" | "$dir/MCcolor.sed"
