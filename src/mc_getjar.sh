#!/bin/bash

# Exit if error
set -e
clobber=true
args_clobber=false
args_no_clobber=false
config_file=/etc/MCscripts/mc-getjar.toml
jars_dir=~/java_jars
syntax='Usage: mc_getjar.sh [OPTION]...'

args=$(getopt -l clobber,help,no-clobber -o hn -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--clobber)
		args_clobber=true
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo "If the JAR of the current version of Minecraft Java Edition server isn't in ~, download it, and remove outdated JARs in ~."
		echo
		echo 'Options:'
		echo '--clobber         remove outdated JARs in ~ (default)'
		echo "-n, --no-clobber  don't remove outdated JARs in ~"
		exit
		;;
	--no-clobber|-n)
		args_no_clobber=true
		shift
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo 'Too much arguments'
	>&2 echo "$syntax"
	exit 1
fi

if [ "$(echo "$args_clobber $args_no_clobber" | grep -o true | wc -l)" -gt 1 ]; then
	>&2 echo 'clobber and no-clobber are mutually exclusive'
	exit 1
fi

if [ -f "$config_file" ]; then
	if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print("clobber" in CONFIG)' "$config_file")" = True ]; then
		if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(isinstance(CONFIG["clobber"], bool))' "$config_file")" = False ]; then
			>&2 echo "clobber must be TOML boolean, check $config_file"
			exit 1
		fi
		clobber=$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(CONFIG["clobber"])' "$config_file")
		clobber=$(echo "$clobber" | tr '[:upper:]' '[:lower:]')
	fi
fi

if [ "$args_clobber" = true ]; then
	clobber=true
elif [ "$args_no_clobber" = true ]; then
	clobber=false
fi

mkdir -p "$jars_dir"

webpage_raw=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server)
webpage=$(echo "$webpage_raw" | hxnormalize -x)
while IFS='' read -rd '' link; do
	links+=("$link")
done < <(echo "$webpage" | hxselect -s '\000' 'a')

echo 'Enter Y if you agree to the Minecraft End User License Agreement and Privacy Policy'
# Does prompting the EULA seem so official that it violates the EULA?
echo 'Minecraft End User License Agreement: https://minecraft.net/eula'
echo 'Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839'
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi
for link in "${links[@]}"; do
	url=$(echo "$link" | hxselect -c 'a::attr(href)')
	if [ -z "$url" ]; then
		continue
	fi
	if echo "$url" | grep -Eq '^https://[^ ]+server\.jar$'; then
		current_ver=$(echo "$link" | hxselect -c 'a')
		current_ver=$(basename -- "$current_ver")
		break
	fi
done
# Symlink to current jar
if [ -h "$jars_dir/current" ]; then
	installed_ver=$(basename "$(realpath "$jars_dir/current")")
fi

if [ ! -f "$jars_dir/$current_ver" ]; then
	curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS "$url" -o "$jars_dir/$current_ver.part"
	mv "$jars_dir/$current_ver.part" "$jars_dir/$current_ver"
fi
if [ "$installed_ver" != "$current_ver" ]; then
	ln -sf "$jars_dir/$current_ver" "$jars_dir/current"
fi
if [ "$clobber" = true ]; then
	for jar in "$jars_dir"/minecraft_server.*.jar; do
		if [ -f "$jar" ] && [ ! "$jar" -ef "$jars_dir/current" ]; then
			rm "$jar"
		fi
	done
fi
