#!/usr/bin/env bash

# Exit if error
set -e
# mcbe-autoupdate.service and mcbe-log@*.timer used to be in MCscripts
services=(mc@*.service mc-backup@*.timer mc-rmbackup@*.service mcbe@*.service mcbe-backup@*.timer mcbe-getzip.timer mcbe-autoupdate.service mcbe-autoupdate@*.service mcbe-rmbackup@*.service mcbe-bot@*.service mcbe-bot@*.timer mcbe-log@*.service mcbe-log@*.timer)
units=(mc-backup@.service mc-backup@.timer mcbe-autoupdate.service mcbe-autoupdate@.service mcbe-backup@.service mcbe-backup@.timer mcbe-bot@.service mcbe-bot@.timer mcbe-getzip.service mcbe-getzip.timer mcbe-log@.service mcbe-log@.timer mcbe-rmbackup@.service mcbe@.service mcbe@.socket mc-rmbackup@.service mc@.service mc@.socket)
syntax='Usage: DisableServices.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo Find enabled services from MCscripts and prompt user to disable them and remove their files.
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
sudo rm ~mc/*.sh
for file in "${units[@]}"; do sudo rm -f "/etc/systemd/system/$file"; done
echo To reenable services copy and paste this later:
echo "sudo systemctl enable ${enabled[*]} --now"
