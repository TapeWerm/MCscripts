#!/bin/bash

# Exit if error
set -e
extension=.py
instance=testme
backup_override=/etc/systemd/system/mc-backup@$instance.service.d/z.conf
server_override=/etc/systemd/system/mc@$instance.service.d/z.conf
update_override=/etc/systemd/system/mc-autoupdate@$instance.service.d/z.conf
server_dir=~mc/java/$instance
mcscripts_dir=$server_dir/.MCscripts
jars_dir=~mc/java_jars
properties=$server_dir/server.properties
port=25765
syntax='Usage: test_mc.sh [OPTION]...'

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
	rm -f "$update_override"
	if [ -d "$(dirname "$update_override")" ]; then
		rmdir --ignore-fail-on-non-empty "$(dirname "$update_override")"
	fi
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

wait_for_server() {
	local invocation_id
	invocation_id=$(systemctl show -p InvocationID --value "mc@$instance")
	local query
	query=$(journalctl "_SYSTEMD_INVOCATION_ID=$invocation_id" --show-cursor -o cat || true)
	local query_cursor
	query_cursor=$(echo "$query" | tail -n 1 | cut -d ' ' -f 3- -s)
	query=$(echo "$query" | head -n -1)
	local timeout
	timeout=$(date -d '1 minute' +%s)
	until echo "$query" | grep -Eq 'Done \([^)]+\)!'; do
		if [ "$(date +%s)" -ge "$timeout" ]; then
			>&2 echo 'Server started timeout'
			exit 1
		fi
		sleep 1
		if [ -n "$query_cursor" ]; then
			query=$(journalctl "_SYSTEMD_INVOCATION_ID=$invocation_id" --after-cursor "$query_cursor" --show-cursor -o cat || true)
		else
			query=$(journalctl "_SYSTEMD_INVOCATION_ID=$invocation_id" --show-cursor -o cat || true)
		fi
		query_cursor=$(echo "$query" | tail -n 1 | cut -d ' ' -f 3- -s)
		query=$(echo "$query" | head -n -1)
	done
}

start_server() {
	systemctl start "mc@$instance"
	wait_for_server
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
		>&2 echo 'No backup printed'
		exit 1
	fi
	backup=$(echo "$backup" | cut -d ' ' -f 3- -s)
	systemctl stop "mc@$instance.socket"
	echo y | "/opt/MCscripts/bin/mc_restore$extension" "$server_dir" "$backup" > /dev/null
	start_server
}

# Print systemd messages for mc@$instance.service
# systemd says Started Minecraft Java Edition server @ $instance.
test_update() {
	local update_cursor
	update_cursor=$(journalctl "UNIT=mc@$instance.service" _PID=1 --show-cursor -n 0 -o cat || true)
	update_cursor=$(echo "$update_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mc-autoupdate@$instance"
	if [ -n "$update_cursor" ]; then
		journalctl "UNIT=mc@$instance.service" _PID=1 --after-cursor "$update_cursor" -o cat
	else
		journalctl "UNIT=mc@$instance.service" _PID=1 -o cat
	fi
	wait_for_server
}

args=$(getopt -l bash,help,port: -o h4: -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--bash)
		extension=.sh
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo 'Test scripts for mc@testme.'
		echo
		echo 'Options:'
		echo '-4, --port=PORT  port for IPv4. defaults to 25765.'
		echo '--bash           test Bash scripts instead of Python'
		echo
		echo '1GB free disk space required.'
		exit
		;;
	--port|-4)
		port=$2
		if [[ ! "$port" =~ ^-?[0-9]+$ ]]; then
			>&2 echo 'PORT must be an integer'
			exit 1
		fi
		if [ "$port" -lt 0 ] || [ "$port" -gt 65535 ]; then
			>&2 echo 'PORT must be between 0 and 65535'
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

echo "MCscripts version $(cat /opt/MCscripts/version)"
if [ -h "$jars_dir/current" ]; then
	minecraft_jar=$(realpath "$jars_dir/current")
else
	>&2 echo "No minecraft_server JAR $jars_dir/current"
	exit 1
