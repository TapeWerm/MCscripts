#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: enable_services.sh'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Read ~mc/disabled_services.txt, update list of services to be reenabled, and enable them.'
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

disabled=$(cat ~mc/disabled_services.txt)
for x in $disabled; do
	enabled+=("$x")
done
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
	# Don't reenable removed service
	elif [[ "${enabled[x]}" =~ ^mcbe-bot@.+\.service$ ]]; then
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
# Update systemd overrides
while read -r override; do
	sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
done < <(ls /etc/systemd/system/mc@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/MCbackup\.sh/mc_backup\.sh/g' "$override"
done < <(ls /etc/systemd/system/mc-backup@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/%i_Backups/%i_backups/g' "$override"
	sed -i 's|java/%i_backups|java_backups/%i|g' "$override"
	sed -i "s/xargs -0d '\\\n' ls -t/xargs -0rd '\\\n' ls -t/g" "$override"
done < <(ls /etc/systemd/system/mc-rmbackup@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
done < <(ls /etc/systemd/system/mcbe@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/MCBEbackup\.sh/mcbe_backup\.sh/g' "$override"
done < <(ls /etc/systemd/system/mcbe-backup@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/%i_Backups/%i_backups/g' "$override"
	sed -i 's|bedrock/%i_backups|bedrock_backups/%i|g' "$override"
	sed -i "s/xargs -0d '\\\n' ls -t/xargs -0rd '\\\n' ls -t/g" "$override"
done < <(ls /etc/systemd/system/mcbe-rmbackup@*.service.d/*.conf 2> /dev/null)
while read -r override; do
	sed -i 's/MCBEgetZIP\.sh/mcbe_getzip\.sh/g' "$override"
done < <(ls /etc/systemd/system/mcbe-getzip.service.d/*.conf 2> /dev/null)
# Move webhooks for mcbe-log
if [ -d ~mc/.MCBE_Bot ]; then
	while read -r file; do
		# Trim off $file after last suffix
		mv "$file" "${file%_BotWebhook.txt}_webhook.txt"
	done < <(ls ~mc/.MCBE_Bot/*_BotWebhook.txt 2> /dev/null)
	mv ~mc/.MCBE_Bot ~mc/.mcbe_log
fi
# Enable dependencies first
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.socket$|^mcbe@.+\.socket$ ]]; then
		systemctl enable "${enabled[x]}" --now
		unset 'enabled[x]'
	fi
done
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.service$|^mcbe@.+\.service$ ]]; then
		systemctl enable "${enabled[x]}" --now
		unset 'enabled[x]'
	fi
done
if [ -n "${enabled[*]}" ]; then
	systemctl enable "${enabled[@]}" --now
fi
