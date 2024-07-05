#!/bin/bash

# Exit if error
set -e
src_dir=$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")
syntax='Usage: install.sh [OPTION]...'

# Merge directory $1 into directory $2
merge_dirs() {
	local src
	src=$(realpath -- "$1")
	local dest
	dest=$(realpath -- "$2")
	merge_dirs_recursive "$src" "$dest"
}

merge_dirs_recursive() {
	local src
	src=$1
	local dest
	dest=$2
	find "$src" -mindepth 1 -maxdepth 1 -type f -print0 | while IFS='' read -rd '' file; do
		if [ ! -e "$dest/$(basename "$file")" ]; then
			cp "$file" "$dest/"
		fi
	done
	find "$src" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS='' read -rd '' dir; do
		dir=$(basename "$dir")
		if [ ! -e "$dest/$dir" ]; then
			mkdir "$dest/$dir"
		fi
		if [ -d "$dest/$dir" ] && [ ! -h "$dest/$dir" ]; then
			merge_dirs_recursive "$src/$dir" "$dest/$dir"
		fi
	done
}

args=$(getopt -l help,update -o hu -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
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

if [ "$src_dir" = /opt/MCscripts/bin ]; then
	>&2 echo "install.sh cannot be ran inside $src_dir"
	exit 1
fi

if command -v apt-get &> /dev/null; then
	apt-get update
	apt-get install -y curl dosfstools html-xml-utils socat zip
	apt-get install -y python3-bs4 python3-requests python3-systemd python3-toml
fi
if ! id mc &> /dev/null; then
	useradd -rmd /opt/MC -s /usr/sbin/nologin mc
fi
if ! getent group mc &> /dev/null; then
	groupadd -r mc
fi
if [ "$(id -grn mc)" != mc ]; then
	usermod -g mc mc
fi
mkdir -p /opt/MCscripts
if [ ! -L /opt/MCscripts/backup_dir ]; then
	if [ -L ~mc/backup_dir ]; then
		mv ~mc/backup_dir /opt/MCscripts/
	else
		ln -s /opt/MCscripts /opt/MCscripts/backup_dir
	fi
fi
chown -h root:root /opt/MCscripts/backup_dir
mkdir -p /etc/MCscripts
merge_dirs "$src_dir/../config" /etc/MCscripts
"$src_dir/disable_services.sh"
mkdir /opt/MCscripts/bin
echo y | "$src_dir/move_servers.sh"
"$src_dir/move_backups.sh"
cp "$src_dir"/*.{py,sed,sh} /opt/MCscripts/bin/
cp "$src_dir/../LICENSE" /opt/MCscripts/
cp "$src_dir"/../systemd/* /etc/systemd/system/
systemctl daemon-reload
"$src_dir/enable_services.sh"
cp "$src_dir/../version" /opt/MCscripts/
echo @@@ How to mitigate Minecraft Java Edition CVE-2021-45046 and CVE-2021-44228: @@@
echo @@@ https://www.creeperhost.net/blog/mitigating-cve/ @@@
