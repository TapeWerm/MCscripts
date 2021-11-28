#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: disable_services.sh'

# Current scripts
scripts=(mc_backup.sh mc_cmd.sh mc_color.sed mc_getjar.sh mc_stop.sh)
scripts+=(mcbe_autoupdate.sh mcbe_backup.sh mcbe_getzip.sh mcbe_log.sh mcbe_update.sh)
scripts+=(disable_services.sh enable_services.sh move_backups.sh move_servers.sh)
# Removed scripts
scripts+=(MCbackup.sh MCcolor.sed MCgetJAR.sh MCrunCmd.sh MCstop.sh)
scripts+=(MCBE_Bot.sh MCBEautoUpdate.sh MCBEbackup.sh MCBEgetZIP.sh MCBElog.sh MCBEupdate.sh)
scripts+=(DisableServices.sh EnableServices.sh MoveServers.sh)

# Current services
services=(mc@*.socket mc@*.service mc-backup@*.timer mc-rmbackup@*.service)
services+=(mcbe@*.socket mcbe@*.service mcbe-backup@*.timer mcbe-getzip.timer mcbe-autoupdate@*.service mcbe-rmbackup@*.service mcbe-log@*.service)
# Removed services
services+=(mcbe-autoupdate@*.timer mcbe-bot@*.service mcbe-bot@*.timer mcbe-log@*.timer)

# Current units
units=(mc-backup@.service mc-backup@.timer mc-rmbackup@.service mc@.service mc@.socket)
units+=(mcbe-autoupdate@.service mcbe-backup@.service mcbe-backup@.timer mcbe-getzip.service mcbe-getzip.timer mcbe-log@.service mcbe-rmbackup@.service mcbe@.service mcbe@.socket)
# Removed units
units+=(mcbe-autoupdate@.timer mcbe-bot@.service mcbe-bot@.timer mcbe-log@.timer)

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Find enabled services from MCscripts, prompt user to disable them and remove their files, and list services in ~mc/disabled_services.txt.'
		exit
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

instances=$(systemctl show "${services[@]}" -p Id --value | grep .)
if [ -n "$instances" ]; then
	while read -r instance; do
		if [ "$(systemctl is-enabled "$instance" 2> /dev/null)" = enabled ]; then
			enabled+=("$instance")
		elif [ "$(systemctl is-active "$instance" 2> /dev/null)" = active ]; then
			active+=("$instance")
		fi
	# Bash process substitution
	done < <(echo "$instances")
fi

if [ -z "${enabled[*]}" ] && [ -z "${active[*]}" ]; then
	echo No services enabled
	exit
fi
echo "Enabled services: ${enabled[*]}"
echo "Active but not enabled services: ${active[*]}"
echo "Enter Y to disable services and remove their files (make sure people aren't playing first)"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

echo "${enabled[*]}" > ~mc/disabled_services.txt
if [ -n "${enabled[*]}" ]; then
	systemctl disable "${enabled[@]}" --now
fi
if [ -n "${active[*]}" ]; then
	systemctl stop "${active[@]}"
fi

for file in "${scripts[@]}"; do
	rm -f ~mc/"$file"
done
for file in "${units[@]}"; do
	rm -f "/etc/systemd/system/$file"
done

echo '@@@ Disabled services are listed in ~mc/disabled_services.txt @@@'
