#!/bin/bash

# Exit if error
set -e
services_file=/opt/MCscripts/disabled_services.txt
syntax='Usage: enable_services.sh'
zips_dir=~mc/bedrock_zips

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
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
	# If there's mc service but no socket add socket
	if [[ "${enabled[x]}" =~ ^mc@.+\.service$ ]]; then
		instance=${enabled[x]%.*}
		if ! echo "${enabled[*]}" | grep -q "$instance\\.socket"; then
			enabled+=("$instance.socket")
		fi
	# Replace mcbe-autoupdate timer with service and mcbe-getzip
	elif [[ "${enabled[x]}" =~ ^mcbe-autoupdate@.+\.timer$ ]]; then
		# Trim off ${enabled[x]} after last .
		instance=${enabled[x]%.*}
		enabled+=("$instance.service")
		getzip=true
		unset 'enabled[x]'
	# Don't reenable removed service
	elif [[ "${enabled[x]}" =~ ^mcbe-bot@.+\.service$ ]]; then
		unset 'enabled[x]'
	# Don't reenable removed timer
	elif [[ "${enabled[x]}" =~ ^mcbe-bot@.+\.timer$ ]]; then
		unset 'enabled[x]'
	# Don't reenable removed timer
	elif [[ "${enabled[x]}" =~ ^mcbe-log@.+\.timer$ ]]; then
		unset 'enabled[x]'
	# If there's mcbe service but no socket add socket
	elif [[ "${enabled[x]}" =~ ^mcbe@.+\.service$ ]]; then
		instance=${enabled[x]%.*}
		if ! echo "${enabled[*]}" | grep -q "$instance\\.socket"; then
			enabled+=("$instance.socket")
		fi
	fi
done
if [ "$getzip" = true ]; then
	enabled+=(mcbe-getzip.timer)
fi
# Update systemd overrides
for override in /etc/systemd/system/mc-backup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCbackup\.sh/mc_backup\.sh/g' "$override"
		sed -i 's|MC/mc_backup\.sh|MCscripts/mc_backup\.sh|g' "$override"
		sed -i 's|MCscripts/mc_backup\.sh|MCscripts/bin/mc_backup\.sh|g' "$override"
		sed -i 's|MCscripts/mc_backup\.py|MCscripts/bin/mc_backup\.py|g' "$override"
	fi
done
for override in /etc/systemd/system/mc-rmbackup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/%i_Backups/%i_backups/g' "$override"
		sed -i 's|java/%i_backups|java_backups/%i|g' "$override"
		sed -i 's|MC/backup_dir|MCscripts/backup_dir|g' "$override"
		sed -i "s/xargs -0d '\\\\n' ls -t/xargs -0rd '\\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0rd '\\\\n' ls -t/xargs -rd '\\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0d '\\\\n' rm -f/xargs -d '\\\\n' rm -f/g" "$override"
	fi
done
for override in /etc/systemd/system/mc@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		sed -i 's|MC/mc_stop\.sh|MCscripts/mc_stop\.sh|g' "$override"
		sed -i 's|MCscripts/mc_stop\.sh|MCscripts/bin/mc_stop\.sh|g' "$override"
		sed -i 's|MCscripts/mc_stop\.py|MCscripts/bin/mc_stop\.py|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-autoupdate@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's|MCscripts/mcbe_autoupdate\.sh|MCscripts/bin/mcbe_autoupdate\.sh|g' "$override"
		sed -i 's|MCscripts/mcbe_autoupdate\.py|MCscripts/bin/mcbe_autoupdate\.py|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-backup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCBEbackup\.sh/mcbe_backup\.sh/g' "$override"
		sed -i 's|MC/mcbe_backup\.sh|MCscripts/mcbe_backup\.sh|g' "$override"
		sed -i 's|MCscripts/mcbe_backup\.sh|MCscripts/bin/mcbe_backup\.sh|g' "$override"
		sed -i 's|MCscripts/mcbe_backup\.py|MCscripts/bin/mcbe_backup\.py|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-getzip.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCBEgetZIP\.sh/mcbe_getzip\.sh/g' "$override"
		sed -i 's|MC/mcbe_getzip\.sh|MCscripts/mcbe_getzip\.sh|g' "$override"
		sed -i 's|MCscripts/mcbe_getzip\.sh|MCscripts/bin/mcbe_getzip\.sh|g' "$override"
		sed -i 's|MCscripts/mcbe_getzip\.py|MCscripts/bin/mcbe_getzip\.py|g' "$override"
	fi
