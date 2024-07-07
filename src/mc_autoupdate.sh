#!/bin/bash

# Exit if error
set -e
syntax='Usage: mc_autoupdate.sh SERVER_DIR SERVICE'
jars_dir=~mc/java_jars

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "If SERVER_DIR/.MCscripts/version isn't the same as the JAR in ~mc, back up, update, and restart service of Minecraft Java Edition server."
		echo
		echo 'Positional arguments:'
		echo 'SERVER_DIR  Minecraft Java Edition server directory'
		echo 'SERVICE     systemd service'
		exit
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo 'Not enough arguments'
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo 'Too much arguments'
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath -- "$1")
mcscripts_dir=$server_dir/.MCscripts
# cat fails if there's no file $mcscripts_dir/version
installed_ver=$(cat "$mcscripts_dir/version" 2> /dev/null || true)

# Trim off $2 after last .service
service=${2%.service}
if ! systemctl is-active -q -- "$service"; then
	>&2 echo "Service $service not active"
	exit 1
fi
# Trim off $service before last @
instance=${service##*@}

if [ -h "$jars_dir/current" ]; then
	minecraft_jar=$(realpath "$jars_dir/current")
else
	>&2 echo "No minecraft_server JAR $jars_dir/current"
	exit 1
fi
# Trim off $minecraft_jar after last .jar
current_ver=$(basename "${minecraft_jar%.jar}")

if [ "$installed_ver" = fail ]; then
	echo "Previous update failed, rm $mcscripts_dir/version and try again"
	exit 1
elif [ "$installed_ver" != "$current_ver" ]; then
	trap 'echo fail > "$mcscripts_dir/version"' ERR
	systemctl start "mc-backup@$instance"
	trap 'systemctl start "$service"' EXIT
	systemctl stop "$service.socket"
	cp "$jars_dir/current" "$server_dir/server.jar"
	echo "$current_ver" > "$mcscripts_dir/version"
fi
