#!/bin/bash

# Exit if error
set -e
jars_dir=~mc/java_jars
syntax='Usage: mc_setup.sh INSTANCE'

args=$(getopt -l help -o h -- "$@")
eval set -- "$args"
while [ "$1" != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo 'Make new Minecraft Java Edition server in ~mc/java/INSTANCE.'
		echo
		echo 'Positional arguments:'
		echo 'INSTANCE  systemd instance name. ex: mc@MC'
		exit
		;;
	esac
done
shift

if [ "$#" -lt 1 ]; then
	>&2 echo 'Not enough arguments'
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo 'Too much arguments'
	>&2 echo "$syntax"
	exit 1
fi

instance=$1
if [ "$instance" != "$(systemd-escape -- "$instance")" ]; then
	>&2 echo 'INSTANCE should be identical to systemd-escape INSTANCE'
	exit 1
fi
server_dir=~mc/java/$instance
if [ -d "$server_dir" ]; then
	>&2 echo "Server directory $server_dir already exists"
	exit 1
fi
mcscripts_dir=$server_dir/.MCscripts

if ! command -v java &> /dev/null; then
	>&2 echo 'No command java'
	exit 1
fi

if [ -h "$jars_dir/current" ]; then
	minecraft_jar=$(realpath "$jars_dir/current")
else
	>&2 echo "No minecraft_server JAR $jars_dir/current"
	exit 1
fi
# Trim off $minecraft_jar after last .jar
current_ver=$(basename "${minecraft_jar%.jar}")

mkdir -p ~mc/java
chown mc:mc ~mc/java
trap 'rm -rf "$server_dir"' ERR
mkdir "$server_dir"
mkdir "$mcscripts_dir"
cp "$minecraft_jar" "$server_dir/server.jar"
echo "$current_ver" > "$mcscripts_dir/version"
cd "$server_dir"
# Minecraft Java Edition makes eula.txt on first run
java -jar server.jar --nogui || true
echo '#!/bin/bash' > "$mcscripts_dir/start.sh"
echo >> "$mcscripts_dir/start.sh"
echo 'java -jar server.jar --nogui' >> "$mcscripts_dir/start.sh"
chmod +x "$mcscripts_dir/start.sh"
chown -R mc:mc "$server_dir"
echo "@@@ Remember to edit $server_dir/server.properties @@@"