done
for override in /etc/systemd/system/mcbe-rmbackup@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/%i_Backups/%i_backups/g' "$override"
		sed -i 's|bedrock/%i_backups|bedrock_backups/%i|g' "$override"
		sed -i 's|MC/backup_dir|MCscripts/backup_dir|g' "$override"
		sed -i "s/xargs -0d '\\\\n' ls -t/xargs -0rd '\\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0rd '\\\\n' ls -t/xargs -rd '\\\\n' ls -t/g" "$override"
		sed -i "s/xargs -0d '\\\\n' rm -f/xargs -d '\\\\n' rm -f/g" "$override"
	fi
done
for override in /etc/systemd/system/mcbe@*.service.d/*.conf; do
	if [ -f "$override" ]; then
		sed -i 's/MCstop\.sh/mc_stop\.sh/g' "$override"
		sed -i 's|MC/mc_stop\.sh|MCscripts/mc_stop\.sh|g' "$override"
		sed -i 's|MCscripts/mc_stop\.sh|MCscripts/bin/mc_stop\.sh|g' "$override"
		sed -i 's|MCscripts/mc_stop\.py|MCscripts/bin/mc_stop\.py|g' "$override"
	fi
done
# Move webhooks for mcbe-log
if [ -d ~mc/.MCBE_Bot ]; then
	for webhook_file in ~mc/.MCBE_Bot/*_BotWebhook.txt; do
		if [ -f "$webhook_file" ]; then
			# Trim off $webhook_file after last suffix
			mv "$webhook_file" "${webhook_file%_BotWebhook.txt}_webhook.txt"
		fi
	done
	mv ~mc/.MCBE_Bot ~mc/.mcbe_log
fi
if [ -d /opt/MCscripts/.mcbe_log ]; then
	mv /opt/MCscripts/.mcbe_log ~mc/
fi
if [ -d ~mc/.mcbe_log ]; then
	chown -R mc:mc ~mc/.mcbe_log
	for webhook_file in ~mc/.mcbe_log/*_webhook.txt; do
		if [ -f "$webhook_file" ]; then
			for chat in discord rocket; do
				if [ "$chat" = discord ]; then
					chat_urls=$(grep -E '^https://discord(app)?\.com' "$webhook_file" || true)
					# Trim off $webhook_file after last suffix
					chat_file=${webhook_file%_webhook.txt}_discord.txt
				elif [ "$chat" = rocket ]; then
					# Rocket Chat can be hosted by any domain
					chat_urls=$(grep -E '^https://rocket\.' "$webhook_file" || true)
					# Trim off $webhook_file after last suffix
					chat_file=${webhook_file%_webhook.txt}_rocket.txt
				fi
				if [ -n "$chat_urls" ]; then
					touch "$chat_file"
					chmod 600 "$chat_file"
					chown mc:mc "$chat_file"
					echo "$chat_urls" > "$chat_file"
				fi
			done
			rm "$webhook_file"
		fi
	done
fi
# Move bedrock ZIPs
if ls ~mc/bedrock-server-*.zip &> /dev/null && [ ! -d "$zips_dir" ]; then
	mkdir "$zips_dir"
	chown mc:mc "$zips_dir"
	for zip in ~mc/bedrock-server-*.zip; do
		if [ -f "$zip" ]; then
			mv "$zip" "$zips_dir/"
		fi
	done
fi
# Make .MCscripts
for server_dir in ~mc/bedrock/*; do
	if [ -d "$server_dir" ]; then
		mcscripts_dir=$server_dir/.MCscripts
		mkdir -p "$mcscripts_dir"
		chown mc:mc "$mcscripts_dir"
	fi
done
for server_dir in ~mc/java/*; do
	if [ -d "$server_dir" ]; then
		mcscripts_dir=$server_dir/.MCscripts
		mkdir -p "$mcscripts_dir"
		chown mc:mc "$mcscripts_dir"
		if [ ! -f "$mcscripts_dir/start.sh" ]; then
			echo '#!/bin/bash' > "$mcscripts_dir/start.sh"
			echo >> "$mcscripts_dir/start.sh"
			echo java -jar server.jar --nogui >> "$mcscripts_dir/start.sh"
			echo "@@@ $mcscripts_dir/start.sh replaced $server_dir/start.bat in MCscripts v6.0.0 @@@"
		fi
		chmod +x "$mcscripts_dir/start.sh"
		chown mc:mc "$mcscripts_dir/start.sh"
	fi
done
# Enable dependencies first
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.socket$|^mcbe@.+\.socket$ ]]; then
		systemctl enable --now -- "${enabled[x]}"
		unset 'enabled[x]'
	fi
done
for x in "${!enabled[@]}"; do
	if [[ "${enabled[x]}" =~ ^mc@.+\.service$|^mcbe@.+\.service$ ]]; then
		systemctl enable --now -- "${enabled[x]}"
		unset 'enabled[x]'
	fi
done
if [ -n "${enabled[*]}" ]; then
	systemctl enable --now -- "${enabled[@]}"
fi
