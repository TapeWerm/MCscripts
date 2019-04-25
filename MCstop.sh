#!/usr/bin/env bash

server_do() {
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
}

countdown() {
	warning="Server stopping in $*"
	server_do say "$warning"
	echo "$warning"
}

syntax() {
	echo '`./MCstop.sh $sessionname [$tmux_socket]`'
}

if [ "$1" = -h ] || [ "$1" = --help ]; then
	echo Warn Minecraft Java Edition or Bedrock Edition server running in tmux session 10 seconds before stopping.
	syntax
	echo Best ran by systemd before shutdown.
	exit
elif [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	syntax
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	syntax
	exit 1
fi

sessionname=$1

if [ -n "$2" ]; then
	tmux_socket=${2%/}
	# Remove trailing slash
else
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
	# $USER = `whoami` and is not set in cron
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
        exit 2
fi

countdown 10 seconds
sleep 5
server_do say "It was nice knowing you. What's your name again?"
sleep 2
countdown 3 seconds
sleep 1
countdown 2 seconds
sleep 1
countdown 1 second
sleep 1

server_do stop
