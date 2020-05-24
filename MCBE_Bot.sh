#!/usr/bin/env bash
# Based on kekbot by dom, Aatrox, and Hunner from the CAT @ Portland State University.

input() {
	# $USER, $HOSTNAME, and $fqdn are verified, name is clearly not
	echo "USER $(whoami) $HOSTNAME $fqdn :The Mafia"
	echo "NICK $nick"
	echo "$join"
	# Last 10 lines of $buffer as IRC appends to it
	tail -f "$buffer"
}

ping_timeout() {
	diff=0
	# 15 minute timeout
	# irc.cat.pdx.edu ping timeout is 4m20s
	while [ "$diff" -lt 900 ]; do
		sleep 1
		# Seconds since epoch
		thyme=$(date +%s)
		# File modification time in seconds since epoch
		mthyme=$(stat -c %Y "$ping_time")
		diff=$((thyme - mthyme))
	done
	# Kill script process
	# exit does not exit script when forked
	kill $$
	exit
}

send() {
	# Avoid filename expansion
	echo "$*" >> "$buffer"
}

# If $1 doesn't exist
if [ -z "$1" ]; then
	nick=MCBE_Bot
else
	nick=$1
fi
# Make directory and parents quietly
mkdir -p ~/.MCBE_Bot
buffer=~/.MCBE_Bot/${nick}Buffer
# Kill all doppelgangers
# Duplicate bots exit if $buffer is removed
rm -f "$buffer"
mkfifo "$buffer"
ping_time=~/.MCBE_Bot/${nick}Ping
touch "$ping_time"

join_file=~/.MCBE_Bot/${nick}Join.txt
join=$(cut -d $'\n' -f 1 < "$join_file")
server=$(cut -d $'\n' -f 2 -s < "$join_file")

# DNS check
# Trim off $server after first :
if ! stdout=$(host "${server%%:*}"); then
	>&2 echo "$stdout"
	exit 1
fi
fqdn=$(host "$HOSTNAME" | head -n 1 | cut -d ' ' -f 1)

ping_timeout &

input | openssl s_client -connect "$server" 2>&1 | while read -r irc; do
	# If disconnected MCBE_Bot reads an empty string
	if [ -n "$irc" ]; then
		# Reset timeout
		touch "$ping_time"
		echo "$irc"
		if [ "$(echo "$irc" | cut -d ' ' -f 1)" = PING ]; then
			send PONG
		elif [ "$(echo "$irc" | cut -d ' ' -f 1)" = ERROR ]; then
			if echo "$irc" | grep -q 'Closing Link'; then
				kill $$
				exit
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2 -s)" = NOTICE ]; then
			if echo "$irc" | grep -q 'Server Terminating'; then
				kill $$
				exit
			fi
		elif [[ "$(echo "$irc" | cut -d ' ' -f 1)" =~ connect:errno=[0-9]+ ]]; then
			kill $$
			exit
		fi
	fi
done
