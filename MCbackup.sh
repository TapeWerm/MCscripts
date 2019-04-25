#!/usr/bin/env bash

set -e
# Exit if error
date=$(date +%d)
month=$(date +%b)
syntax='`./MCbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
thyme=$(date +%H-%M)
# Filenames can't contain : on some filesystems
year=$(date +%Y)

server_do() {
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
}

countdown() {
	warning="Autosave pausing for backups in $*"
	server_do say "$warning"
	echo "$warning"
}

server_read() {
# Set $buffer to buffer from $sessionname from the last occurence of $* to the end
# Pass same $* as server_do to see output afterward
# $buffer may not have output from server_do first try
# unset buffer; until echo "$buffer" | grep -q "$wanted_output"; do server_read; done
# Read until $wanted_output is read
	sleep 1
	# Wait for output
	buffer=$(tmux -S "$tmux_socket" capture-pane -pJt "$sessionname:0.0" -S -)
	# Read buffer and unwrap lines from the first pane of the first window of session $sessionname on socket $tmux_socket
	buffer=$(echo "$buffer" | awk -v cmd="$*" 'buffer{buffer=buffer"\n"$0} $0~cmd{buffer=$0} END {print buffer}')
	# Trim off $buffer before the last occurence of $*
	# If buffer exists append $0, if $0 contains cmd set buffer to $0, repeat, and in the end print buffer
	# $0 is the current line in awk
}

if [ "$1" = -h ] || [ "$1" = --help ]; then
	echo Back up Minecraft Java Edition server world running in tmux session.
	echo "$syntax"
	echo 'Backups are ${server_dir}_Backups/${world}_Backups/$year/$month/${date}_$hour-$minute.zip in ~ or $backup_dir if applicable. $backup_dir is best on another drive.'
	exit
elif [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 4 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
properties=$server_dir/server.properties
world=$(grep level-name "$properties" | cut -d = -f 2)
# $properties says level-name=$world
if [ ! -d "$server_dir/$world" ]; then
	>&2 echo "No world $world in $server_dir, check level-name in server.properties too"
	exit 2
fi

sessionname=$2

if [ -n "$3" ]; then
	backup_dir=$(realpath "$3")
else
	backup_dir=~
fi
backup_dir=$backup_dir/$(basename "$server_dir")_Backups/${world}_Backups/$year/$month
mkdir -p "$backup_dir"
# Make directory and parents quietly
backup_zip=$backup_dir/${date}_$thyme.zip

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

server_read save-off
if [ -n "$buffer" ]; then
# If save was off
	if ! echo "$buffer" | grep -q 'save-on'; then
		>&2 echo Save off, is a backup in progress?
		exit 5
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

server_do save-off
# Disable autosave
trap 'server_do save-on' ERR
server_do save-all flush
# Pause and save the server
unset buffer
until echo "$buffer" | grep -q 'Saved the game'; do
# Minecraft says [HH:MM:SS] [Server thread/INFO]: Saved the game
	server_read save-all flush
done

cd "$server_dir"
# zip restores path of directory given to it ($world), not just the directory itself
trap 'server_do save-on; rm -f "$backup_zip"' ERR
zip -r "$backup_zip" "$world"
echo "Backup is $backup_zip"
server_do save-on
server_do say "Well that's better now, isn't it?"
