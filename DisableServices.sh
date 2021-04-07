#!/usr/bin/env bash

# Exit if error
set -e
# List includes current and past services
scripts=(DisableServices.sh EnableServices.sh MCBE_Bot.sh MCBEautoUpdate.sh MCBEbackup.sh MCBEgetZIP.sh MCBElog.sh MCBEupdate.sh MCbackup.sh MCcolor.sed MCgetJAR.sh MCrunCmd.sh MCstop.sh MoveServers.sh)
services=(mc-backup@*.timer mc-rmbackup@*.service mc@*.service mc@*.socket mcbe-autoupdate@*.service mcbe-autoupdate@*.timer mcbe-backup@*.timer mcbe-bot@*.service mcbe-bot@*.timer mcbe-getzip.timer mcbe-log@*.service mcbe-log@*.timer mcbe-rmbackup@*.service mcbe@*.service mcbe@*.socket)
units=(mc-backup@.service mc-backup@.timer mc-rmbackup@.service mc@.service mc@.socket mcbe-autoupdate@.service mcbe-autoupdate@.timer mcbe-backup@.service mcbe-backup@.timer mcbe-bot@.service mcbe-bot@.timer mcbe-getzip.service mcbe-getzip.timer mcbe-log@.service mcbe-log@.timer mcbe-rmbackup@.service mcbe@.service mcbe@.socket)
syntax='Usage: DisableServices.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo 'Find enabled services from MCscripts, prompt user to disable them and remove their files, and list services in ~mc/disabled_services.txt.'
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

echo "${enabled[*]}" | sudo tee ~mc/disabled_services.txt > /dev/null
if [ -n "${enabled[*]}" ]; then
	sudo systemctl disable "${enabled[@]}" --now
fi
if [ -n "${active[*]}" ]; then
	sudo systemctl stop "${active[@]}"
fi

for file in "${scripts[@]}"; do
	sudo rm -f ~mc/"$file"
done
for file in "${units[@]}"; do
	sudo rm -f "/etc/systemd/system/$file"
done

echo '@@@ Disabled services are listed in ~mc/disabled_services.txt @@@'
