#!/usr/bin/env bash

# Exit if error
set -e
backup_time=$(date +%s)
# Filenames can't contain : on some filesystems
minute=$(date --date "@$backup_time" +%H-%M)
date=$(date --date "@$backup_time" +%d)
month=$(date --date "@$backup_time" +%m)
year=$(date --date "@$backup_time" +%Y)
syntax='Usage: mc_backup.sh [OPTION]... SERVER_DIR SERVICE'

# Print time in YYYY-MM-DD HH:MM:SS format for server_read
# echo "$*" to $service input
server_do() {
	date '+%Y-%m-%d %H:%M:%S'
	echo "$*" > "/run/$service"
}

# Print output of $service after time $1 printed by server_do
server_read() {
	# Wait for output
	sleep 1
	# Output of $service since $1 with no metadata
	journalctl -u "$service" -S "${1:?}" -o cat
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
		echo Back up Minecraft Java Edition server running in service.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --backup-dir=BACKUP_DIR  directory backups go in. defaults to ~. best on another drive'
		echo
		echo 'Backups are java_backups/SERVER_DIR/WORLD/YYYY/MM/DD_HH-MM.zip in BACKUP_DIR.'
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
world=$(grep ^level-name= "$properties" | cut -d = -f 2- -s | sed 's/\r$//')
world=$(basename -- "$world")
if [ -z "$world" ]; then
	>&2 echo 'No level-name in server.properties'
	exit 1
fi
if [ ! -d "$server_dir/$world" ]; then
	>&2 echo "No world $world in $server_dir, check level-name in server.properties too"
	exit 1
fi

# Trim off $2 after last .service
service=${2%.service}
if ! systemctl is-active --quiet -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi

if [ -n "$backup_dir" ]; then
	backup_dir=$(realpath -- "$backup_dir")
else
	backup_dir=~
fi
backup_dir=$backup_dir/java_backups/$(basename "$server_dir")/$world/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$minute.zip

# Disable autosave
server_do save-off > /dev/null
trap 'server_do save-on > /dev/null' EXIT
# Pause and save the server
query_time=$(server_do save-all flush)
timeout=$(date -d '1 minute' +%s)
# Minecraft Java Edition says [HH:MM:SS] [Server thread/INFO]: Saved the game
until echo "$query" | grep -Ev '<.+>' | grep -q 'Saved the game'; do
	if [ "$(date +%s)" -ge "$timeout" ]; then
		>&2 echo save query timeout
		exit 1
	fi
	query=$(server_read "$query_time")
done

# zip restores path of directory given to it ($world), not just the directory itself
cd "$server_dir"
trap 'rm -f "$backup_zip"' ERR
zip -rq "$backup_zip" -- "$world"
echo "Backup is $backup_zip"
