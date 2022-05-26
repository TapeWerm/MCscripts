#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: mc_getjar.sh [OPTION]...'

args=$(getopt -l help,url: -o hu: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Download the JAR of the current version of Minecraft Java Edition server.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-u, --url  server JAR URL'
		exit
		;;
	--url|-u)
		url=$2
		shift 2
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

if [ -z "$url" ]; then
	webpage_raw=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server)
	webpage=$(echo "$webpage_raw" | hxnormalize -x)
	urls=$(echo "$webpage" | hxselect -s '\n' -c 'a::attr(href)')
	url=$(echo "$urls" | grep -E 'https://[^ ]+server\.jar' | head -n 1)
fi

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

curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS "$url" -O
