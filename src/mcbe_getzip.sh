#!/bin/bash

# Exit if error
set -e
clobber=true
args_clobber=false
args_no_clobber=false
config_file=/etc/MCscripts/mcbe-getzip.toml
syntax='Usage: mcbe_getzip.sh [OPTION]...'
versions=(current preview)
args_both=false
args_current=false
args_preview=false
zips_dir=~/bedrock_zips

args=$(getopt -l both,clobber,current,help,no-clobber,preview -o bchnp -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--both|-b)
		args_both=true
		shift
		;;
	--clobber)
		args_clobber=true
		shift
		;;
	--current|-c)
		args_current=true
		shift
		;;
	--help|-h)
		echo "$syntax"
		echo "If the ZIP of the current version of Minecraft Bedrock Edition server isn't in ~, download it, and remove outdated ZIPs in ~."
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-b, --both        download current and preview versions (default)'
		echo '-c, --current     download current version'
		echo '--clobber         remove outdated ZIPs in ~ (default)'
		echo "-n, --no-clobber  don't remove outdated ZIPs in ~"
		echo '-p, --preview     download preview version'
		exit
		;;
	--no-clobber|-n)
		args_no_clobber=true
		shift
		;;
	--preview|-p)
		args_preview=true
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

if [ "$(echo "$args_clobber $args_no_clobber" | grep -o true | wc -l)" -gt 1 ]; then
	>&2 echo clobber and no-clobber are mutually exclusive
	exit 1
fi
if [ "$(echo "$args_both $args_current $args_preview" | grep -o true | wc -l)" -gt 1 ]; then
	>&2 echo both, current, and preview are mutually exclusive
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
	if [ "$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print("versions" in CONFIG)' "$config_file")" = True ]; then
		config_versions=$(python3 -c 'import sys; import toml; CONFIG = toml.load(sys.argv[1]); print(CONFIG["versions"])' "$config_file")
		if [ "$config_versions" = both ]; then
			versions=(current preview)
		elif [ "$config_versions" = current ]; then
			versions=(current)
		elif [ "$config_versions" = preview ]; then
			versions=(preview)
		else
			>&2 echo "No versions $config_versions, check $config_file"
			exit 1
		fi
	fi
fi

if [ "$args_clobber" = true ]; then
	clobber=true
elif [ "$args_no_clobber" = true ]; then
	clobber=false
fi

if [ "$args_both" = true ]; then
	versions=(current preview)
elif [ "$args_current" = true ]; then
	versions=(current)
elif [ "$args_preview" = true ]; then
	versions=(preview)
fi

mkdir -p "$zips_dir"

webpage_raw=$(curl -A 'Mozilla/5.0 (X11; Linux x86_64)' -H 'Accept-Language: en-US' --compressed -LsS https://www.minecraft.net/en-us/download/server/bedrock)
webpage=$(echo "$webpage_raw" | hxnormalize -x)
urls=$(echo "$webpage" | hxselect -s '\n' -c 'a::attr(href)')

echo Enter Y if you agree to the Minecraft End User License Agreement and Privacy Policy
# Does prompting the EULA seem so official that it violates the EULA?
echo Minecraft End User License Agreement: https://minecraft.net/eula
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
