#!/usr/bin/env bash

# Exit if error
set -e
services=(mc@*.service mc-backup@*.timer mc-rmbackup@*.service mcbe@*.service mcbe-backup@*.timer mcbe-getzip.timer mcbe-autoupdate@*.service mcbe-rmbackup@*.service mcbe-bot@*.service mcbe-log@*.service)
syntax='Usage: DisableServices.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo Find enabled services and prompt user to disable them and remove their files.
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
		if systemctl is-enabled "$instance" > /dev/null; then
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
echo "Enter Y to disable services (make sure people aren't playing first)"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

sudo systemctl disable "${enabled[@]}" --now
sudo rm ~mc/*.sh
for file in systemd/*; do sudo rm "/etc/systemd/system/$(basename "$file")"; done
