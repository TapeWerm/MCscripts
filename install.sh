#!/usr/bin/env bash

# Exit if error
set -e
dir=$(dirname "$0")
syntax='Usage: install.sh [OPTION]...'
update=false

args=$(getopt -l help,update -o hu -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Install or update MCscripts.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-u, --update  update MCscripts'
		exit
		;;
	--update|-u)
		update=true
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

if [ "$dir" = ~mc ]; then
	>&2 echo 'install.sh cannot be ran inside ~mc'
	exit 1
fi

cd "$dir"
if [ "$update" = false ]; then
	adduser --home /opt/MC --system mc
	ln -s ~mc ~mc/backup_dir
	cp -- *.{sed,sh} ~mc/
	chown -h mc:nogroup ~mc/*
	cp systemd/* /etc/systemd/system/
else
	if [ ! -d ~mc/backup_dir ]; then
		ln -s ~mc ~mc/backup_dir
	fi
	./disable_services.sh
	echo y | ./move_servers.sh
	./move_backups.sh
	cp -- *.{sed,sh} ~mc/
	chown -h mc:nogroup ~mc/*
	cp systemd/* /etc/systemd/system/
	./enable_services.sh
fi