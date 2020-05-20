#!/usr/bin/env bash
# Based on kekbot by dom, Aatrox, and Hunner from the CAT @ Portland State University.

# $USER = `whoami` and is not set in cron
uid=$(id -u "$(whoami)")
ram=/dev/shm/$uid
ram_dir=$ram/MCBE_Bot

send() {
	# Avoid filename expansion
	echo "-> $*"
	echo "$*" >> "$buffer"
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

join_file=~/.MCBE_Bot/${nick}Join.txt
join=$(cut -d $'\n' -f 1 < "$join_file")
server=$(cut -d $'\n' -f 2 -s < "$join_file")

timeout=0
# Trim off $server after first :
until host "${server%%:*}" > /dev/null; do
	if [ "$timeout" = 10 ]; then
		>&2 host "${server%%:*}"
		exit 1
	fi
	sleep 1
	timeout=$(( ++timeout ))
done
fqdn=$(getent ahostsv4 "$HOSTNAME" | head -n 1 | awk '{print $3}')

mkdir -p "$ram_dir"
# Forked processes cannot share variables
ping_time=$ram_dir/$nick
touch "$ping_time"
trap 'rm -r "$ram_dir"; rmdir --ignore-fail-on-non-empty "$ram"' EXIT

ping_timeout &

# Last 10 lines of $buffer as IRC appends to it
tail -f "$buffer" | openssl s_client -connect "$server" | while true; do
	if [ -z "$started" ]; then
		# $USER, $HOSTNAME, and $fqdn are verified, name is clearly not
		send "USER $(whoami) $HOSTNAME $fqdn :The Mafia"
		send "NICK $nick"
		send "$join"
		started=true
	fi

	read -r irc
	# If disconnected MCBE_Bot reads an empty string
	if [ -n "$irc" ]; then
		# Reset timeout
		touch "$ping_time"
		echo "<- $irc"
		if [ "$(echo "$irc" | cut -d ' ' -f 1)" = PING ]; then
			send PONG
		elif [ "$(echo "$irc" | cut -d ' ' -f 1)" = ERROR ]; then
			if echo "$irc" | grep -q 'Closing Link'; then
				exit
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = NOTICE ]; then
			if echo "$irc" | grep -q 'Server Terminating'; then
				exit
			fi
		fi
	fi
done
