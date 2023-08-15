#!/usr/bin/env bash

# Exit if error
set -e
extension=.py
perf=false
syntax='Usage: test_mcbe_getzip.sh [OPTION]...'
zips_dir=~/bedrock_zips

ps_recursive() {
	if ! ps -o pid,cputimes,rss,args --no-header "$1"; then
		false
	else
		for child_pid in $(ps -o pid --no-header --ppid "$1"); do
			ps_recursive "$child_pid"
		done
	fi
}

test_getzip() {
    echo y | "/opt/MCscripts/mcbe_getzip$extension" -b > /dev/null
    unzip -tq "$zips_dir/current"
    unzip -tq "$zips_dir/preview"
}

args=$(getopt -l bash,help,perf -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--bash)
		extension=.sh
		shift 1
		;;
	--help|-h)
		echo "$syntax"
		echo Test mcbe_getzip.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '--bash  test Bash scripts instead of Python'
		echo '--perf  monitor CPU and memory usage'
		exit
		;;
	--perf)
		perf=true
		shift 1
		;;
	esac
done
shift

rm -rf "$zips_dir"
trap 'rm -rf "$zips_dir"' EXIT

if [ "$perf" = true ]; then
	echo y | "/opt/MCscripts/mcbe_getzip$extension" -b > /dev/null &
	if [ "$extension" = .py ]; then
		pid=$(pgrep -P $$ -f 'python3 /opt/MCscripts/mcbe_getzip\.py -b')
	elif [ "$extension" = .sh ]; then
		pid=$(pgrep -P $$ -f 'bash /opt/MCscripts/mcbe_getzip\.sh -b')
	fi
	echo pid cputimes rss args
	while ps_recursive "$pid"; do
		sleep 0.1
	done
	exit
fi

echo Test mcbe_getzip first run
test_getzip

ln -snf "$zips_dir/bedrock-server-nope.nada.never.zip" "$zips_dir/current"

echo Test mcbe_getzip different symlink
test_getzip

touch "$zips_dir/bedrock-server-nope.nada.never.zip"

echo Test mcbe_getzip no clobber
echo y | "/opt/MCscripts/mcbe_getzip$extension" -bn > /dev/null
unzip -tq "$zips_dir/current"
unzip -tq "$zips_dir/preview"
if [ ! -f "$zips_dir/bedrock-server-nope.nada.never.zip" ]; then
    >&2 echo bedrock-server-nope.nada.never.zip was clobbered
fi

echo Test mcbe_getzip clobber
test_getzip
if [ -f "$zips_dir/bedrock-server-nope.nada.never.zip" ]; then
    >&2 echo "bedrock-server-nope.nada.never.zip wasn't clobbered"
fi

rm "$zips_dir/preview"

echo Test mcbe_getzip no preview symlink
echo y | "/opt/MCscripts/mcbe_getzip$extension" > /dev/null
unzip -tq "$zips_dir/current"

echo All tests passed
