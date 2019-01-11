#!/usr/bin/env bash

date=`date +%d`
month=`date +%b`
year=`date +%Y`

server_do()
{
	tmux -S "$tmux_socket" send-keys -t "$sessionname":0.0 "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
}

server_read()
# Set $buffer to buffer from $sessionname from last occurence of $* to end
# $buffer may not have output from server_do
# while ! echo "$buffer" | grep -q "$wanted_output"; do server_read; done
# Wait until server is done
# Detached tmux sessions line wrap at 80 chars without -x #
{
        sleep 1
        # Wait for output
        buffer=`tmux -S "$tmux_socket" capture-pane -pt "$sessionname":0.0 -S -`
        # Read buffer from the first pane of the first window of session $sessionname on socket $tmux_socket
        buffer=`echo "$buffer" | awk -v cmd="$*" 'buffer{buffer=buffer"\n"$0} $0~cmd{buffer=$0} END {print buffer}'`
        # Trim off $buffer before last occurence of $*
        # If buffer exists append $0, if $0 contains cmd set buffer to $0, repeat, and in the end print buffer
        # $0 is the current line in awk
}

if [ -z "$1" -o -z "$2" -o "$1" = -h -o "$1" = --help ]; then
	>&2 echo Backs up Minecraft Bedrock Edition server world running in tmux session.
	>&2 echo '`./MCBEbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
	>&2 echo 'Backups are ${world}_Backups/$year/$month/$date.zip in ~ or $backup_dir if applicable. $backup_dir is best on another drive.'
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
properties=$server_dir/server.properties
if [ ! -r "$properties" ]; then
	if [ -f "$properties" ]; then
		>&2 echo $properties is not readable
		exit 2
	fi
	>&2 echo No file $properties
	exit 3
fi
world=`grep level-name "$properties" | cut -d = -f 2`
# $properties says level-name=$world
world_dir=$server_dir/worlds/$world
if [ ! -r "$world_dir" ]; then
	if [ -d "$world_dir" ]; then
		>&2 echo $world_dir is not readable
		exit 2
	fi
	>&2 echo No directory $world_dir
	exit 3
fi
world_dir=`realpath "$world_dir"`

sessionname=$2

if [ -n "$3" ]; then
	backup_dir=${3%/}
else
	backup_dir=~
fi
if [ ! -w "$backup_dir" ]; then
	if [ -d "$backup_dir" ]; then
		>&2 echo $backup_dir is not writable
		exit 2
	fi
	>&2 echo No directory $backup_dir
	exit 3
fi
backup_dir=$backup_dir/${world}_Backups/$year/$month
mkdir -p "$backup_dir"
# Make directory and parents quietly

if [ -n "$4" ]; then
	tmux_socket=${4%/}
else
	tmux_socket=/tmp/tmux-$(id -u `whoami`)/default
	# $USER = `whoami` and is not set in cron
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo No session $sessionname on socket $tmux_socket
	exit 4
fi

server_do save hold
# Prepare backup
sleep 1
# Wait one second for Minecraft Bedrock Edition command to avoid infinite loop
# Only unplayably slow servers take more than a second to run a command
while ! echo "$buffer" | grep -q 'Data saved'; do
# Minecraft Bedrock Edition says Data saved.
        server_do save query
        # Check if backup is ready
        server_read save query
done
files=`echo "$buffer" | tr -d '\n' | grep -o "$world[^:]*:[0-9]*"`
# Remove line wrapping and grep only matching strings from line
# ${world}not :...:#...
# Minecraft Bedrock Edition says $file:$bytes, $file:$bytes, ...
cd "$backup_dir"
# zip restores path of directory given to it ($world), not just the directory itself
cp -r "$world_dir" .
for string in $files; do
        file=${string%:*}
        length=${string##*:}
        # Trim off $string before last colon
        truncate --size=$length $file
done
zip -r $date.zip "$world"
rm -r "$world"
server_do save resume
