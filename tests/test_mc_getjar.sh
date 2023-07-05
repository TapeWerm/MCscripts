#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: test_mc_getjar.sh'
jars_dir=~/java_jars

test_getjar() {
    echo y | /opt/MCscripts/mc_getjar.py > /dev/null
    unzip -tq "$jars_dir/current"
}

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Test mc_getjar.
		exit
		;;
	esac
done
shift

rm -rf "$jars_dir"
trap 'rm -rf "$jars_dir"' EXIT

echo Test mc_getjar first run
test_getjar

ln -snf "$jars_dir/minecraft_server.nope.nada.never.jar" "$jars_dir/current"

echo Test mc_getjar different symlink
test_getjar

touch "$jars_dir/minecraft_server.nope.nada.never.jar"

echo Test mc_getjar no clobber
echo y | /opt/MCscripts/mc_getjar.py -n > /dev/null
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
