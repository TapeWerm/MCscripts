#!/usr/bin/env bash

syntax='Usage: MCstop.sh [OPTION] ... SESSIONNAME'

server_do() {
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
}

countdown() {
	warning="Server stopping in $*"
	server_do say "$warning"
	echo "$warning"
}

args=$(getopt -l help,tmux-socket: -o ht: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Warn Minecraft Java Edition or Bedrock Edition server running in tmux session 10 seconds before stopping.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-t, --tmux-socket=TMUX_SOCKET  socket tmux session is on'
		echo
		echo Best ran by systemd before shutdown.
		exit
		;;
	--tmux-socket|-t)
		tmux_socket=$2
		shift 2
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

sessionname=$1

if [ -n "$tmux_socket" ]; then
	# Remove trailing slash
	tmux_socket=${tmux_socket%/}
else
	# $USER = `whoami` and is not set in cron
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
	exit 1
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
