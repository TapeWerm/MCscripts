#!/bin/bash

# Exit if error
set -e
backup_dir=~
backup_time=$(date +%s)
# Filenames can't contain : on some filesystems
minute=$(date --date "@$backup_time" +%H-%M)
date=$(date --date "@$backup_time" +%d)
month=$(date --date "@$backup_time" +%m)
year=$(date --date "@$backup_time" +%Y)
syntax='Usage: mc_backup.sh [OPTION]... SERVER_DIR SERVICE'

# Print systemd cursor for server_read
# echo "$*" to $service input
server_do() {
	{
		journalctl "_SYSTEMD_UNIT=$service.service" --show-cursor -n 0 -o cat || true
	} | cut -d ' ' -f 3- -s
	echo "$*" > "/run/$service"
}

# Print output of $service after $1 printed by server_do
server_read() {
	# Wait for output
	sleep 1
	if [ -n "$1" ]; then
		# Output of $service since $1 with no metadata
		journalctl "_SYSTEMD_UNIT=$service.service" --after-cursor "$1" -o cat
	else
		journalctl "_SYSTEMD_UNIT=$service.service" -o cat
	fi
}

args=$(getopt -l backup-dir:,help -o b:h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--backup-dir|-b)
		args_backup_dir=$2
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
world=$(grep ^level-name= "$properties" | cut -d = -f 2- -s)
# Trim off $world after last carriage return
world=$(basename -- "${world%$'\r'}")
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
if ! systemctl is-active -q -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi
# Trim off $service before last @
instance=${service##*@}

config_files=(/etc/MCscripts/mc-backup.toml "/etc/MCscripts/mc-backup/$instance.toml")
for config_file in "${config_files[@]}"; do
	if [ -f "$config_file" ]; then
		if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print("backup_dir" in CONFIG)' "$config_file")" = True ]; then
			if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(isinstance(CONFIG["backup_dir"], str))' "$config_file")" = False ]; then
				>&2 echo "backup_dir must be TOML string, check $config_file"
				exit 1
			fi
			backup_dir=$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(CONFIG["backup_dir"])' "$config_file")
			backup_dir=$(realpath -- "$backup_dir")
		fi
	fi
done

if [ -n "$args_backup_dir" ]; then
	backup_dir=$(realpath -- "$args_backup_dir")
fi
backup_dir=$backup_dir/java_backups/$(basename "$server_dir")/$world/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$minute.zip

# Disable autosave
server_do save-off > /dev/null
trap 'server_do save-on > /dev/null' EXIT
# Pause and save the server
query_cursor=$(server_do save-all flush)
timeout=$(date -d '1 minute' +%s)
# Minecraft Java Edition says [HH:MM:SS] [Server thread/INFO]: Saved the game
until echo "$query" | grep -Ev '<.+>' | grep -q 'Saved the game'; do
	if [ "$(date +%s)" -ge "$timeout" ]; then
		>&2 echo save query timeout
		exit 1
	fi
	query=$(server_read "$query_cursor")
done

# zip restores path of directory given to it ($world), not just the directory itself
cd "$server_dir"
trap 'rm -f "$backup_zip"' ERR
zip -rq "$backup_zip" -- "$world"
echo "Backup is $backup_zip"
