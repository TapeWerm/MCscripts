#!/usr/bin/env bash

# Exit if error
set -e
clobber=true
preview=false
syntax='Usage: mcbe_getzip.sh [OPTION]...'

args=$(getopt -l help,no-clobber,preview -o hnp -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo "If the ZIP of the current version of Minecraft Bedrock Edition server isn't in ~, download it, and remove outdated ZIPs in ~."
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo "-n, --no-clobber  don't remove outdated ZIPs in ~"
		echo "-p, --preview     download preview instead of the current version"
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

webpage_raw=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server/bedrock)
webpage=$(echo "$webpage_raw" | hxnormalize -x)
urls=$(echo "$webpage" | hxselect -s '\n' -c 'a::attr(href)')
if [ "$preview" = false ]; then
	url=$(echo "$urls" | grep -E 'https://[^ ]+bin-linux/bedrock-server-[^ ]+\.zip' | head -n 1)
else
	url=$(echo "$urls" | grep -E 'https://[^ ]+bin-linux-preview/bedrock-server-[^ ]+\.zip' | head -n 1)
fi
current_ver=$(basename "$url")
# ls fails if there's no match
installed_ver=$(ls ~/bedrock-server-*.zip 2> /dev/null || true)

# There might be more than one ZIP in ~
if ! echo "$installed_ver" | grep -q "$current_ver"; then
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

	curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS "$url" -o ~/"$current_ver".part
	trap '' SIGTERM
	mv ~/"$current_ver".part ~/"$current_ver"
	if [ "$clobber" = true ]; then
		echo "$installed_ver" | xargs -d '\n' rm -f
	fi
fi
