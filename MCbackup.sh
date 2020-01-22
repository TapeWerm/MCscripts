#!/usr/bin/env bash

set -e
# Exit if error
syntax='`./MCbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
# Filenames can't contain : on some filesystems
thyme=$(date +%H-%M)
date=$(date +%d)
month=$(date +%b)
year=$(date +%Y)

server_do() {
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
	tmux -S "$tmux_socket" send-keys -t "$sessionname:0.0" "$*" Enter
}

countdown() {
	warning="Autosave pausing for backups in $*"
	server_do say "$warning"
	echo "$warning"
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

case $1 in
--help|-h)
	echo Back up Minecraft Java Edition server world running in tmux session.
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

# Remove trailing slash
server_dir=${1%/}
properties=$server_dir/server.properties
world=$(grep ^level-name= "$properties" | cut -d = -f 2)
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
# Make directory and parents quietly
mkdir -p "$backup_dir"
backup_zip=$backup_dir/${date}_$thyme.zip

if [ -n "$4" ]; then
	tmux_socket=${4%/}
else
	# $USER = `whoami` and is not set in cron
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
	exit 4
fi

server_read save-off
# If save was off
if [ -n "$buffer" ]; then
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
		exit 6
	fi
	server_read save-all flush
	timeout=$(( ++timeout ))
done

# zip restores path of directory given to it ($world), not just the directory itself
cd "$server_dir"
trap 'server_do save-on; rm -f "$backup_zip"' ERR
zip -r "$backup_zip" "$world"
echo "Backup is $backup_zip"
server_do save-on
server_do say "Well that's better now, isn't it?"
