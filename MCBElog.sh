#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: MCBElog.sh SERVICE'

send() {
	status=$(systemctl status "mcbe-bot@$instance" | cut -d $'\n' -f 3 | awk '{print $2}')
	if [ "$status" = active ]; then
		echo "PRIVMSG $chan :$*" >> ~mc/.MCBE_Bot/"${instance}_BotBuffer"
	fi
}

case $1 in
--help|-h)
	echo "$syntax"
	echo Post Minecraft Bedrock Edition server connect/disconnect messages running in service to IRC.
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
status=$(systemctl status "$service" | cut -d $'\n' -f 3 | awk '{print $2}')
if [ "$status" != active ]; then
	>&2 echo "Service $service not active"
	exit 1
fi

# Trim off $service before last @
instance=${service##*@}
join_file=~mc/.MCBE_Bot/${instance}_BotJoin.txt
join=$(cut -d $'\n' -f 1 < "$join_file")
chans=$(echo "$join" | cut -d ' ' -f 2)
# Trim off $chans after first ,
chan=${chans%%,*}

# Follow log for unit $service 0 lines from bottom, no metadata
# Escape \ while reading line from journalctl
journalctl -fu "$service" -n 0 -o cat | while read -r line; do
	if echo "$line" | grep -q 'Player connected'; then
		player=$(echo "$line" | cut -d ' ' -f 6)
		player=${player%,}
		send "$player connected"
	elif echo "$line" | grep -q 'Player disconnected'; then
		player=$(echo "$line" | cut -d ' ' -f 6)
		player=${player%,}
		send "$player disconnected"
	fi
done
