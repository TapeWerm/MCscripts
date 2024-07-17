#!/bin/bash

# Exit if error
set -e
extension=.py
perf=false
syntax='Usage: test_mcbe_getzip.sh [OPTION]...'
zips_dir=~/bedrock_zips

ps_recursive() {
	local cputimes
	if ! cputimes=$(ps -o cputimes --no-header "$1"); then
		return 1
	fi
	# Trim off $cputimes before last space
	cputimes=${cputimes##* }
	local rss
	if ! rss=$(ps -o rss --no-header "$1"); then
		return 1
	fi
	# Trim off $rss before last space
	rss=${rss##* }
	local cmd
	if ! cmd=$(ps -o args --no-header "$1"); then
		return 1
	fi
	cmd=${cmd//'"'/'""'}
	echo "\"$timestamp\",$1,$cputimes,$rss,\"$cmd\""
	local child_pid
	for child_pid in $(ps -o pid --no-header --ppid "$1"); do
		ps_recursive "$child_pid" || true
	done
}

test_getzip() {
    echo y | "/opt/MCscripts/bin/mcbe_getzip$extension" --clobber -b > /dev/null
    unzip -tq "$zips_dir/current"
    unzip -tq "$zips_dir/preview"
}

args=$(getopt -l bash,help,perf -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--bash)
		extension=.sh
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo 'Test mcbe_getzip.'
		echo
		echo 'Options:'
		echo '--bash  test Bash scripts instead of Python'
		echo '--perf  monitor CPU and memory usage in CSV'
		exit
		;;
	--perf)
		perf=true
		shift
		;;
	esac
done
shift

if [ -d "$zips_dir" ]; then
	>&2 echo "ZIPs directory $zips_dir already exists"
	exit 1
fi

trap 'rm -rf "$zips_dir"' EXIT

if [ "$perf" = true ]; then
	echo y | "/opt/MCscripts/bin/mcbe_getzip$extension" --clobber -b > /dev/null &
	if [ "$extension" = .py ]; then
		pid=$(pgrep -P $$ -fx 'python3 /opt/MCscripts/bin/mcbe_getzip\.py --clobber -b')
	elif [ "$extension" = .sh ]; then
		pid=$(pgrep -P $$ -fx 'bash /opt/MCscripts/bin/mcbe_getzip\.sh --clobber -b')
	fi
	echo 'Timestamp,PID,CPU Time,RSS,Command'
	while timestamp=$(date --iso-8601=ns) && ps_recursive "$pid"; do
		sleep 0.1
	done
	exit
fi

echo "MCscripts version $(cat /opt/MCscripts/version)"

echo 'Test mcbe_getzip EULA prompt'
if echo nope | "/opt/MCscripts/bin/mcbe_getzip$extension" &> /dev/null; then
	>&2 echo "nope didn't fail EULA prompt"
	exit 1
fi

echo 'Test mcbe_getzip first run'
test_getzip

ln -snf "$zips_dir/bedrock-server-nope.nada.never.zip" "$zips_dir/current"

echo 'Test mcbe_getzip different symlink'
test_getzip

mv "$(realpath "$zips_dir/current")" "$(realpath "$zips_dir/current").part"

echo 'Test mcbe_getzip partial download'
test_getzip

touch "$zips_dir/bedrock-server-nope.nada.never.zip"

echo 'Test mcbe_getzip no clobber'
echo y | "/opt/MCscripts/bin/mcbe_getzip$extension" -bn > /dev/null
unzip -tq "$zips_dir/current"
unzip -tq "$zips_dir/preview"
if [ ! -f "$zips_dir/bedrock-server-nope.nada.never.zip" ]; then
    >&2 echo 'bedrock-server-nope.nada.never.zip was clobbered'
	exit 1
fi

echo 'Test mcbe_getzip clobber'
test_getzip
if [ -f "$zips_dir/bedrock-server-nope.nada.never.zip" ]; then
    >&2 echo "bedrock-server-nope.nada.never.zip wasn't clobbered"
	exit 1
fi

rm "$zips_dir/preview"

echo 'Test mcbe_getzip no preview symlink'
echo y | "/opt/MCscripts/bin/mcbe_getzip$extension" --clobber -c > /dev/null
unzip -tq "$zips_dir/current"

echo 'All tests passed'
