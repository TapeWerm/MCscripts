#!/usr/bin/env bash

set -e
# Exit if error
date=$(date +%d)
month=$(date +%b)
year=$(date +%Y)

server_do() {
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
}

server_read() {
# Set $buffer to buffer from $sessionname from the last occurence of $* to the end
# Pass same $* as server_do to see output afterward
# $buffer may not have output from server_do first try
# unset buffer; until echo "$buffer" | grep -q "$wanted_output"; do server_read; done
# Read until $wanted_output is read
# Lines wrap at 80-characters-long in new detached tmux sessions
# Attaching to tmux sessions resizes them
	sleep 1
	# Wait for output
	buffer=$(tmux -S "$tmux_socket" capture-pane -pt "$sessionname:0.0" -S -)
	# Read buffer from the first pane of the first window of session $sessionname on socket $tmux_socket
	buffer=$(echo "$buffer" | awk -v cmd="$*" 'buffer{buffer=buffer"\n"$0} $0~cmd{buffer=$0} END {print buffer}')
	# Trim off $buffer before the last occurence of $*
	# If buffer exists append $0, if $0 contains cmd set buffer to $0, repeat, and in the end print buffer
	# $0 is the current line in awk
}

if [ -z "$1" ] || [ -z "$2" ] || [ "$1" = -h ] || [ "$1" = --help ]; then
	>&2 echo Back up Minecraft Bedrock Edition server world running in tmux session.
	>&2 echo '`./MCBEbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
	>&2 echo 'Backups are ${world}_Backups_BE/$year/$month/$date.zip in ~ or $backup_dir if applicable. $backup_dir is best on another drive.'
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
properties=$server_dir/server.properties
world=$(grep level-name "$properties" | cut -d = -f 2)
# $properties says level-name=$world
world_dir=$server_dir/worlds
world_dir=$(realpath "$world_dir")
if [ ! -d "$world_dir" ]; then
	>&2 echo "No world $world in $world_dir, check level-name in server.properties too"
	exit 2
fi

sessionname=$2

if [ -n "$3" ]; then
	backup_dir=${3%/}
else
	backup_dir=~
fi
backup_dir=$backup_dir/${world}_Backups_BE/$year/$month
mkdir -p "$backup_dir"
# Make directory and parents quietly

if [ -n "$4" ]; then
	tmux_socket=${4%/}
else
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
	# $USER = `whoami` and is not set in cron
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
	exit 4
fi

server_read save hold
if [ -n "$buffer" ]; then
# If save was held
	if ! echo "$buffer" | grep -q 'save resume'; then
		>&2 echo Save held, is a backup in progress?
		exit 5
	fi
fi

server_do save hold
# Prepare backup
trap 'server_do save resume' ERR
sleep 1
# Wait one second for Minecraft Bedrock Edition command to avoid infinite loop
# Only unplayably slow servers take more than a second to run a command
unset buffer
until echo "$buffer" | grep -q 'Data saved'; do
# Minecraft Bedrock Edition says Data saved. Files are now ready to be copied.
	server_do save query
	# Check if backup is ready
	server_read save query
done
files=$(echo "$buffer" | tr -d '\n' | grep -Eo "$world[^:]+:[0-9]+")
# Remove line wrapping and grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...

cd "$backup_dir"
# zip restores path of directory given to it ($world), not just the directory itself
trap 'server_do save resume; rm -rf "$world"' ERR
echo "$files" | while read -r line; do
# Escape \ while reading line from $files
	file=${line%:*}
	# Trim off $line after last :
	dir=$(dirname "$file")
	length=${line##*:}
	# Trim off $line before last :
	mkdir -p "$dir"
	cp "$world_dir/$file" "$dir/"
	truncate --size="$length" "$file"
done
zip -r "$date.zip" "$world"
rm -r "$world"
server_do save resume
