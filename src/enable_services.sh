#!/usr/bin/env bash

# Exit if error
set -e
services_file=/opt/MCscripts/disabled_services.txt
syntax='Usage: enable_services.sh'
zips_dir=~mc/bedrock_zips

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "Read $services_file, update list of services to be reenabled, and enable them."
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

disabled=$(cat "$services_file")
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
for override in /etc/systemd/system/mc@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		sed -i 's|MC/mc_stop\.sh|MCscripts/mc_stop\.sh|g' "$override"
	fi
done
for override in /etc/systemd/system/mc-backup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCbackup\.sh/mc_backup\.sh/g' "$override"
		sed -i 's|MC/mc_backup\.sh|MCscripts/mc_backup\.sh|g' "$override"
	fi
done
for override in /etc/systemd/system/mc-rmbackup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/%i_Backups/%i_backups/g' "$override"
		sed -i 's|java/%i_backups|java_backups/%i|g' "$override"
		sed -i 's|MC/backup_dir|MCscripts/backup_dir|g' "$override"
		sed -i "s/xargs -0d '\\\n' ls -t/xargs -0rd '\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0rd '\\\n' ls -t/xargs -rd '\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0d '\\\n' rm -f/xargs -d '\\\n' rm -f/g" "$override"
	fi
done
for override in /etc/systemd/system/mcbe@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		sed -i 's|MC/mc_stop\.sh|MCscripts/mc_stop\.sh|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-backup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCBEbackup\.sh/mcbe_backup\.sh/g' "$override"
		sed -i 's|MC/mcbe_backup\.sh|MCscripts/mcbe_backup\.sh|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-rmbackup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/%i_Backups/%i_backups/g' "$override"
		sed -i 's|bedrock/%i_backups|bedrock_backups/%i|g' "$override"
		sed -i 's|MC/backup_dir|MCscripts/backup_dir|g' "$override"
		sed -i "s/xargs -0d '\\\n' ls -t/xargs -0rd '\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0rd '\\\n' ls -t/xargs -rd '\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0d '\\\n' rm -f/xargs -d '\\\n' rm -f/g" "$override"
	fi
done
for override in /etc/systemd/system/mcbe-getzip.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCBEgetZIP\.sh/mcbe_getzip\.sh/g' "$override"
		sed -i 's|MC/mcbe_getzip\.sh|MCscripts/mcbe_getzip\.sh|g' "$override"
	fi
done
# Move webhooks for mcbe-log
if [ -d ~mc/.MCBE_Bot ]; then
	for file in ~mc/.MCBE_Bot/*_BotWebhook.txt; do
		if [ -f "$file" ]; then
			# Trim off $file after last suffix
			mv "$file" "${file%_BotWebhook.txt}_webhook.txt"
		fi
	done
	mv ~mc/.MCBE_Bot ~mc/.mcbe_log
fi
if [ -d /opt/MCscripts/.mcbe_log ]; then
	mv /opt/MCscripts/.mcbe_log ~mc/
fi
if [ -d ~mc/.mcbe_log ]; then
	chown -R mc:mc ~mc/.mcbe_log
fi
# Move bedrock ZIPs
if [ ! -d "$zips_dir" ]; then
	mkdir "$zips_dir"
	chown mc:mc "$zips_dir"
	for zip in ~mc/bedrock-server-*.zip; do
		if [ -f "$zip" ]; then
			mv "$zip" "$zips_dir/"
		fi
	done
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
