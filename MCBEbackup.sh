#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: MCBEbackup.sh [OPTION] ... SERVER_DIR SESSIONNAME'
temp_dir=/tmp/MCBEbackup
# Filenames can't contain : on some filesystems
thyme=$(date +%H-%M)
date=$(date +%d)
month=$(date +%b)
year=$(date +%Y)

server_do() {
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
}

# Set $buffer to buffer from $sessionname from the last occurence of $* to the end
# Pass same $* as server_do to see output afterward
# $buffer may not have output from server_do first try
# unset buffer; until echo "$buffer" | grep -q "$wanted_output"; do server_read; done
# Read until $wanted_output is read
server_read() {
	# Wait for output
	sleep 1
	# Read buffer and unwrap lines from the first pane of the first window of session $sessionname on socket $tmux_socket
	scrape=$(tmux -S "$tmux_socket" capture-pane -pJt "$sessionname:0.0" -S -)
	unset buffer
	# Trim off $scrape before the last occurence of $*
	# Escape \ while reading line from $scrape
	while read -r line; do
		if echo "$line" | grep -q "$*"; then
			buffer=$line
		elif [ -n "$buffer" ]; then
			buffer=$buffer$'\n'$line
		fi
	# Bash process substitution
	done < <(echo "$scrape")
}

args=$(getopt -l backup-dir:,help,tmux-socket: -o b:ht: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--backup-dir|-b)
		backup_dir=$2
		shift 2
		;;
	--help|-h)
		echo "$syntax"
		echo Back up Minecraft Bedrock Edition server world running in tmux session.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --backup-dir=BACKUP_DIR    directory backups go in. defaults to ~'
		echo '-t, --tmux-socket=TMUX_SOCKET  socket tmux session is on'
		echo
		echo 'Backups are ${server_dir}_Backups/${world}_Backups/$year/$month/${date}_$hour-$minute.zip in $backup_dir. $backup_dir is best on another drive.'
		exit
		;;
	--tmux-socket|-t)
		tmux_socket=$2
		shift 2
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
world=$(grep ^level-name= "$properties" | cut -d = -f 2)
world_dir=$server_dir/worlds
if [ ! -d "$world_dir/$world" ]; then
	>&2 echo "No world $world in $world_dir, check level-name in server.properties too"
	exit 2
fi

sessionname=$2

if [ -n "$backup_dir" ]; then
	backup_dir=$(realpath "$backup_dir")
else
	backup_dir=~
fi
backup_dir=$backup_dir/$(basename "$server_dir")_Backups/${world}_Backups/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$thyme.zip

if [ -n "$tmux_socket" ]; then
	# Remove trailing slash
	tmux_socket=${tmux_socket%/}
else
	# $USER = `whoami` and is not set in cron
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
	exit 4
fi

server_read save hold
# If save was held
if [ -n "$buffer" ]; then
	if ! echo "$buffer" | grep -q 'save resume'; then
		>&2 echo Save held, is a backup in progress?
		exit 5
	fi
fi

server_do save hold
# Prepare backup
trap 'server_do save resume' ERR
# Wait one second for Minecraft Bedrock Edition command to avoid infinite loop
# Only unplayably slow servers take more than a second to run a command
sleep 1
timeout=0
unset buffer
# Minecraft Bedrock Edition says Data saved. Files are now ready to be copied.
until echo "$buffer" | grep -q 'Data saved'; do
	# 1 minute timeout because server_read sleeps 1 second
	if [ "$timeout" = 60 ]; then
		server_do save resume
		>&2 echo save query timeout
		exit 6
	fi
	# Check if backup is ready
	server_do save query
	server_read save query
	timeout=$(( ++timeout ))
done
# grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...
files=$(echo "$buffer" | grep -Eo "$world[^:]+:[0-9]+")

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
	if [ ! -f "$world_dir/$file" ]; then
		# Trim off $line before first $world/
		file=${file#$world/}
		# There might be more than one $file in $world_dir
		file=$(find "$world_dir" -name "$file" | head -n 1)
		file=${file#$world_dir/}
	fi
	dir=$(dirname "$file")
	# Trim off $line before last :
	length=${line##*:}
	mkdir -p "$dir"
	cp "$world_dir/$file" "$dir/"
	truncate --size="$length" "$file"
done
zip -r "$backup_zip" "$world"
echo "Backup is $backup_zip"
rm -r "$world"
server_do save resume
