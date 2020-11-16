#!/usr/bin/env bash

# Exit if error
set -e
epoch=$(date +%s)
thyme=$(date --date "@$epoch" +%H-%M)
date=$(date --date "@$epoch" +%d)
month=$(date --date "@$epoch" +%b)
year=$(date --date "@$epoch" +%Y)
syntax='Usage: MCbackup.sh [OPTION] ... SERVER_DIR SERVICE'
# Filenames can't contain : on some filesystems

server_do() {
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$*" > "/run/$service"
}

countdown() {
	warning="Server stopping in $*"
	server_do say "$warning"
	echo "$warning"
}

# Set $buffer to output of $service after $timestamp set by server_do
# If $timestamp doesn't exist set it to when $service started
# $buffer may not have output from server_do first try
# unset buffer; until echo "$buffer" | grep -q "$wanted_output"; do server_read; done
# Read until $wanted_output is read
server_read() {
	# Wait for output
	sleep 1
	if [ -z "$timestamp" ]; then
		timestamp=$(systemctl show "$service" -p ActiveEnterTimestamp --value | cut -d ' ' -f 2-3 -s)
	fi
	# Output of $service since $timestamp with no metadata
	buffer=$(journalctl -u "$service" -S "$timestamp" -o cat)
}

args=$(getopt -l backup-dir:,help -o b:h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--backup-dir|-b)
		backup_dir=$2
		shift 2
		;;
	--help|-h)
		echo "$syntax"
		echo Back up Minecraft Java Edition server world running in service.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --backup-dir=BACKUP_DIR  directory backups go in. defaults to ~. best on another drive'
		echo
		echo 'Backups are {SERVER_DIR}_Backups/{WORLD}_Backups/YEAR/MONTH/{DATE}_HOUR-MINUTE.zip in BACKUP_DIR.'
		exit
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath "$1")
properties=$server_dir/server.properties
world=$(grep ^level-name= "$properties" | cut -d = -f 2- -s)
if [ ! -d "$server_dir/$world" ]; then
	>&2 echo "No world $world in $server_dir, check level-name in server.properties too"
	exit 1
fi

service=$2
if ! systemctl is-active --quiet "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi

if [ -n "$backup_dir" ]; then
	backup_dir=$(realpath "$backup_dir")
else
	backup_dir=~
fi
backup_dir=$backup_dir/java/$(basename "$server_dir")_Backups/${world}_Backups/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$thyme.zip

server_read
# If save was off
if [ -n "$buffer" ]; then
	# The last line that matches either is the current save state
	state=$(echo "$buffer" | grep -E 'Automatic saving is now (disabled|enabled)' | tail -n 1)
	if echo "$state" | grep -q 'Automatic saving is now disabled'; then
		>&2 echo Save off, is a backup in progress?
		exit 1
	fi
fi

countdown 10 seconds
sleep 7
countdown 3 seconds
sleep 1
countdown 2 seconds
sleep 1
countdown 1 second
sleep 1
server_do say Darnit

# Disable autosave
server_do save-off
trap 'server_do save-on' ERR
# Pause and save the server
server_do save-all flush
timeout=0
unset buffer
# Minecraft says [HH:MM:SS] [Server thread/INFO]: Saved the game
until echo "$buffer" | grep -q 'Saved the game'; do
	# 1 minute timeout because server_read sleeps 1 second
	if [ "$timeout" = 60 ]; then
		server_do save resume
		>&2 echo save query timeout
		exit 1
	fi
	server_read
	timeout=$(( ++timeout ))
done

# zip restores path of directory given to it ($world), not just the directory itself
cd "$server_dir"
trap 'server_do save-on; rm -f "$backup_zip"' ERR
zip -rq "$backup_zip" "$world"
echo "Backup is $backup_zip"
server_do save-on
server_do say "Well that's better now, isn't it?"
