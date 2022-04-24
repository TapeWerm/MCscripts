#!/usr/bin/env bash

# Exit if error
set -e
backup_dir=/opt/MCscripts/backup_dir
syntax='Usage: move_backups.sh'

# Merge directory $1 into directory $2
merge_dirs() {
	while read -r file; do
		dir=$(dirname "$file")
		mkdir -p "$2/$dir"
		mv -n "$1/$file" "$2/$file"
	done < <(find "$1" -type f -printf '%P\n')
	find "$1" -type d -empty -delete
}

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "Find Minecraft Java Edition or Bedrock Edition backups in $backup_dir and update their paths."
		echo
		echo Run move_servers.sh before running move_backup.sh.
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

# If $backup_dir is case insensitive, rename directories
if [ -d "$backup_dir/java" ] && [ "$backup_dir/java" -ef "$backup_dir/Java" ]; then
	while read -r server_backups; do
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups"/server.jar ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_Backups}")
			while read -r world_backups; do
				# Trim off $world_backups after last suffix
				world=$(basename "${world_backups%_Backups}")
				mv "$server_backups/${world}_Backups" "$server_backups/${world}_Backups.old"
				mv "$server_backups/${world}_Backups.old" "$server_backups/${world}_backups"
			done < <(ls -d "$server_backups"/*_Backups 2> /dev/null)
			mv "$backup_dir/java/$server"_Backups "$backup_dir/java/$server"_Backups.old
			mv "$backup_dir/java/$server"_Backups.old "$backup_dir/java/$server"_backups
		fi
	done < <(ls -d "$backup_dir"/java/*_Backups 2> /dev/null)
# Else move from $server_Backups to $server_backups
else
	while read -r server_backups; do
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups"/server.jar ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_Backups}")
			while read -r world_backups; do
				# Trim off $world_backups after last suffix
				world=$(basename "${world_backups%_Backups}")
				new_backups=$backup_dir/java/${server}_backups/${world}_backups
				merge_dirs "$world_backups" "$new_backups"
			done < <(ls -d "$server_backups"/*_Backups 2> /dev/null)
			rmdir "$server_backups"
		fi
	done < <(ls -d "$backup_dir"/java/*_Backups 2> /dev/null)
fi

# Move from java to java_backups
while read -r server_backups; do
	# If $server_backups doesn't have an executable
	if [ ! -f "$server_backups"/server.jar ]; then
		# Trim off $server_backups after last suffix
		server=$(basename "${server_backups%_backups}")
		while read -r world_backups; do
			# Trim off $world_backups after last suffix
			world=$(basename "${world_backups%_backups}")
			new_backups=$backup_dir/java_backups/$server/$world
			merge_dirs "$world_backups" "$new_backups"
		done < <(ls -d "$server_backups"/*_backups 2> /dev/null)
		rmdir "$server_backups"
	fi
done < <(ls -d "$backup_dir"/java/*_backups 2> /dev/null)
if [ ! "$backup_dir" -ef ~mc ] && [ -d "$backup_dir/java" ]; then
	rmdir "$backup_dir/java"
fi

chown -Rf root:root "$backup_dir/java_backups" || true

# If $backup_dir is case insensitive, rename directories
if [ -d "$backup_dir/bedrock" ] && [ "$backup_dir/bedrock" -ef "$backup_dir/Bedrock" ]; then
	while read -r server_backups; do
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups"/bedrock_server ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_Backups}")
			while read -r world_backups; do
				# Trim off $world_backups after last suffix
				world=$(basename "${world_backups%_Backups}")
				mv "$server_backups/${world}_Backups" "$server_backups/${world}_Backups.old"
				mv "$server_backups/${world}_Backups.old" "$server_backups/${world}_backups"
			done < <(ls -d "$server_backups"/*_Backups 2> /dev/null)
			mv "$backup_dir/bedrock/$server"_Backups "$backup_dir/bedrock/$server"_Backups.old
			mv "$backup_dir/bedrock/$server"_Backups.old "$backup_dir/bedrock/$server"_backups
		fi
	done < <(ls -d "$backup_dir"/bedrock/*_Backups 2> /dev/null)
# Else move from $server_Backups to $server_backups
else
	while read -r server_backups; do
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups"/bedrock_server ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_Backups}")
			while read -r world_backups; do
				# Trim off $world_backups after last suffix
				world=$(basename "${world_backups%_Backups}")
				new_backups=$backup_dir/bedrock/${server}_backups/${world}_backups
				merge_dirs "$world_backups" "$new_backups"
			done < <(ls -d "$server_backups"/*_Backups 2> /dev/null)
			rmdir "$server_backups"
		fi
	done < <(ls -d "$backup_dir"/bedrock/*_Backups 2> /dev/null)
fi

# Move from bedrock to bedrock_backups
while read -r server_backups; do
	# If $server_backups doesn't have an executable
	if [ ! -f "$server_backups"/bedrock_server ]; then
		# Trim off $server_backups after last suffix
		server=$(basename "${server_backups%_backups}")
		while read -r world_backups; do
			# Trim off $world_backups after last suffix
			world=$(basename "${world_backups%_backups}")
			new_backups=$backup_dir/bedrock_backups/$server/$world
			merge_dirs "$world_backups" "$new_backups"
		done < <(ls -d "$server_backups"/*_backups 2> /dev/null)
		rmdir "$server_backups"
	fi
done < <(ls -d "$backup_dir"/bedrock/*_backups 2> /dev/null)
if [ ! "$backup_dir" -ef ~mc ] && [ -d "$backup_dir/bedrock" ]; then
	rmdir "$backup_dir/bedrock"
fi

chown -Rf root:root "$backup_dir/bedrock_backups" || true
