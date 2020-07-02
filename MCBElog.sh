#!/usr/bin/env bash

syntax='Usage: MCBElog.sh SERVICE'

send() {
	status=$(systemctl show "mcbe-bot@$instance" -p ActiveState --value)
	if [ "$status" = active ]; then
		if [ -f "$join_file" ]; then
			join=$(grep '^JOIN ' "$join_file")
			chans=$(echo "$join" | cut -d ' ' -f 2 -s)
			# Trim off $chans after first ,
			chan=${chans%%,*}
		fi
		echo "PRIVMSG $chan :$*" >> ~mc/.MCBE_Bot/"${instance}_BotBuffer"
	fi
	if [ -f ~mc/.MCBE_Bot/"${instance}_BotWebhook.txt" ]; then
		# Escape \ while reading line from file
		while read -r url; do
			if echo "$url" | grep -Eq 'https://discord(app)?\.com'; then
				curl -X POST -H 'Content-Type: application/json' -d "{\"content\":\"$*\"}" "$url"
			# Rocket Chat can be hosted by any domain
			elif echo "$url" | grep -q 'https://rocket\.'; then
				curl -X POST -H 'Content-Type: application/json' -d "{\"text\":\"$*\"}" "$url"
			fi
		done < ~mc/.MCBE_Bot/"${instance}_BotWebhook.txt"
	fi
}

case $1 in
--help|-h)
	echo "$syntax"
	echo 'Post Minecraft Bedrock Edition server logs running in service to IRC and webhooks (Discord and Rocket Chat).'
	echo
	echo Logs include server start/stop and player connect/disconnect/kicks.
	exit
	;;
esac

if [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

service=$1
status=$(systemctl show "$service" -p ActiveState --value)
if [ "$status" != active ]; then
	>&2 echo "Service $service not active"
	exit 1
fi

# Trim off $service before last @
instance=${service##*@}
join_file=~mc/.MCBE_Bot/${instance}_BotJoin.txt

# Follow log for unit $service 0 lines from bottom, no metadata
journalctl -fu "$service" -n 0 -o cat | while read -r line; do
	if echo "$line" | grep -q 'Player connected'; then
		# Gamertags can have spaces as long as they're not leading/trailing/contiguous
		player=$(echo "$line" | cut -d ' ' -f 6- -s | cut -d , -f 1)
		send "$player connected to $instance"
	elif echo "$line" | grep -q 'Player disconnected'; then
		player=$(echo "$line" | cut -d ' ' -f 6- -s | cut -d , -f 1)
		send "$player disconnected from $instance"
	elif echo "$line" | grep -q Kicked; then
		player=$(echo "$line" | cut -d ' ' -f 2- -s | sed 's/ from the game:.*//')
		reason=$(echo "$line" | cut -d "'" -f 2- -s)
		# Trim off trailing ' from $reason
		reason=${reason%"'"}
		# Trim off leading space from $reason
		reason=${reason#' '}
		send "$player was kicked from $instance because $reason"
	elif echo "$line" | grep -q 'Server started.'; then
		send "Server $instance started"
	elif echo "$line" | grep -q 'Stopping Minecraft Bedrock Edition server'; then
		send "Server $instance stopping"
	fi
done
