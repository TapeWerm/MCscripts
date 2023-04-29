#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mc_cmd.sh SERVICE COMMAND...'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "Run command in the server console of Minecraft Java Edition or Bedrock Edition server running in service."
		exit
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
fi

# Trim off $1 after last .service
service=${1%.service}
shift
if ! systemctl is-active --quiet -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi

cmd_time=$(date '+%Y-%m-%d %H:%M:%S')
echo "$*" > "/run/$service"
sleep 1
# Output of $service since $cmd_time with no metadata
output=$(journalctl -u "$service" -S "$cmd_time" -o cat)
if [ -z "$output" ]; then
	echo "No output from service after 1 second"
	exit
fi
echo "$output" | /opt/MCscripts/mc_color.sed
