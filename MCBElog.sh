#!/usr/bin/env bash

# Exit if error
set -e
syntax='Usage: MCBElog.sh [OPTION] ... SESSIONNAME'
thyme=$(date -d '1 min ago' '+%Y-%m-%d %H:%M')

send() {
	status=$(systemctl status "mcbe-bot@$sessionname" | cut -d $'\n' -f 3 | awk '{print $2}')
	if [ "$status" = active ]; then
		echo "PRIVMSG $chan :$*" >> ~/.MCBE_Bot/"${sessionname}_BotBuffer"
	fi
}

args=$(getopt -l help,tmux-socket: -o ht: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo Post Minecraft Bedrock Edition server connect/disconnect messages running in tmux session to IRC.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-t, --tmux-socket=TMUX_SOCKET  socket tmux session is on'
		exit
		;;
	--tmux-socket|-t)
		tmux_socket=$2
		shift 2
		;;
	esac
done
shift

if [ "$#" -lt 1 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 1 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

sessionname=$1
join_file=~/.MCBE_Bot/${sessionname}_BotJoin.txt
join=$(cut -d $'\n' -f 1 < "$join_file")
chans=$(echo "$join" | cut -d ' ' -f 2)
# Trim off $chans after first ,
chan=${chans%%,*}

if [ -n "$tmux_socket" ]; then
	# Remove trailing slash
	tmux_socket=${tmux_socket%/}
else
	# $USER = `whoami` and is not set in cron
	tmux_socket=/tmp/tmux-$(id -u "$(whoami)")/default
fi
if ! tmux -S "$tmux_socket" ls | grep -q "^$sessionname:"; then
	>&2 echo "No session $sessionname on socket $tmux_socket"
	exit 2
fi

scrape=$(tmux -S "$tmux_socket" capture-pane -pJt "$sessionname:0.0" -S -)
# grep fails if there's no match
buffer=$(echo "$scrape" | grep "$thyme" || true)
# Escape \ while reading line from $buffer
echo "$buffer" | while read -r line; do
	if echo "$line" | grep -q 'Player connected'; then
		player=$(echo "$line" | cut -d ' ' -f 6)
		player=${player%,}
		send "$player connected"
	elif echo "$line" | grep -q 'Player disconnected'; then
		player=$(echo "$line" | cut -d ' ' -f 6)
		player=${player%,}
		send "$player disconnected"
	fi
done
