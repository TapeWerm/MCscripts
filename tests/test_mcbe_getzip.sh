#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: test_mcbe_getzip.sh'
zips_dir=~/bedrock_zips

test_getzip() {
    echo y | /opt/MCscripts/mcbe_getzip.py -b > /dev/null
    unzip -tq "$zips_dir/current"
    unzip -tq "$zips_dir/preview"
}

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Test mcbe_getzip.
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
echo y | /opt/MCscripts/mcbe_getzip.py -bn > /dev/null
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

echo All tests passed
