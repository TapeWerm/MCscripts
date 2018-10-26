#!/usr/bin/env bash

date=`date +%d`
month=`date +%b`
year=`date +%Y`

server_do()
{
	tmux send-keys -t "$sessionname":0.0 "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname
}

if [ -z "$1" -o -z "$2" -o "$1" = -h -o "$1" = --help ]; then
	>&2 echo Backs up Minecraft Bedrock Edition server world running in tmux session.
	>&2 echo '`./MCBEbackup.sh $server_dir $sessionname [$backup_dir]`'
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

sessionname=$2
if ! tmux ls 2>&1 | grep -q "$sessionname"; then
	>&2 echo No session $sessionname
	exit 4
fi

if [ -n "$3" ]; then
	backup_dir=${3%/}
else
	backup_dir=~
fi
backup_dir=$backup_dir/${world}_Backups/$year/$month
mkdir -p "$backup_dir"
# Make directory and parents quietly
backup_dir=`realpath "$backup_dir"`

server_do save hold
# Prepare backup
while [ -z "$success" ]; do
	sleep 1
	server_do save query
	# Check if backup is ready
	buffer=`tmux capture-pane -pt "$sessionname":0.0 -S -`
	# Get buffer from the first pane of the first window of session $sessionname
	buffer=`echo "$buffer" | awk 'file{file=file"\n"$0} /save query/{file=$0} END {print file}'`
	# Trim off $buffer before last occurence of save query
	# If file exists append $0, if $0 contains save-all set file to $0, and at end print file
	if echo "$buffer" | grep -q 'saved'; then
	# Minecraft Bedrock Edition says Data saved.
		success=true
	fi
done
files=`echo "$buffer" | grep "$world" | tr -d '\n' | sed 's/, /,/g'`
# Minecraft Bedrock Edition says $path:$bytes, $path:$bytes, ...
cd "$server_dir"
# zip restores path of directory given to it ($world), not just the directory itself
cp -r "worlds/$world" .
IFS=,
for string in $files; do
	file=${string%:*}
	length=${string##*:}
	truncate --size=$length $file
done
unset IFS
zip -r "$backup_dir/$date.zip" "$world"
rm -r "$world"
server_do save resume
