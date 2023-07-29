#!/usr/bin/env bash

# Exit if error
set -e
both=false
clobber=true
preview=false
syntax='Usage: mcbe_getzip.sh [OPTION]...'
zips_dir=~/bedrock_zips

args=$(getopt -l both,help,no-clobber,preview -o bhnp -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--both|-b)
		both=true
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo "If the ZIP of the current version of Minecraft Bedrock Edition server isn't in ~, download it, and remove outdated ZIPs in ~."
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --both        download current and preview versions'
		echo "-n, --no-clobber  don't remove outdated ZIPs in ~"
		echo '-p, --preview     download preview instead of the current version'
		exit
		;;
	--no-clobber|-n)
		clobber=false
		shift
		;;
	--preview|-p)
		preview=true
		shift
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

if [ "$both" = true ] && [ "$preview" = true ]; then
	>&2 echo both and preview are mutually exclusive
	exit 1
elif [ "$both" = true ]; then
	versions=(current preview)
elif [ "$preview" = true ]; then
	versions=(preview)
else
	versions=(current)
fi

mkdir -p "$zips_dir"

webpage_raw=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server/bedrock)
webpage=$(echo "$webpage_raw" | hxnormalize -x)
urls=$(echo "$webpage" | hxselect -s '\n' -c 'a::attr(href)')

echo Enter Y if you agree to the Minecraft End User License Agreement and Privacy Policy
# Does prompting the EULA seem so official that it violates the EULA?
echo Minecraft End User License Agreement: https://minecraft.net/terms
echo Privacy Policy: https://go.microsoft.com/fwlink/?LinkId=521839
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi
for version in "${versions[@]}"; do
	case $version in
	current)
		url=$(echo "$urls" | grep -E '^https://[^ ]+bin-linux/bedrock-server-[^ ]+\.zip$' | head -n 1)
		;;
	preview)
		url=$(echo "$urls" | grep -E '^https://[^ ]+bin-linux-preview/bedrock-server-[^ ]+\.zip$' | head -n 1)
		;;
	*)
		continue
		;;
	esac
	current_ver=$(basename "$url")
	# Symlink to current/preview zip
	if [ -h "$zips_dir/$version" ]; then
		installed_ver=$(basename "$(realpath "$zips_dir/$version")")
	fi

	if [ ! -f "$zips_dir/$current_ver" ]; then
		curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS "$url" -o "$zips_dir/$current_ver.part"
		mv "$zips_dir/$current_ver.part" "$zips_dir/$current_ver"
	fi
	if [ "$installed_ver" != "$current_ver" ]; then
		ln -sf "$zips_dir/$current_ver" "$zips_dir/$version"
	fi
done
if [ "$clobber" = true ]; then
	for zip in "$zips_dir"/bedrock-server-*.zip; do
		if [ -f "$zip" ] && [ ! "$zip" -ef "$zips_dir/current" ] && [ ! "$zip" -ef "$zips_dir/preview" ]; then
			rm "$zip"
		fi
	done
fi
