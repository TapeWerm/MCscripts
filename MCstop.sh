#!/usr/bin/env bash

syntax='Usage: MCstop.sh SERVICE'

server_do() {
	echo "$*" > "/run/$service"
}

countdown() {
	warning="Server stopping in $*"
	server_do say "$warning"
	echo "$warning"
}

case $1 in
--help|-h)
	echo "$syntax"
	echo Warn Minecraft Java Edition or Bedrock Edition server running in service 10 seconds before stopping.
	echo
	echo Best ran by systemd before shutdown.
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
systemctl status "$service" > /dev/null

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
