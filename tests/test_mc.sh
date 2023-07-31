#!/usr/bin/env bash

# Exit if error
set -e
instance=testme
backup_override=/etc/systemd/system/mc-backup@$instance.service.d/z.conf
server_override=/etc/systemd/system/mc@$instance.service.d/z.conf
server_dir=~mc/java/$instance
properties=$server_dir/server.properties
port=25765
syntax='Usage: test_mc.sh'

cleanup() {
	if mountpoint -q /mnt/test_mc_backup; then
		umount /mnt/test_mc_backup
	fi
	if [ -d /mnt/test_mc_backup ]; then
		rmdir /mnt/test_mc_backup
	fi
	rm -f /tmp/test_mc_backup.img
	rm -rf /tmp/test_mc_backup
	rm -rf /tmp/test_mc_setup
	systemctl stop "mc@$instance.socket"
	rm -rf "$server_dir"
	rm -f "$backup_override"
	if [ -d "$(dirname "$backup_override")" ]; then
		rmdir --ignore-fail-on-non-empty "$(dirname "$backup_override")"
	fi
	rm -f "$server_override"
	if [ -d "$(dirname "$server_override")" ]; then
		rmdir --ignore-fail-on-non-empty "$(dirname "$server_override")"
	fi
	systemctl daemon-reload
}

start_server() {
	local query_cursor
	query_cursor=$(journalctl "_SYSTEMD_UNIT=mc@$instance.service" --show-cursor -n 0 -o cat || true)
	query_cursor=$(echo "$query_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mc@$instance"
	local timeout
	timeout=$(date -d '1 minute' +%s)
	local query
	until echo "$query" | grep -Eq 'Done \([^)]+\)!'; do
		if [ "$(date +%s)" -ge "$timeout" ]; then
			>&2 echo Server started timeout
			exit 1
		fi
		sleep 1
		if [ -n "$query_cursor" ]; then
			query=$(journalctl "_SYSTEMD_UNIT=mc@$instance.service" --after-cursor "$query_cursor" --show-cursor -o cat || true)
		else
			query=$(journalctl "_SYSTEMD_UNIT=mc@$instance.service" --show-cursor -o cat || true)
		fi
		query_cursor=$(echo "$query" | tail -n 1 | cut -d ' ' -f 3- -s)
		query=$(echo "$query" | head -n -1)
	done
}

test_backup() {
	local backup_cursor
	backup_cursor=$(journalctl "_SYSTEMD_UNIT=mc-backup@$instance.service" --show-cursor -n 0 -o cat || true)
	backup_cursor=$(echo "$backup_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mc-backup@$instance"
	local backup
	if [ -n "$backup_cursor" ]; then
		backup=$(journalctl "_SYSTEMD_UNIT=mc-backup@$instance.service" --after-cursor "$backup_cursor" -o cat)
	else
		backup=$(journalctl "_SYSTEMD_UNIT=mc-backup@$instance.service" -o cat)
	fi
	if ! echo "$backup" | grep -q '^Backup is '; then
		>&2 echo No backup printed
		exit 1
	fi
	backup=$(echo "$backup" | cut -d ' ' -f 3- -s)
	systemctl stop "mc@$instance.socket"
	echo y | /opt/MCscripts/mc_restore.py "$server_dir" "$backup" > /dev/null
	start_server
}

args=$(getopt -l help,port: -o h,4: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Test scripts for mc@testme.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-4, --port    port for IPv4. defaults to 25765.'
		echo
		echo "1GB free disk space required."
		exit
		;;
	--port|-4)
		port=$2
		if [[ ! "$port" =~ ^-?[0-9]+$ ]]; then
			>&2 echo PORT must be an integer
			exit 1
		fi
		if [ "$port" -lt 0 ] || [ "$port" -gt 65535 ]; then
			>&2 echo PORT must be between 0 and 65535
			exit 1
		fi
		shift 2
		;;
	esac
done
shift

if [ -d "$server_dir" ]; then
	>&2 echo "Server directory $server_dir already exists"
	exit 1
fi

cleanup
trap 'cleanup' EXIT

mkdir -p "$(dirname "$server_override")"
echo '[Service]' > "$server_override"
echo 'ExecStop=' >> "$server_override"
echo 'ExecStop=/opt/MCscripts/mc_stop.py -s 0 %N' >> "$server_override"
mkdir -p "$(dirname "$backup_override")"
echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo 'ExecStart=/opt/MCscripts/mc_backup.py -b /tmp/test_mc_backup /opt/MC/java/%i mc@%i' >> "$backup_override"
systemctl daemon-reload

echo Test mc_setup new server
echo y | /opt/MCscripts/mc_setup.py "$instance" > /dev/null
sed -i 's/^level-name=.*/level-name=Java level/' "$properties"
sed -i "s/^server-port=.*/server-port=$port/" "$properties"
sed -i 's/^eula=.*/eula=true/' "$server_dir/eula.txt"
start_server

systemctl stop "mc@$instance.socket"
sed -i 's/$/\r/' "$properties"
mv "$server_dir" /tmp/test_mc_setup
chown -R root:root /tmp/test_mc_setup

echo Test mc_setup import Windows server
yes | /opt/MCscripts/mc_setup.py -i /tmp/test_mc_setup "$instance" > /dev/null
start_server

echo Test mc-backup@testme
test_backup

systemctl stop "mc@$instance.socket"
sed -i 's/^level-name=.*/level-name=--nope/' "$properties"
start_server

echo Test mc-backup@testme level-name flag injection
test_backup

systemctl stop "mc@$instance.socket"
sed -i 's/^level-name=.*/level-name=Java level/' "$properties"
start_server

touch /tmp/test_mc_backup.img
truncate --size=1G /tmp/test_mc_backup.img
mkfs.fat -F 32 /tmp/test_mc_backup.img > /dev/null
mkdir /mnt/test_mc_backup
mount -t vfat /tmp/test_mc_backup.img /mnt/test_mc_backup

echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo 'ExecStart=/opt/MCscripts/mc_backup.py -b /mnt/test_mc_backup /opt/MC/java/%i mc@%i' >> "$backup_override"
systemctl daemon-reload

echo Test mc-backup@testme FAT32 backup directory
test_backup

echo Test mc_cmd multiline input
/opt/MCscripts/mc_cmd.py "mc@$instance" help$'\n'say Hello world

echo Test mc_stop runs outside systemd
/opt/MCscripts/mc_stop.py -s 0 "mc@$instance"

echo All tests passed
