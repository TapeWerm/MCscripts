#!/usr/bin/env bash

# Exit if error
set -e
epoch=$(date +%s)
# Filenames can't contain : on some filesystems
minute=$(date --date "@$epoch" +%H-%M)
date=$(date --date "@$epoch" +%d)
month=$(date --date "@$epoch" +%m)
year=$(date --date "@$epoch" +%Y)
syntax='Usage: mcbe_backup.sh [OPTION]... SERVER_DIR SERVICE'

server_do() {
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$*" > "/run/$service"
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

args=$(getopt -l backup-dir:,docker,help -o b:dh -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--backup-dir|-b)
		backup_dir=$2
		shift 2
		;;
	--docker|-d)
		docker=true
		server_do() {
			timestamp=$(date --iso-8601=seconds)
			echo "$*" | socat EXEC:"docker attach '$service'",pty STDIN
		}
		server_read() {
			sleep 1
			if [ -z "$timestamp" ]; then
				timestamp=$(docker inspect "$service" | grep '^ *"StartedAt":' | cut -d '"' -f 4 -s)
			fi
			buffer=$(docker logs --since "$timestamp" "$service")
		}
		shift 1
		;;
	--help|-h)
		echo "$syntax"
		echo Back up Minecraft Bedrock Edition server world running in service.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --backup-dir=BACKUP_DIR  directory backups go in. defaults to ~. best on another drive'
		echo '-d, --docker                 docker run -d -it --name SERVICE -e EULA=TRUE -p 19132:19132/udp -v SERVER_DIR:/data itzg/minecraft-bedrock-server'
		echo
		echo 'Backups are bedrock_backups/SERVER_DIR/WORLD/YYYY/MM/{DATE}_HOUR-MINUTE.zip in BACKUP_DIR.'
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
worlds_dir=$server_dir/worlds
if [ ! -d "$worlds_dir/$world" ]; then
	>&2 echo "No world $world in $worlds_dir, check level-name in server.properties too"
	exit 1
fi
temp_dir=/tmp/mcbe_backup/$(basename "$server_dir")

service=$2
if [ "$docker" = true ]; then
	if ! docker ps --format='{{.Names}}' | grep -q "^$service$"; then
		>&2 echo "Container $service not up"
		exit 1
	fi
else
	if ! systemctl is-active --quiet "$service"; then
		>&2 echo "Service $service not active"
		exit 1
	fi
fi

if [ -n "$backup_dir" ]; then
	backup_dir=$(realpath "$backup_dir")
else
	backup_dir=~
fi
backup_dir=$backup_dir/bedrock_backups/$(basename "$server_dir")/$world/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$minute.zip

server_read
# If save was held
if [ -n "$buffer" ]; then
	# The last line that matches either is the current save state
	state=$(echo "$buffer" | grep -E 'Saving|Changes to the level are resumed' | tail -n 1)
	if echo "$state" | grep -q 'Saving'; then
		>&2 echo Save held, is a backup in progress?
		exit 1
	fi
fi

# Prepare backup
server_do save hold
trap 'server_do save resume' ERR
# Wait 1 second for Minecraft Bedrock Edition command to avoid infinite loop
# Only unplayably slow servers take more than 1 second to run a command
sleep 1
timeout=$(date -d '1 minute' +%s)
unset buffer
# Minecraft Bedrock Edition says Data saved. Files are now ready to be copied.
until echo "$buffer" | grep -q 'Data saved'; do
	if [ "$(date +%s)" -ge "$timeout" ]; then
		server_do save resume
		>&2 echo save query timeout
		exit 1
	fi
	# Check if backup is ready
	server_do save query
	server_read
done
# grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...
# journald LineMax splits lines so delete newlines
files=$(echo "$buffer" | tr -d '\n' | grep -Eo "$world[^:]+:[0-9]+")

mkdir -p "$temp_dir"
# zip restores path of directory given to it ($world), not just the directory itself
cd "$temp_dir"
rm -rf "$world"
trap 'server_do save resume; rm -rf "$world"; rm -f "$backup_zip"' ERR
echo "$files" | while read -r line; do
	# Trim off $line after last :
	file=${line%:*}
	# https://bugs.mojang.com/browse/BDS-1085
	# save query no longer gives path
	if [ ! -f "$worlds_dir/$file" ]; then
		# Trim off $line before first $world/
		file=${file#$world/}
		# There might be more than one $file in $worlds_dir/$world
		file=$(find "$worlds_dir/$world" -name "$file" | head -n 1)
		file=${file#$worlds_dir/}
	fi
	dir=$(dirname "$file")
	# Trim off $line before last :
	length=${line##*:}
	mkdir -p "$dir"
	cp "$worlds_dir/$file" "$dir/"
	truncate --size="$length" "$file"
done
zip -rq "$backup_zip" "$world"
echo "Backup is $backup_zip"
rm -r "$world"
server_do save resume
