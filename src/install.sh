#!/usr/bin/env bash

# Exit if error
set -e
dir=$(dirname "$0")
syntax='Usage: install.sh [OPTION]...'

args=$(getopt -l help,update -o hu -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Install or update MCscripts.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-u, --update  deprecated flag'
		exit
		;;
	--update|-u)
		shift
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

case $dir in
~mc|/opt/MCscripts/bin)
	>&2 echo "install.sh cannot be ran inside $dir"
	exit 1
	;;
esac

if command -v apt-get &> /dev/null; then
	apt-get update
	apt-get install -y curl html-xml-utils socat zip
fi
if ! id -u mc &> /dev/null; then
	adduser --home /opt/MC --system mc
fi
mkdir -p /opt/MCscripts
if [ ! -d ~mc/backup_dir ]; then
	ln -s ~mc ~mc/backup_dir
fi
"$dir/disable_services.sh"
echo y | "$dir/move_servers.sh"
"$dir/move_backups.sh"
cp "$dir"/*.{sed,sh} /opt/MCscripts/
chown -h mc:nogroup ~mc/*
cp "$dir"/../systemd/* /etc/systemd/system/
systemctl daemon-reload
"$dir/enable_services.sh"
echo @@@ How to mitigate Minecraft Java Edition CVE-2021-45046 and CVE-2021-44228: @@@
echo @@@ https://www.creeperhost.net/blog/mitigating-cve/ @@@
