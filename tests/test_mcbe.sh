#!/usr/bin/env bash

# Exit if error
set -e
extension=.py
instance=testme
backup_override=/etc/systemd/system/mcbe-backup@$instance.service.d/z.conf
server_override=/etc/systemd/system/mcbe@$instance.service.d/z.conf
update_override=/etc/systemd/system/mcbe-autoupdate@$instance.service.d/z.conf
server_dir=~mc/bedrock/$instance
properties=$server_dir/server.properties
discord_file=~mc/.mcbe_log/${instance}_discord.txt
port=20132
portv6=20133
syntax='Usage: test_mcbe.sh [OPTION]...'
zips_dir=~mc/bedrock_zips

cleanup() {
	rm -f "$discord_file"
	if [ -d ~mc/.mcbe_log ]; then
		rmdir --ignore-fail-on-non-empty ~mc/.mcbe_log
	fi
	if mountpoint -q /mnt/test_mcbe_backup; then
		umount /mnt/test_mcbe_backup
	fi
	if [ -d /mnt/test_mcbe_backup ]; then
		rmdir /mnt/test_mcbe_backup
	fi
	rm -f /tmp/test_mcbe_backup.img
	rm -rf /tmp/test_mcbe_backup
	rm -rf /tmp/test_mcbe_setup
	systemctl stop "mcbe@$instance.socket"
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

start_server() {
	local query_cursor
	query_cursor=$(journalctl "_SYSTEMD_UNIT=mcbe@$instance.service" --show-cursor -n 0 -o cat || true)
	query_cursor=$(echo "$query_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mcbe@$instance"
	local timeout
	timeout=$(date -d '1 minute' +%s)
	local query
	until echo "$query" | grep -q 'Server started\.'; do
		if [ "$(date +%s)" -ge "$timeout" ]; then
			>&2 echo Server started timeout
			exit 1
		fi
		sleep 1
		if [ -n "$query_cursor" ]; then
			query=$(journalctl "_SYSTEMD_UNIT=mcbe@$instance.service" --after-cursor "$query_cursor" --show-cursor -o cat || true)
		else
			query=$(journalctl "_SYSTEMD_UNIT=mcbe@$instance.service" --show-cursor -o cat || true)
		fi
		query_cursor=$(echo "$query" | tail -n 1 | cut -d ' ' -f 3- -s)
		query=$(echo "$query" | head -n -1)
	done
}

test_backup() {
	local backup_cursor
	backup_cursor=$(journalctl "_SYSTEMD_UNIT=mcbe-backup@$instance.service" --show-cursor -n 0 -o cat || true)
	backup_cursor=$(echo "$backup_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mcbe-backup@$instance"
	local backup
	if [ -n "$backup_cursor" ]; then
		backup=$(journalctl "_SYSTEMD_UNIT=mcbe-backup@$instance.service" --after-cursor "$backup_cursor" -o cat)
	else
		backup=$(journalctl "_SYSTEMD_UNIT=mcbe-backup@$instance.service" -o cat)
	fi
	if ! echo "$backup" | grep -q '^Backup is '; then
		>&2 echo No backup printed
		exit 1
	fi
	backup=$(echo "$backup" | cut -d ' ' -f 3- -s)
	systemctl stop "mcbe@$instance.socket"
	echo y | "/opt/MCscripts/bin/mcbe_restore$extension" "$server_dir" "$backup" > /dev/null
	start_server
}

# Print systemd messages for mcbe@$instance.service
# systemd says Starting Minecraft Bedrock Edition server @ $instance...
test_update() {
	local update_cursor
	update_cursor=$(journalctl "UNIT=mcbe@$instance.service" _PID=1 --show-cursor -n 0 -o cat || true)
	update_cursor=$(echo "$update_cursor" | cut -d ' ' -f 3- -s)
	systemctl start "mcbe-autoupdate@$instance"
	if [ -n "$update_cursor" ]; then
		journalctl "UNIT=mcbe@$instance.service" _PID=1 --after-cursor "$update_cursor" -o cat
	else
		journalctl "UNIT=mcbe@$instance.service" _PID=1 -o cat
	fi
	if ! grep -q '^# Test mcbe_update keeps server\.properties$' "$properties"; then
		>&2 echo "mcbe_update didn't keep server.properties"
		exit 1
	fi
	if [ ! -f "$server_dir/test_mcbe_update.json" ]; then
		>&2 echo "mcbe_update didn't keep test_mcbe_update.json"
		exit 1
	fi
	if [ ! -d "$server_dir/worlds/--nope" ]; then
		>&2 echo "mcbe_update didn't keep worlds"
		exit 1
	fi
}

args=$(getopt -l bash,help,port:,portv6: -o h4:6: -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--bash)
		extension=.sh
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo Test scripts for mcbe@testme.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-4, --port=PORT      port for IPv4. defaults to 20132.'
		echo '-6, --portv6=PORTV6  port for IPv6. defaults to 20133.'
		echo '--bash               test Bash scripts instead of Python'
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
	--portv6|-6)
		portv6=$2
		if [[ ! "$portv6" =~ ^-?[0-9]+$ ]]; then
			>&2 echo PORTV6 must be an integer
			exit 1
		fi
		if [ "$portv6" -lt 0 ] || [ "$portv6" -gt 65535 ]; then
			>&2 echo PORTV6 must be between 0 and 65535
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

echo MCscripts version "$(cat /opt/MCscripts/version)"
for version in current preview; do
	if [ -h "$zips_dir/$version" ]; then
		minecraft_zip=$(realpath "$zips_dir/$version")
	else
		>&2 echo "No bedrock-server ZIP $zips_dir/$version"
		exit 1
	fi
	# Trim off $minecraft_zip after last .zip
	current_ver=$(basename "${minecraft_zip%.zip}")
	echo "$version version $current_ver"
done

mkdir -p "$(dirname "$server_override")"
echo '[Service]' > "$server_override"
echo 'ExecStop=' >> "$server_override"
echo "ExecStop=/opt/MCscripts/bin/mc_stop$extension -s 0 %N" >> "$server_override"
mkdir -p "$(dirname "$backup_override")"
echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo "ExecStart=/opt/MCscripts/bin/mcbe_backup$extension -b /tmp/test_mcbe_backup /opt/MC/bedrock/%i mcbe@%i" >> "$backup_override"
systemctl daemon-reload

echo Test mcbe_setup new server
"/opt/MCscripts/bin/mcbe_setup$extension" "$instance" > /dev/null
sed -i 's/^enable-lan-visibility=.*/enable-lan-visibility=false/' "$properties"
sed -i 's/^level-name=.*/level-name=Bedrock level/' "$properties"
sed -i "s/^server-port=.*/server-port=$port/" "$properties"
sed -i "s/^server-portv6=.*/server-portv6=$portv6/" "$properties"
echo '# Test mcbe_update keeps server.properties' >> "$properties"
touch "$server_dir/test_mcbe_update.json"
chown mc:mc "$server_dir/test_mcbe_update.json"
start_server

systemctl stop "mcbe@$instance.socket"
sed -i 's/$/\r/' "$properties"
mv "$server_dir" /tmp/test_mcbe_setup
chown -R root:root /tmp/test_mcbe_setup

echo Test mcbe_import Windows server
echo y | "/opt/MCscripts/bin/mcbe_import$extension" /tmp/test_mcbe_setup "$instance" > /dev/null
start_server

echo Test mcbe-backup@testme
test_backup

systemctl stop "mcbe@$instance.socket"
sed -i 's/^level-name=.*/level-name=--nope/' "$properties"
start_server

echo Test mcbe-backup@testme level-name flag injection
test_backup

systemctl stop "mcbe@$instance.socket"
sed -i 's/^level-name=.*/level-name=Bedrock level/' "$properties"
start_server

touch /tmp/test_mcbe_backup.img
truncate --size=1G /tmp/test_mcbe_backup.img
mkfs.fat -F 32 /tmp/test_mcbe_backup.img > /dev/null
mkdir /mnt/test_mcbe_backup
mount -t vfat /tmp/test_mcbe_backup.img /mnt/test_mcbe_backup

echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo "ExecStart=/opt/MCscripts/bin/mcbe_backup$extension -b /mnt/test_mcbe_backup /opt/MC/bedrock/%i mcbe@%i" >> "$backup_override"
systemctl daemon-reload

echo Test mcbe-backup@testme FAT32 backup directory
test_backup

echo '[Service]' > "$backup_override"
echo 'ExecStart=' >> "$backup_override"
echo "ExecStart=/opt/MCscripts/bin/mcbe_backup$extension -b /tmp/test_mcbe_backup /opt/MC/bedrock/%i mcbe@%i" >> "$backup_override"
mkdir -p "$(dirname "$update_override")"
echo '[Service]' > "$update_override"
echo 'ExecStart=' >> "$update_override"
echo "ExecStart=/opt/MCscripts/bin/mcbe_autoupdate$extension -c /opt/MC/bedrock/%i mcbe@%i" >> "$update_override"
systemctl daemon-reload

echo Test mcbe-autoupdate@testme already up to date
if test_update | grep -q Starting; then
	>&2 echo "mcbe@$instance was updated when already up to date"
	exit 1
fi

echo 💢 > "$server_dir/version"

echo Test mcbe-autoupdate@testme different version
if ! test_update | grep -q Starting; then
	>&2 echo "mcbe@$instance wasn't updated when different version"
	exit 1
fi

rm "$server_dir/version"

echo Test mcbe-autoupdate@testme no version file
if ! test_update | grep -q Starting; then
	>&2 echo "mcbe@$instance wasn't updated when no version file"
	exit 1
fi

echo '[Service]' > "$update_override"
echo 'ExecStart=' >> "$update_override"
echo "ExecStart=/opt/MCscripts/bin/mcbe_autoupdate$extension -p /opt/MC/bedrock/%i mcbe@%i" >> "$update_override"
systemctl daemon-reload

# In case current and preview are the same version, force update
rm "$server_dir/version"

echo Test mcbe-autoupdate@testme Bedrock Edition server preview
if ! test_update | grep -q Starting; then
	>&2 echo "mcbe@$instance wasn't updated when no version file"
	exit 1
fi

echo Test mcbe-backup@testme Bedrock Edition server preview
test_backup

mkdir -p ~mc/.mcbe_log
touch "$discord_file"
chmod 600 "$discord_file"
chown -R mc:mc ~mc/.mcbe_log
echo https://discord.com/do-not-print > "$discord_file"

echo "Test mcbe_log doesn't print webhook when offline"
offline=$(systemd-run -PGqp KillMode=mixed -p PrivateNetwork=true -p RuntimeMaxSec=1 -p SupplementaryGroups=systemd-journal -p User=mc "/opt/MCscripts/bin/mcbe_log$extension" "mcbe@$instance" 2>&1 || true)
if echo "$offline" | grep -q do-not-print; then
	>&2 echo mcbe_log printed webhook when offline
	exit 1
fi

echo Test mc_cmd multiline input
"/opt/MCscripts/bin/mc_cmd$extension" "mcbe@$instance" help$'\n'say Hello world

echo Test mc_stop runs outside systemd
"/opt/MCscripts/bin/mc_stop$extension" -s 0 "mcbe@$instance"

echo All tests passed
