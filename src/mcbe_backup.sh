#!/usr/bin/env bash

# Exit if error
set -e
backup_time=$(date +%s)
# Filenames can't contain : on some filesystems
minute=$(date --date "@$backup_time" +%H-%M)
date=$(date --date "@$backup_time" +%d)
month=$(date --date "@$backup_time" +%m)
year=$(date --date "@$backup_time" +%Y)
syntax='Usage: mcbe_backup.sh [OPTION]... SERVER_DIR SERVICE'

# Print time in YYYY-MM-DD HH:MM:SS format for server_read
# echo "$*" to $service input
server_do() {
	if [ "$docker" = true ]; then
		# Escape '][(){}‘’:,!\"\n' for socat address specifications
		local no_escape
		no_escape=$(echo "$service" | sed 's/\([][(){}‘’:,!\"]\)/\\\\\\\1/g')
		date --iso-8601=seconds
		echo "$*" | socat EXEC:"docker attach $no_escape",pty STDIN
	else
		date '+%Y-%m-%d %H:%M:%S'
		echo "$*" > "/run/$service"
	fi
}

# Print output of $service after time $1 printed by server_do
server_read() {
	# Wait for output
	sleep 1
	if [ "$docker" = true ]; then
		docker logs --since "${1:?}" "$service"
	else
		# Output of $service since $1 with no metadata
		journalctl -u "$service" -S "${1:?}" -o cat
	fi
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
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo Back up Minecraft Bedrock Edition server running in service.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --backup-dir=BACKUP_DIR  directory backups go in. defaults to ~. best on another drive'
		echo '-d, --docker                 docker run -d -it --name SERVICE -e EULA=TRUE -p 19132:19132/udp -v SERVER_DIR:/data itzg/minecraft-bedrock-server'
		echo
		echo 'Backups are bedrock_backups/SERVER_DIR/WORLD/YYYY/MM/DD_HH-MM.zip in BACKUP_DIR.'
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

server_dir=$(realpath -- "$1")
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
	if ! docker ps --format '{{.Names}}' | grep -q "^$service$"; then
		>&2 echo "Container $service not running"
		exit 1
	fi
else
	if ! systemctl is-active --quiet -- "$service"; then
		>&2 echo "Service $service not active"
		exit 1
	fi
fi

if [ -n "$backup_dir" ]; then
	backup_dir=$(realpath -- "$backup_dir")
else
	backup_dir=~
fi
backup_dir=$backup_dir/bedrock_backups/$(basename "$server_dir")/$world/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$minute.zip

# Prepare backup
server_do save hold > /dev/null
trap 'server_do save resume > /dev/null' EXIT
# Wait 1 second for Minecraft Bedrock Edition command to avoid infinite loop
# Only unplayably slow servers take more than 1 second to run a command
sleep 1
timeout=$(date -d '1 minute' +%s)
# Minecraft Bedrock Edition says Data saved. Files are now ready to be copied.
until echo "$query" | grep -q 'Data saved'; do
	if [ "$(date +%s)" -ge "$timeout" ]; then
		>&2 echo save query timeout
		exit 1
	fi
	# Check if backup is ready
	query_time=$(server_do save query)
	query=$(server_read "$query_time")
done
# grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...
# journald LineMax splits lines so delete newlines
files=$(echo "$query" | tr -d '\n' | grep -Eo "$world[^:]+:[0-9]+")

mkdir -p "$temp_dir"
# zip restores path of directory given to it ($world), not just the directory itself
cd "$temp_dir"
rm -rf "$world"
trap 'rm -f "$backup_zip"' ERR
trap 'rm -rf "$world"; server_do save resume > /dev/null' EXIT
echo "$files" | while read -r line; do
	# Trim off $line after last :
	file=${line%:*}
	# https://bugs.mojang.com/browse/BDS-1085
	# save query no longer gives path
	if [ ! -f "$worlds_dir/$file" ]; then
		# Trim off $line before first $world/
		file=${file#"$world"/}
		# There might be more than one $file in $worlds_dir/$world
		file=$(find "$worlds_dir/$world" -name "$file" | head -n 1)
		file=${file#"$worlds_dir"/}
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
