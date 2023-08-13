#!/usr/bin/env bash

# Exit if error
set -e
extension=.py
perf=false
syntax='Usage: test_mc_getjar.sh [OPTION]...'
jars_dir=~/java_jars

test_getjar() {
    echo y | "/opt/MCscripts/mc_getjar$extension" > /dev/null
    unzip -tq "$jars_dir/current"
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
		echo Test mc_getjar.
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

rm -rf "$jars_dir"
trap 'rm -rf "$jars_dir"' EXIT

if [ "$perf" = true ]; then
	echo y | "/opt/MCscripts/mc_getjar$extension" > /dev/null &
	if [ "$extension" = .py ]; then
		pid=$(pgrep -P $$ -f 'python3 /opt/MCscripts/mc_getjar\.py')
	elif [ "$extension" = .sh ]; then
		pid=$(pgrep -P $$ -f 'bash /opt/MCscripts/mc_getjar\.sh')
	fi
	ps -o pid,cputimes,rss --ppid "$pid" "$pid"
	sleep 0.1
	while ps -o pid,cputimes,rss --no-header --ppid "$pid" "$pid"; do
		sleep 0.1
	done
	exit
fi

echo Test mc_getjar first run
test_getjar

ln -snf "$jars_dir/minecraft_server.nope.nada.never.jar" "$jars_dir/current"

echo Test mc_getjar different symlink
test_getjar

touch "$jars_dir/minecraft_server.nope.nada.never.jar"

echo Test mc_getjar no clobber
echo y | "/opt/MCscripts/mc_getjar$extension" -n > /dev/null
unzip -tq "$jars_dir/current"
if [ ! -f "$jars_dir/minecraft_server.nope.nada.never.jar" ]; then
    >&2 echo minecraft_server.nope.nada.never.jar was clobbered
fi

echo Test mc_getjar clobber
test_getjar
if [ -f "$jars_dir/minecraft_server.nope.nada.never.jar" ]; then
    >&2 echo "minecraft_server.nope.nada.never.jar wasn't clobbered"
fi

echo All tests passed
