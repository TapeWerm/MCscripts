#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: enable_services.sh'

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

disabled=$(cat ~mc/disabled_services.txt)
for x in $disabled; do
	enabled+=("$x")
done
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
for x in "${!enabled[@]}"; do
	override=/etc/systemd/system/${enabled[x]}.d/override.conf
	if [[ "${enabled[x]}" =~ ^mc@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		fi
	elif [[ "${enabled[x]}" =~ ^mc-backup@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/MCbackup\.sh/mc_backup\.sh/g' "$override"
		fi
	elif [[ "${enabled[x]}" =~ ^mc-rmbackup@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/%i_Backups/%i_backups/g' "$override"
			sed -i 's|java/%i_backups|java_backups/%i|g' "$override"
		fi
	elif [[ "${enabled[x]}" =~ ^mcbe@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		fi
	elif [[ "${enabled[x]}" =~ ^mcbe-backup@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/MCBEbackup\.sh/mcbe_backup\.sh/g' "$override"
		fi
	elif [[ "${enabled[x]}" =~ ^mcbe-rmbackup@.+\.service$ ]]; then
		if [ -f "$override" ]; then
			sed -i 's/%i_Backups/%i_backups/g' "$override"
			sed -i 's|bedrock/%i_backups|bedrock_backups/%i|g' "$override"
		fi
	elif [ "${enabled[x]}" = mcbe-getzip@.service ]; then
		if [ -f "$override" ]; then
			sed -i 's/MCBEgetZIP\.sh/mcbe_getzip\.sh/g' "$override"
		fi
	fi
done
# Move webhooks for mcbe-log
if [ -d ~mc/.MCBE_Bot ]; then
	while read -r file; do
		# Trim off $file after last suffix
		sudo mv "$file" "${file%_BotWebhook.txt}_webhook.txt"
	done < <(ls ~mc/.MCBE_Bot/*_BotWebhook.txt 2> /dev/null || true)
	sudo mv ~mc/.MCBE_Bot ~mc/.mcbe_log
fi
# Enable dependencies first
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.socket$|^mcbe@.+\.socket$ ]]; then
		sudo systemctl enable "${enabled[x]}" --now
		unset 'enabled[x]'
	fi
done
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.service$|^mcbe@.+\.service$ ]]; then
		sudo systemctl enable "${enabled[x]}" --now
		unset 'enabled[x]'
	fi
done
sudo systemctl enable "${enabled[@]}" --now
