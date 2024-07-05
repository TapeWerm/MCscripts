#!/bin/bash

# Exit if error
set -e
syntax='Usage: mcbe_log.sh SERVICE'

send() {
	if [ -f "$discord_file" ]; then
		local url
		while read -r url; do
			curl -X POST -H 'Content-Type: application/json' -d "{\"content\":\"$*\"}" -sS "$url" &
		done < "$discord_file"
	fi
	if [ -f "$rocket_file" ]; then
		local url
		while read -r url; do
			curl -X POST -H 'Content-Type: application/json' -d "{\"text\":\"$*\"}" -sS "$url" &
		done < "$rocket_file"
	fi
	wait
}

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Post Minecraft Bedrock Edition server logs running in service to webhooks (Discord and Rocket Chat).'
		echo
		echo Logs include server start/stop and player connect/disconnect/kicks.
		exit
		;;
	esac
done
shift

if [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

# Trim off $1 after last .service
service=${1%.service}
if ! systemctl is-active -q -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi

# Trim off $service before last @
instance=${service##*@}
discord_file=~/.mcbe_log/${instance}_discord.txt
if [ -f "$discord_file" ]; then
	chmod 600 "$discord_file"
fi
rocket_file=~/.mcbe_log/${instance}_rocket.txt
if [ -f "$rocket_file" ]; then
	chmod 600 "$rocket_file"
fi

send "Server $instance starting"
trap 'send "Server $instance stopping"; pkill -s $$' EXIT
# Follow log for unit $service 0 lines from bottom, no metadata
journalctl "_SYSTEMD_UNIT=$service.service" -fn 0 -o cat | while IFS='' read -r line; do
	if echo "$line" | grep -q 'Player connected'; then
		# Gamertags can have spaces as long as they're not leading/trailing/contiguous
		# shellcheck disable=SC2001
		player=$(echo "$line" | sed 's/.*Player connected: \(.*\), xuid:.*/\1/')
		send "$player connected to $instance"
	elif echo "$line" | grep -q 'Player disconnected'; then
		# shellcheck disable=SC2001
		player=$(echo "$line" | sed 's/.*Player disconnected: \(.*\), xuid:.*/\1/')
		send "$player disconnected from $instance"
	elif echo "$line" | grep -q Kicked; then
		# shellcheck disable=SC2001
		player=$(echo "$line" | sed 's/.*Kicked \(.*\) from the game.*/\1/')
		# shellcheck disable=SC2001
		reason=$(echo "$line" | sed "s/.*from the game: '\(.*\)'.*/\1/")
		# Trim off leading space from $reason
		reason=${reason# }
		send "$player was kicked from $instance because $reason"
	fi
done