fi
# Trim off $minecraft_jar after last .jar
current_ver=$(basename "${minecraft_jar%.jar}")
echo "current version $current_ver"

mkdir -p "$(dirname "$server_override")"
echo '[Service]' > "$server_override"
echo 'ExecStop=' >> "$server_override"
echo "ExecStop=/opt/MCscripts/bin/mc_stop$extension -s 0 %N" >> "$server_override"
systemctl daemon-reload

echo 'Test mc_setup new server'
"/opt/MCscripts/bin/mc_setup$extension" "$instance" > /dev/null
sed -ie 's/^level-name=.*/level-name=Java level/' "$properties"
sed -ie "s/^server-port=.*/server-port=$port/" "$properties"
sed -ie 's/^eula=.*/eula=true/' "$server_dir/eula.txt"
start_server

systemctl stop "mc@$instance.socket"
rm -r "$mcscripts_dir"
sed -ie 's/$/\r/' "$properties"
mv "$server_dir" /tmp/test_mc_setup
chown -R root:root /tmp/test_mc_setup

echo 'Test mc_import Windows server'
echo y | "/opt/MCscripts/bin/mc_import$extension" /tmp/test_mc_setup "$instance" > /dev/null
start_server

systemctl stop "mc@$instance.socket"
mv "$server_dir" /tmp/test_mc_setup
chown -R root:root /tmp/test_mc_setup

echo 'Test mc_import .MCscripts already exists'
echo y | "/opt/MCscripts/bin/mc_import$extension" /tmp/test_mc_setup "$instance" > /dev/null
start_server

mkdir -p "$(dirname "$backup_override")"
echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo "ExecStart=/opt/MCscripts/bin/mc_backup$extension -b /tmp/test_mc_backup /opt/MC/java/%i mc@%i" >> "$backup_override"
systemctl daemon-reload

echo 'Test mc-backup@testme'
test_backup

systemctl stop "mc@$instance.socket"
sed -ie 's/^level-name=.*/level-name=--nope/' "$properties"
start_server

echo 'Test mc-backup@testme level-name flag injection'
test_backup

systemctl stop "mc@$instance.socket"
sed -ie 's/^level-name=.*/level-name=Java level/' "$properties"
start_server

touch /tmp/test_mc_backup.img
truncate --size=1G /tmp/test_mc_backup.img
mkfs.fat -F 32 /tmp/test_mc_backup.img > /dev/null
mkdir /mnt/test_mc_backup
mount -t vfat /tmp/test_mc_backup.img /mnt/test_mc_backup

echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo "ExecStart=/opt/MCscripts/bin/mc_backup$extension -b /mnt/test_mc_backup /opt/MC/java/%i mc@%i" >> "$backup_override"
systemctl daemon-reload

echo 'Test mc-backup@testme FAT32 backup directory'
test_backup

mkdir -p "$(dirname "$update_override")"
echo '[Service]' > "$update_override"
echo 'ExecStart=' >> "$update_override"
echo "ExecStart=/opt/MCscripts/bin/mc_autoupdate$extension /opt/MC/java/%i mc@%i" >> "$update_override"
systemctl daemon-reload

echo 'Test mc-autoupdate@testme already up to date'
if test_update | grep -q Started; then
	>&2 echo "mc@$instance was updated when already up to date"
	exit 1
fi

echo 💢 > "$mcscripts_dir/version"

echo 'Test mc-autoupdate@testme different version'
if ! test_update | grep -q Started; then
	>&2 echo "mc@$instance wasn't updated when different version"
	exit 1
fi

rm "$mcscripts_dir/version"

echo 'Test mc-autoupdate@testme no version file'
if ! test_update | grep -q Started; then
	>&2 echo "mc@$instance wasn't updated when no version file"
	exit 1
fi

echo 'Test mc_cmd multiline input'
"/opt/MCscripts/bin/mc_cmd$extension" "mc@$instance" help$'\n'say Hello world

echo 'Test mc_stop runs outside systemd'
"/opt/MCscripts/bin/mc_stop$extension" -s 0 "mc@$instance"

echo 'All tests passed'
