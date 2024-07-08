#!/bin/bash

# Exit if error
set -e
syntax='Usage: mcbe_autoupdate.sh [OPTION]... SERVER_DIR SERVICE'
version=current
args_current=false
args_preview=false
zips_dir=~mc/bedrock_zips

args=$(getopt -l current,help,preview -o chp -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--current|-c)
		args_current=true
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo "If SERVER_DIR/.MCscripts/version isn't the same as the ZIP in ~mc, back up, update, and restart service of Minecraft Bedrock Edition server."
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-c, --current  update to current version (default)'
		echo '-p, --preview  update to preview version'
		exit
		;;
	--preview|-p)
		args_preview=true
		shift
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

if [ "$(echo "$args_current $args_preview" | grep -o true | wc -l)" -gt 1 ]; then
	>&2 echo current and preview are mutually exclusive
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

config_files=(/etc/MCscripts/mcbe-autoupdate.toml "/etc/MCscripts/mcbe-autoupdate/$instance.toml")
for config_file in "${config_files[@]}"; do
	if [ -f "$config_file" ]; then
		if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print("version" in CONFIG)' "$config_file")" = True ]; then
			config_version=$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(CONFIG["version"])' "$config_file")
			if [ "$config_version" = current ]; then
				version=current
			elif [ "$config_version" = preview ]; then
				version=preview
			else
				>&2 echo "No version $config_version, check $config_file"
				exit 1
			fi
		fi
	fi
done

if [ "$args_current" = true ]; then
	version=current
elif [ "$args_preview" = true ]; then
	version=preview
fi

if [ -h "$zips_dir/$version" ]; then
	minecraft_zip=$(realpath "$zips_dir/$version")
else
	>&2 echo "No bedrock-server ZIP $zips_dir/$version"
	exit 1
fi
# Trim off $minecraft_zip after last .zip
current_ver=$(basename "${minecraft_zip%.zip}")

if [ "$installed_ver" = fail ]; then
	echo "Previous update failed, rm $mcscripts_dir/version and try again"
	exit 1
elif [ "$installed_ver" != "$current_ver" ]; then
	trap 'mkdir -p "$mcscripts_dir"; echo fail > "$mcscripts_dir/version"' ERR
	systemctl start "mcbe-backup@$instance"
	trap 'systemctl start "$service"' EXIT
	systemctl stop "$service.socket"
	# mcbe_update.sh reads y asking if you stopped the server
	echo y | systemd-run -PGqp User=mc /opt/MCscripts/bin/mcbe_update.sh "$server_dir" "$minecraft_zip"
fi
