# Description
Minecraft Java Edition and Bedrock Dedicated Server (BDS for short) systemd units, bash scripts, and chat bots for backups, automatic updates, installation, and shutdown warnings

**[MCBEbackup.sh](MCBEbackup.sh) also works with Docker**

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd (Try [my Ubuntu Server 18.04 Setup](https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3)). You can run [MCgetJAR.sh](MCgetJAR.sh), [MCBEgetZIP.sh](MCBEgetZIP.sh), and [MCBEupdate.sh](MCBEupdate.sh) without enabling the systemd units, but not others. No automatic update scripts nor chat bots for Java Edition.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- [Notes](#notes)
- [Setup](#setup)
  - [Java Edition setup](#java-edition-setup)
  - [Bedrock Edition setup](#bedrock-edition-setup)
  - [Bedrock Edition IRC bot setup](#bedrock-edition-irc-bot-setup)
  - [Bedrock Edition webhook bots setup](#bedrock-edition-webhook-bots-setup)
  - [Override systemd unit configuration](#override-systemd-unit-configuration)
  - [Update MCscripts](#update-mcscripts)
# Notes
How to run commands in the server console:
```bash
sudo ~mc/MCrunCmd.sh SERVICE COMMAND...
# Bedrock Dedicated Server example
sudo ~mc/MCrunCmd.sh mcbe@MCBE help 2
```
How to see server output (Press <kbd>H</kbd> for help):
```bash
journalctl -eu SERVICE | ~mc/MCcolor.sed
```
How to add everyone to whitelist:
```bash
whitelist=$(for x in steve alex herobrine; do echo whitelist add "$x"; done)
sudo ~mc/MCrunCmd.sh SERVICE "$whitelist"
```
How to control systemd services:
```bash
# Backup Minecraft Bedrock Edition server
sudo systemctl start mcbe-backup@MCBE
# Stop Minecraft Bedrock Edition server
sudo systemctl stop mcbe@MCBE
```

Backups are in ~mc by default. `systemctl status mc-backup@MC mcbe-backup@MCBE` says the last backup's location. Outdated bedrock-server ZIPs in ~mc will be removed by [MCBEgetZIP.sh](MCBEgetZIP.sh). [MCBEupdate.sh](MCBEupdate.sh) only keeps packs, worlds, JSON files, and PROPERTIES files. Other files will be removed.

[PS4 and Xbox One can only connect on LAN, Nintendo Switch cannot connect at all.](https://help.minecraft.net/hc/en-us/articles/360035131651-Dedicated-Servers-for-Minecraft-on-Bedrock-) Try [jhead/phantom](https://github.com/jhead/phantom) to work around this on PS4 and Xbox One. Try [ProfessorValko's Bedrock Dedicated Server Tutorial](https://www.reddit.com/user/ProfessorValko/comments/9f438p/bedrock_dedicated_server_tutorial/).
# Setup
Open Terminal:
```bash
sudo apt install curl git procps socat wget zip
git clone https://github.com/TapeWerm/MCscripts.git
cd MCscripts
sudo adduser --home /opt/MC --system mc
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s EXT_DRIVE ~mc/backup_dir
sudo ln -s ~mc ~mc/backup_dir
```
Copy and paste this block:
```bash
sudo cp *.sh ~mc/
sudo chown -h mc:nogroup ~mc/*
sudo cp systemd/* /etc/systemd/system/
```
## Java Edition setup
Stop the Minecraft server.
```bash
sudo mkdir ~mc/java
# Move server directory (Replace SERVER_DIR with Minecraft server directory)
sudo mv SERVER_DIR ~mc/java/MC
# Open server.jar with no GUI and 1024-2048 MB of RAM
echo java -Xms1024M -Xmx2048M -jar server.jar nogui | sudo tee ~mc/java/MC/start.bat
```
Copy and paste this block:
```bash
sudo chmod +x ~mc/java/MC/start.bat
sudo chown -R mc:nogroup ~mc/java
sudo systemctl enable mc@MC.socket mc@MC.service mc-backup@MC.timer --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mc-rmbackup@MC.service --now
```
## Bedrock Edition setup
Stop the Minecraft server.
```bash
sudo mkdir ~mc/bedrock

# Do one of the following:
# Move server directory (Replace SERVER_DIR with Minecraft server directory)
sudo mv SERVER_DIR ~mc/bedrock/MCBE
# OR
# Make new server directory
sudo su mc -s /bin/bash -c '~/MCBEgetZIP.sh'
sudo ~mc/MCBEautoUpdate.sh ~mc/bedrock/MCBE
```
If you moved a server directory from Windows:
```bash
sudo su mc -s /bin/bash -c '~/MCBEgetZIP.sh'
sudo ~mc/MCBEupdate.sh ~mc/bedrock/MCBE ~mc/bedrock-server-*.zip
# Convert DOS line endings to UNIX line endings
for file in ~mc/bedrock/MCBE/*.{json,properties}; do sudo sed -i s/$'\r'$// "$file"; done
```
Copy and paste this block:
```bash
sudo chown -R mc:nogroup ~mc/bedrock
sudo systemctl enable mcbe@MCBE.socket mcbe@MCBE.service mcbe-backup@MCBE.timer mcbe-getzip.timer mcbe-autoupdate@MCBE.service --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mcbe-rmbackup@MCBE.service --now
```
## Bedrock Edition IRC bot setup
If you want to post server logs to IRC:
```bash
sudo su mc -s /bin/bash
mkdir -p ~/.MCBE_Bot
touch ~/.MCBE_Bot/MCBE_BotJoin.txt
chmod 600 ~/.MCBE_Bot/MCBE_BotJoin.txt
```
Enter `nano ~/.MCBE_Bot/MCBE_BotJoin.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
NICK $nick
JOIN #chan $key
PRIVMSG #chan :$msg
...
irc.domain.tld:$port
```
If NICK line is missing it defaults to MCBE_Bot. PRIVMSG lines are optional and can be used before JOIN to identify with NickServ.

Copy and paste this block:
```bash
exit
sudo systemctl enable mcbe-bot@MCBE.service mcbe-log@MCBE.service --now
```
## Bedrock Edition webhook bots setup
If you want to post server logs to webhooks (Discord and Rocket Chat):
```bash
sudo su mc -s /bin/bash
mkdir -p ~/.MCBE_Bot
touch ~/.MCBE_Bot/MCBE_BotWebhook.txt
chmod 600 ~/.MCBE_Bot/MCBE_BotWebhook.txt
```
Enter `nano ~/.MCBE_Bot/MCBE_BotWebhook.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
$url
$url
...
```
Copy and paste this block:
```bash
exit
sudo systemctl enable mcbe-log@MCBE.service --now
```
## Override systemd unit configuration
If you want to edit systemd units in a way that won't get overwritten when you update MCscripts, use `systemctl edit SERVICE` to override specific options. Options that are a list, such as ExecStop, must first be reset by setting it to an empty string.

How to change mcbe@MCBE shutdown warning to 20 seconds:

Enter `sudo systemctl edit mcbe@MCBE`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
[Service]
ExecStop=
ExecStop=/opt/MC/MCstop.sh -s 20 %N
```
Other services you might want to edit:
- [mcbe-backup@MCBE.timer](systemd/mcbe-backup@.timer) - When backups occur (check time zone with `date`)
- [mcbe-rmbackup@MCBE.service](systemd/mcbe-rmbackup@.service) - How many backups to keep
- [mcbe-getzip.service](systemd/mcbe-getzip.service) - [MCBEgetZIP.sh](MCBEgetZIP.sh) --no-clobber

How to restart mcbe@MCBE at 3 AM daily:

Enter `sudo crontab -e`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
# m h  dom mon dow   command
0 3 * * * systemctl is-active --quiet mcbe@MCBE && systemctl restart mcbe@MCBE
```
## Update MCscripts
Disable the services you use and remove their files:
```bash
cd MCscripts
git pull origin master
sudo ./DisableServices.sh
```
Update the services:
```bash
sudo apt install curl git procps socat wget zip
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s EXT_DRIVE ~mc/backup_dir
if [ ! -d ~mc/backup_dir ]; then sudo ln -s ~mc ~mc/backup_dir; fi
sudo ./MoveServers.sh
```
Copy and paste this block:
```bash
sudo cp *.{sed,sh} ~mc/
sudo chown -h mc:nogroup ~mc/*
sudo cp systemd/* /etc/systemd/system/
```
Reenable the services you use:
```bash
sudo systemctl enable SERVICES --now
```
