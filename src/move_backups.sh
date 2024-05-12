#!/usr/bin/env bash

# Exit if error
set -e
backup_dir=/opt/MCscripts/backup_dir
syntax='Usage: move_backups.sh'

# Merge directory $1 into directory $2
merge_dirs() {
	local src
	src=$(realpath -- "$1")
	local dest
	dest=$(realpath -- "$2")
	merge_dirs_recursive "$src" "$dest"
	find "$src" -type d -empty -delete
}

merge_dirs_recursive() {
	local src
	src=$1
	local dest
	dest=$2
	find "$src" -mindepth 1 -maxdepth 1 -type f -print0 | while IFS='' read -rd '' file; do
		mv -n "$file" "$dest/"
	done
	find "$src" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS='' read -rd '' dir; do
		dir=$(basename "$dir")
		if [ ! -e "$dest/$dir" ]; then
			mkdir "$dest/$dir"
		fi
		if [ -d "$dest/$dir" ] && [ ! -h "$dest/$dir" ]; then
			merge_dirs_recursive "$src/$dir" "$dest/$dir"
		fi
	done
}

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
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
	for server_backups in "$backup_dir"/java/*_Backups; do
		if [ -d "$server_backups" ]; then
			# If $server_backups doesn't have an executable
			if [ ! -f "$server_backups/server.jar" ]; then
				# Trim off $server_backups after last suffix
				server=$(basename "${server_backups%_Backups}")
				for world_backups in "$server_backups"/*_Backups; do
					if [ -d "$world_backups" ]; then
						# Trim off $world_backups after last suffix
						world=$(basename "${world_backups%_Backups}")
						mv "$server_backups/${world}_Backups" "$server_backups/${world}_Backups.old"
						mv "$server_backups/${world}_Backups.old" "$server_backups/${world}_backups"
					fi
				done
				mv "$backup_dir/java/${server}_Backups" "$backup_dir/java/${server}_Backups.old"
				mv "$backup_dir/java/${server}_Backups.old" "$backup_dir/java/${server}_backups"
			fi
		fi
	done
# Else move from $server_Backups to $server_backups
else
	for server_backups in "$backup_dir"/java/*_Backups; do
		if [ -d "$server_backups" ]; then
			# If $server_backups doesn't have an executable
			if [ ! -f "$server_backups/server.jar" ]; then
				# Trim off $server_backups after last suffix
				server=$(basename "${server_backups%_Backups}")
				for world_backups in "$server_backups"/*_Backups; do
					if [ -d "$world_backups" ]; then
						# Trim off $world_backups after last suffix
						world=$(basename "${world_backups%_Backups}")
						new_backups=$backup_dir/java/${server}_backups/${world}_backups
						merge_dirs "$world_backups" "$new_backups"
					fi
				done
				rmdir "$server_backups"
			fi
		fi
	done
fi

# Move from java to java_backups
for server_backups in "$backup_dir"/java/*_backups; do
	if [ -d "$server_backups" ]; then
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups/server.jar" ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_backups}")
			for world_backups in "$server_backups"/*_backups; do
				if [ -d "$world_backups" ]; then
					# Trim off $world_backups after last suffix
					world=$(basename "${world_backups%_backups}")
					new_backups=$backup_dir/java_backups/$server/$world
					merge_dirs "$world_backups" "$new_backups"
				fi
			done
			rmdir "$server_backups"
		fi
	fi
done
if [ ! "$backup_dir" -ef ~mc ] && [ -d "$backup_dir/java" ]; then
	rmdir "$backup_dir/java"
fi

chown -Rf root:root "$backup_dir/java_backups" || true

# If $backup_dir is case insensitive, rename directories
if [ -d "$backup_dir/bedrock" ] && [ "$backup_dir/bedrock" -ef "$backup_dir/Bedrock" ]; then
	for server_backups in "$backup_dir"/bedrock/*_Backups; do
		if [ -d "$server_backups" ]; then
			# If $server_backups doesn't have an executable
			if [ ! -f "$server_backups/bedrock_server" ]; then
				# Trim off $server_backups after last suffix
				server=$(basename "${server_backups%_Backups}")
				for world_backups in "$server_backups"/*_Backups; do
					if [ -d "$world_backups" ]; then
						# Trim off $world_backups after last suffix
						world=$(basename "${world_backups%_Backups}")
						mv "$server_backups/${world}_Backups" "$server_backups/${world}_Backups.old"
						mv "$server_backups/${world}_Backups.old" "$server_backups/${world}_backups"
					fi
				done
				mv "$backup_dir/bedrock/${server}_Backups" "$backup_dir/bedrock/${server}_Backups.old"
				mv "$backup_dir/bedrock/${server}_Backups.old" "$backup_dir/bedrock/${server}_backups"
			fi
		fi
	done
# Else move from $server_Backups to $server_backups
else
	for server_backups in "$backup_dir"/bedrock/*_Backups; do
		if [ -d "$server_backups" ]; then
			# If $server_backups doesn't have an executable
			if [ ! -f "$server_backups/bedrock_server" ]; then
				# Trim off $server_backups after last suffix
				server=$(basename "${server_backups%_Backups}")
				for world_backups in "$server_backups"/*_Backups; do
					if [ -d "$world_backups" ]; then
						# Trim off $world_backups after last suffix
						world=$(basename "${world_backups%_Backups}")
						new_backups=$backup_dir/bedrock/${server}_backups/${world}_backups
						merge_dirs "$world_backups" "$new_backups"
					fi
				done
				rmdir "$server_backups"
			fi
		fi
	done
fi

# Move from bedrock to bedrock_backups
for server_backups in "$backup_dir"/bedrock/*_backups; do
	if [ -d "$server_backups" ]; then
		# If $server_backups doesn't have an executable
		if [ ! -f "$server_backups/bedrock_server" ]; then
			# Trim off $server_backups after last suffix
			server=$(basename "${server_backups%_backups}")
			for world_backups in "$server_backups"/*_backups; do
				if [ -d "$world_backups" ]; then
					# Trim off $world_backups after last suffix
					world=$(basename "${world_backups%_backups}")
					new_backups=$backup_dir/bedrock_backups/$server/$world
					merge_dirs "$world_backups" "$new_backups"
				fi
			done
			rmdir "$server_backups"
		fi
	fi
done
if [ ! "$backup_dir" -ef ~mc ] && [ -d "$backup_dir/bedrock" ]; then
	rmdir "$backup_dir/bedrock"
fi

chown -Rf root:root "$backup_dir/bedrock_backups" || true
