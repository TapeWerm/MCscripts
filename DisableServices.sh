#!/usr/bin/env bash

# Exit if error
set -e
scripts=(DisableServices.sh MCbackup.sh MCBEautoUpdate.sh MCBEbackup.sh MCBE_Bot.sh MCBEgetZIP.sh MCBElog.sh MCBEupdate.sh MCgetJAR.sh MCstop.sh MoveServers.sh)
# mcbe-autoupdate@*.timer and mcbe-log@*.timer used to be in MCscripts
services=(mc@*.socket mc@*.service mc-backup@*.timer mc-rmbackup@*.service mcbe@*.socket mcbe@*.service mcbe-backup@*.timer mcbe-getzip.timer mcbe-autoupdate@*.service mcbe-autoupdate@*.timer mcbe-rmbackup@*.service mcbe-bot@*.service mcbe-bot@*.timer mcbe-log@*.service mcbe-log@*.timer)
units=(mc-backup@.service mc-backup@.timer mcbe-autoupdate@.service mcbe-autoupdate@.timer mcbe-backup@.service mcbe-backup@.timer mcbe-bot@.service mcbe-bot@.timer mcbe-getzip.service mcbe-getzip.timer mcbe-log@.service mcbe-log@.timer mcbe-rmbackup@.service mcbe@.service mcbe@.socket mc-rmbackup@.service mc@.service mc@.socket)
syntax='Usage: DisableServices.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo Find enabled services from MCscripts, prompt user to disable them and remove their files, and list services to be reenabled.
	exit
	;;
esac
if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

instances=$(systemctl show "${services[@]}" -p Id --value | grep .)
if [ -n "$instances" ]; then
	while read -r instance; do
		if [ "$(systemctl is-enabled "$instance" 2> /dev/null)" = enabled ]; then
			enabled+=($instance)
		fi
	# Bash process substitution
	done < <(echo "$instances")
fi

if [ -z "${enabled[*]}" ]; then
	echo No services enabled
	exit
fi
echo "Enabled services: ${enabled[*]}"
echo "Enter Y to disable services and remove their files (make sure people aren't playing first)"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

sudo systemctl disable "${enabled[@]}" --now
for file in "${scripts[@]}"; do
	sudo rm -f ~mc/"$file"
done
for file in "${units[@]}"; do
	sudo rm -f "/etc/systemd/system/$file"
done

# Update list of services to be reenabled
for x in "${!enabled[@]}"; do
	# Replace mcbe-autoupdate timer with service and mcbe-getzip
	if [[ "${enabled[x]}" =~ ^mcbe-autoupdate@.+\.timer$ ]]; then
		# Trim off ${enabled[x]} after last .
		instance=${enabled[x]%.*}
		enabled+=($instance.service)
		getzip=true
		unset 'enabled[x]'
	# Don't reenable removed timer
	elif [[ "${enabled[x]}" =~ ^mcbe-log@.+\.timer$ ]]; then
		unset 'enabled[x]'
	# Don't reenable removed timer
	elif [[ "${enabled[x]}" =~ ^mcbe-bot@.+\.timer$ ]]; then
		unset 'enabled[x]'
	# If there's mc service but no socket add socket
	elif [[ "${enabled[x]}" =~ ^mc@.+\.service$ ]]; then
		instance=${enabled[x]%.*}
		if ! echo "${enabled[*]}" | grep -q "$instance.socket"; then
			enabled+=($instance.socket)
		fi
	# If there's mcbe service but no socket add socket
	elif [[ "${enabled[x]}" =~ ^mcbe@.+\.service$ ]]; then
		instance=${enabled[x]%.*}
		if ! echo "${enabled[*]}" | grep -q "$instance.socket"; then
			enabled+=($instance.socket)
		fi
	fi
done
if [ "$getzip" = true ]; then
	enabled+=(mcbe-getzip.timer)
fi
echo @@@ To reenable services copy and paste this later: @@@
echo "sudo systemctl enable ${enabled[*]} --now"
