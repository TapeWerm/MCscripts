#!/usr/bin/env bash

# Exit if error
set -e
syntax='`./MCBEbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
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
	buffer=$(tmux -S "$tmux_socket" capture-pane -pJt "$sessionname:0.0" -S -)
	# Trim off $buffer before the last occurence of $*
	# If buffer exists append $0, if $0 contains cmd set buffer to $0, repeat, and in the end print buffer
	# $0 is the current line in awk
	buffer=$(echo "$buffer" | awk -v cmd="$*" '
		buffer { buffer=buffer"\n"$0 }
		$0~cmd { buffer=$0 }
		END { print buffer }
	')
}

case $1 in
--help|-h)
	echo Back up Minecraft Bedrock Edition server world running in tmux session.
	echo "$syntax"
	echo 'Backups are ${server_dir}_Backups/${world}_Backups/$year/$month/${date}_$hour-$minute.zip in ~ or $backup_dir if applicable. $backup_dir is best on another drive.'
	exit
	;;
esac
if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 4 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath "$1")
properties=$server_dir/server.properties
# $properties says level-name=$world
world=$(grep level-name "$properties" | cut -d = -f 2)
world_dir=$server_dir/worlds
if [ ! -d "$world_dir/$world" ]; then
	>&2 echo "No world $world in $world_dir, check level-name in server.properties too"
	exit 2
fi

sessionname=$2

if [ -n "$3" ]; then
	backup_dir=$(realpath "$3")
else
	backup_dir=~
fi
backup_dir=$backup_dir/$(basename "$server_dir")_Backups/${world}_Backups/$year/$month
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$thyme.zip

if [ -n "$4" ]; then
	# Remove trailing slash
	tmux_socket=${4%/}
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
	# 5 minute timeout because server_read sleeps 1 second
	if [ "$timeout" = 300 ]; then
		server_do save resume
		>&2 echo save query timeout
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
# Escape \ while reading line from $files
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
