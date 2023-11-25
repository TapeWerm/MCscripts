#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mc_cmd.sh SERVICE COMMAND...'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
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

cmd_cursor=$(journalctl "_SYSTEMD_UNIT=$service.service" --show-cursor -n 0 -o cat || true)
cmd_cursor=$(echo "$cmd_cursor" | cut -d ' ' -f 3- -s)
echo "$*" > "/run/$service"
sleep 1
if [ -n "$cmd_cursor" ]; then
	# Output of $service since $cmd_cursor with no metadata
	output=$(journalctl "_SYSTEMD_UNIT=$service.service" --after-cursor "$cmd_cursor" -o cat)
else
	output=$(journalctl "_SYSTEMD_UNIT=$service.service" -o cat)
fi
if [ -z "$output" ]; then
	echo "No output from service after 1 second"
	exit
fi
echo "$output" | /opt/MCscripts/mc_color.sed
