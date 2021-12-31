#!/usr/bin/env bash

syntax='Usage: mc_stop.sh [OPTION]... SERVICE'

server_do() {
	echo "$*" > "/run/$service"
}

countdown() {
	warning="Server stopping in $*"
	server_do say "$warning"
	echo "$warning"
}

args=$(getopt -l help,seconds: -o hs: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Warn Minecraft Java Edition or Bedrock Edition server running in service 10 seconds before stopping.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-s, --seconds=SECONDS  seconds before stopping. must be between 0 and 60. defaults to 10'
		echo
		echo Best ran by systemd before shutdown.
		exit
		;;
	--seconds|-s)
		seconds=$2
		if [[ ! "$seconds" =~ ^-?[0-9]+$ ]]; then
			>&2 echo SECONDS must be an integer
			exit 1
		fi
		if [ "$seconds" -lt 0 ] || [ "$seconds" -gt 60 ]; then
			>&2 echo SECONDS must be between 0 and 60
			exit 1
		fi
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

service=$1
if [ -z "$MAINPID" ]; then
	MAINPID=$(systemctl show "$service" -p MainPID --value)
fi
if [ "$MAINPID" = 0 ]; then
	echo "Service $service already stopped"
	exit
fi

if [ -z "$seconds" ]; then
	seconds=10
fi

if [ "$seconds" -gt 3 ]; then
	countdown "$seconds seconds"
	sleep $((seconds - 3))
fi
for x in {3..1}; do
	if [ "$seconds" -ge "$x" ]; then
		countdown "$x seconds"
		sleep 1
	fi
done
server_do stop
# Follow /dev/null until $MAINPID dies
tail -f --pid "$MAINPID" /dev/null
