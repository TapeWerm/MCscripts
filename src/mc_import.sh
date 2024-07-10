#!/bin/bash

# Exit if error
set -e
jars_dir=~mc/java_jars
syntax='Usage: mc_import.sh [OPTION]... SERVER_DIR INSTANCE'
update=true

args=$(getopt -l help,no-update -o hn -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Import Minecraft Java Edition server to ~mc/java/INSTANCE.'
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo "-n, --no-update  don't update minecraft java edition server"
		exit
		;;
	--no-update|-n)
		update=false
		shift
		;;
	esac
done
shift

if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

import=$(realpath -- "$1")

instance=$2
if [ "$instance" != "$(systemd-escape -- "$instance")" ]; then
	>&2 echo INSTANCE should be indentical to systemd-escape INSTANCE
	exit 1
fi
server_dir=~mc/java/$instance
if [ -d "$server_dir" ]; then
	>&2 echo "Server directory $server_dir already exists"
	exit 1
fi
mcscripts_dir=$server_dir/.MCscripts

if ! command -v java &> /dev/null; then
	>&2 echo "No command java"
	exit 1
fi

if [ -h "$jars_dir/current" ]; then
	minecraft_jar=$(realpath "$jars_dir/current")
else
	>&2 echo "No minecraft_server JAR $jars_dir/current"
	exit 1
fi

mkdir -p ~mc/java
chown mc:mc ~mc/java

echo "Enter Y if you stopped the server to import"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 1
fi

trap 'rm -rf "$server_dir"' ERR
cp -r "$import" "$server_dir"
# Convert DOS line endings to UNIX line endings
for file in "$server_dir"/*.{json,properties}; do
	if [ -f "$file" ]; then
		sed -i 's/\r$//' "$file"
	fi
done
mkdir -p "$mcscripts_dir"
echo '#!/bin/bash' > "$mcscripts_dir/start.sh"
echo >> "$mcscripts_dir/start.sh"
echo java -jar server.jar --nogui >> "$mcscripts_dir/start.sh"
chmod +x "$mcscripts_dir/start.sh"
if [ "$update" = true ]; then
	cp "$minecraft_jar" "$server_dir/server.jar"
fi
chown -R mc:mc "$server_dir"
trap - ERR
rm -r "$import"
echo "@@@ Remember to edit $server_dir/server.properties @@@"
