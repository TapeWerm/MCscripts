#!/usr/bin/env bash

# Exit if error
set -e
backup_dir=~
backup_time=$(date +%s)
# Filenames can't contain : on some filesystems
minute=$(date --date "@$backup_time" +%H-%M)
date=$(date --date "@$backup_time" +%d)
month=$(date --date "@$backup_time" +%m)
year=$(date --date "@$backup_time" +%Y)
syntax='Usage: mcbe_backup.sh [OPTION]... SERVER_DIR SERVICE'

# Print systemd cursor or ISO 8601 time for server_read
# echo "$*" to $service input
server_do() {
	if [ "$docker" = true ]; then
		# Escape '][(){}‘’:,!\"\n' for socat address specifications
		local no_escape
		# shellcheck disable=SC2001
		no_escape=$(echo "$service" | sed 's/\\/\\\\\\\\/g')
		# shellcheck disable=SC2001,SC1112
		no_escape=$(echo "$no_escape" | sed 's/\([][(){}‘’:,!"]\)/\\\1/g')
		date --iso-8601=ns
		echo "$*" | socat - EXEC:"docker container attach -- $no_escape",pty > /dev/null
	else
		{
			journalctl "_SYSTEMD_UNIT=$service.service" --show-cursor -n 0 -o cat || true
		} | cut -d ' ' -f 3- -s
		echo "$*" > "/run/$service"
	fi
}

# Print output of $service after $1 printed by server_do
server_read() {
	# Wait for output
	sleep 1
	if [ "$docker" = true ]; then
		docker container logs --since "${1:?}" "$service"
	else
		if [ -n "$1" ]; then
			# Output of $service since $1 with no metadata
			journalctl "_SYSTEMD_UNIT=$service.service" --after-cursor "$1" -o cat
		else
			journalctl "_SYSTEMD_UNIT=$service.service" -o cat
		fi
	fi
}

args=$(getopt -l backup-dir:,docker,help -o b:dh -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--backup-dir|-b)
		args_backup_dir=$2
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
# Trim off $world after last carriage return
world=$(basename -- "${world%$'\r'}")
if [ -z "$world" ]; then
	>&2 echo 'No level-name in server.properties'
	exit 1
fi
worlds_dir=$server_dir/worlds
if [ ! -d "$worlds_dir/$world" ]; then
	>&2 echo "No world $world in $worlds_dir, check level-name in server.properties too"
	exit 1
fi
if [ "$docker" = true ]; then
	temp_dir=/tmp/docker_mcbe_backup/$(basename "$(dirname "$server_dir")")
else
	temp_dir=/tmp/mcbe_backup/$(basename "$server_dir")
fi

if [ "$docker" = true ]; then
	service=$2
	if ! docker container ls --format '{{.Names}}' | grep -q "^$service$"; then
		>&2 echo "Container $service not running"
		exit 1
	fi
else
	# Trim off $2 after last .service
	service=${2%.service}
	if ! systemctl is-active -q -- "$service"; then
		>&2 echo "Service $service not active"
		exit 1
	fi
	# Trim off $service before last @
	instance=${service##*@}
fi

if [ "$docker" = true ]; then
	config_files=(/etc/MCscripts/docker-mcbe-backup.toml "/etc/MCscripts/docker-mcbe-backup/$service.toml")
else
	config_files=(/etc/MCscripts/mcbe-backup.toml "/etc/MCscripts/mcbe-backup/$instance.toml")
fi
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
if [ "$docker" = true ]; then
	backup_dir=$backup_dir/docker_bedrock_backups/$(basename "$(dirname "$server_dir")")/$world/$year/$month
else
	backup_dir=$backup_dir/bedrock_backups/$(basename "$server_dir")/$world/$year/$month
fi
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$minute.zip

# Prepare backup
server_do save hold > /dev/null
trap 'server_do save resume > /dev/null' EXIT
sleep 1
query_cursor=$(server_do save query)
query=$(server_read "$query_cursor")
timeout=$(date -d '1 minute' +%s)
until echo "$query" | grep -q 'Data saved\. Files are now ready to be copied\.'; do
	if [ "$(date +%s)" -ge "$timeout" ]; then
		>&2 echo save query timeout
		exit 1
	fi
	if echo "$query" | grep -q 'A previous save has not been completed\.'; then
		query_cursor=$(server_do save query)
	fi
	query=$(server_read "$query_cursor")
done
# grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...
# journald LineMax splits lines so delete newlines
# shellcheck disable=SC1087
files=$(echo "$query" | tr -d '\n' | grep -Eo -- "$world[^:]+:[0-9]+")

mkdir -p "$temp_dir"
# zip restores path of directory given to it ($world), not just the directory itself
cd "$temp_dir"
rm -rf -- "$world"
trap 'rm -f "$backup_zip"' ERR
trap 'rm -rf -- "$world"; server_do save resume > /dev/null' EXIT
echo "$files" | while IFS='' read -r line; do
	# Trim off $line after last :
	file=${line%:*}
	dir=$(dirname -- "$file")
	# Trim off $line before last :
	length=${line##*:}
	mkdir -p -- "$dir"
	cp -- "$worlds_dir/$file" "$dir/"
	truncate --size="$length" -- "$file"
done
zip -rq "$backup_zip" -- "$world"
echo "Backup is $backup_zip"
