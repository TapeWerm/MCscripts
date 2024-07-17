#!/bin/bash

# Exit if error
set -e
seconds=10
syntax='Usage: mc_stop.sh [OPTION]... SERVICE'

server_do() {
	echo "$*" > "/run/$service"
}

countdown() {
	local warning
	warning="Server stopping in $1 seconds"
	server_do say "$warning"
	echo "$warning"
}

args=$(getopt -l help,seconds: -o hs: -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Warn Minecraft Java Edition or Bedrock Edition server running in service 10 seconds before stopping.'
		echo
		echo 'Positional arguments:'
		echo 'SERVICE  systemd service'
		echo
		echo 'Options:'
		echo '-s, --seconds=SECONDS  seconds before stopping. must be between 0 and 60. defaults to 10'
		echo
		echo 'Best ran by systemd before shutdown.'
		exit
		;;
	--seconds|-s)
		args_seconds=$2
		if [[ ! "$args_seconds" =~ ^-?[0-9]+$ ]]; then
			>&2 echo 'SECONDS must be an integer'
			exit 1
		fi
		shift 2
		;;
	esac
done
shift

if [ "$#" -lt 1 ]; then
	>&2 echo 'Not enough arguments'
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo 'Too much arguments'
	>&2 echo "$syntax"
	exit 1
fi

# Trim off $1 after last .service
service=${1%.service}
if [ -z "$MAINPID" ]; then
	MAINPID=$(systemctl show -p MainPID --value -- "$service")
fi
if [ "$MAINPID" = 0 ]; then
	echo "Service $service already stopped"
	exit
fi
# Trim off $service before last @
instance=${service##*@}
# Trim off $service after first @
template=${service%@*}

config_files=("/etc/MCscripts/$template.toml" "/etc/MCscripts/$template/$instance.toml")
for config_file in "${config_files[@]}"; do
	if [ -f "$config_file" ]; then
		if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print("seconds" in CONFIG)' "$config_file")" = True ]; then
			if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(isinstance(CONFIG["seconds"], int))' "$config_file")" = False ]; then
				>&2 echo "seconds must be TOML integer, check $config_file"
				exit 1
			fi
			seconds=$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(CONFIG["seconds"])' "$config_file")
			if [ "$seconds" -lt 0 ] || [ "$seconds" -gt 60 ]; then
				>&2 echo "seconds must be between 0 and 60, check $config_file"
				exit 1
			fi
		fi
	fi
done

if [ -n "$args_seconds" ]; then
	seconds=$args_seconds
	if [ "$seconds" -lt 0 ] || [ "$seconds" -gt 60 ]; then
		>&2 echo 'SECONDS must be between 0 and 60'
		exit 1
	fi
fi

if [ "$seconds" -gt 3 ]; then
	countdown "$seconds"
	sleep $((seconds - 3))
fi
for x in {3..1}; do
	if [ "$seconds" -ge "$x" ]; then
		countdown "$x"
		sleep 1
	fi
done
server_do stop
# Follow /dev/null until $MAINPID dies
tail -f --pid "$MAINPID" /dev/null
