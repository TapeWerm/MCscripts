#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: EnableServices.sh'

case $1 in
--help|-h)
	echo "$syntax"
	echo 'Read ~mc/disabled_services.txt, update list of services to be reenabled, and enable them.'
	exit
	;;
esac
if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

enabled=($(cat ~mc/disabled_services.txt))
if [ -z "${enabled[*]}" ]; then
	echo No services to reenable
	exit
fi
# Update list of services to be reenabled
for x in "${!enabled[@]}"; do
	# Replace mcbe-autoupdate timer with service and mcbe-getzip
	if [[ "${enabled[x]}" =~ ^mcbe-autoupdate@.+\.timer$ ]]; then
		# Trim off ${enabled[x]} after last .
		instance=${enabled[x]%.*}
		enabled+=("$instance.service")
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
			enabled+=("$instance.socket")
		fi
	# If there's mcbe service but no socket add socket
	elif [[ "${enabled[x]}" =~ ^mcbe@.+\.service$ ]]; then
		instance=${enabled[x]%.*}
		if ! echo "${enabled[*]}" | grep -q "$instance.socket"; then
			enabled+=("$instance.socket")
		fi
	fi
done
if [ "$getzip" = true ]; then
	enabled+=("mcbe-getzip.timer")
fi
# Dependency jobs will fail until dependencies finish starting
sudo systemctl enable "${enabled[@]}" --now || true
