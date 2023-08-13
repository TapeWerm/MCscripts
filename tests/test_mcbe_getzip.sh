#!/usr/bin/env bash

# Exit if error
set -e
extension=.py
syntax='Usage: test_mcbe_getzip.sh [OPTION]...'
zips_dir=~/bedrock_zips

test_getzip() {
    echo y | "/opt/MCscripts/mcbe_getzip$extension" -b > /dev/null
    unzip -tq "$zips_dir/current"
    unzip -tq "$zips_dir/preview"
}

args=$(getopt -l bash,help -o h -- "$@")
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
		exit
		;;
	esac
done
shift

rm -rf "$zips_dir"
trap 'rm -rf "$zips_dir"' EXIT

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
