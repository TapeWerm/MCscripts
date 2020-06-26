# Description
Minecraft Java Edition and Bedrock Dedicated Server (BDS for short) systemd units, bash scripts, and chat bots for backups, automatic updates, installation, and shutdown warnings

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd (Try [my Ubuntu Server 18.04 Setup](https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3)). You can run [MCgetJAR.sh](MCgetJAR.sh), [MCBEgetZIP.sh](MCBEgetZIP.sh), and [MCBEupdate.sh](MCBEupdate.sh) without enabling the systemd units, but no others. No automatic update scripts or chat bots for Java Edition.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- [Notes](#notes)
- [Setup](#setup)
  - [Java Edition setup](#java-edition-setup)
  - [Bedrock Edition setup](#bedrock-edition-setup)
  - [Bedrock Edition IRC bot setup](#bedrock-edition-irc-bot-setup)
  - [Bedrock Edition webhook bots setup](#bedrock-edition-webhook-bots-setup)
  - [Update MCscripts](#update-mcscripts)
# Notes
How to send input to and read output from the server console:
```bash
# Send input to server console
sudo su mc -s /bin/bash -c "echo $input > /run/$service"
# Read output from server console
systemctl status $service
# Bedrock Dedicated Server example
sudo su mc -s /bin/bash -c "echo save query > /run/mcbe@MCBE"
systemctl status mcbe@MCBE
```
How to add everyone to Bedrock Dedicated Server whitelist:
```bash
for x in steve alex herobrine; do sudo su mc -s /bin/bash -c "echo whitelist add $x > /run/mcbe@MCBE"; done
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
sudo apt install curl git socat wget zip
git clone https://github.com/TapeWerm/MCscripts.git
cd MCscripts
sudo adduser --home /opt/MC --system mc
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s $ext_drive ~mc/backup_dir
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
# Move server directory (Replace "$server_dir" with Minecraft server directory)
sudo mv "$server_dir" ~mc/java/MC
# Open server.jar with no GUI and 1024-2048 MB of RAM
echo java -Xms1024M -Xmx2048M -jar server.jar nogui | sudo tee ~mc/java/MC/start.bat
```
Copy and paste this block:
```bash
sudo chmod +x ~mc/java/MC/start.bat
sudo chown -R mc:nogroup ~mc/java
sudo systemctl enable mc@MC.service mc-backup@MC.timer --now
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
# Move server directory (Replace "$server_dir" with Minecraft server directory)
sudo mv "$server_dir" ~mc/bedrock/MCBE
# OR
# Make new server directory
sudo su mc -s /bin/bash -c '~/MCBEgetZIP.sh'
sudo ~mc/MCBEautoUpdate.sh ~mc/bedrock/MCBE
```
Copy and paste this block:
```bash
sudo chown -R mc:nogroup ~mc/bedrock
sudo systemctl enable mcbe@MCBE.service mcbe-backup@MCBE.timer mcbe-getzip.timer mcbe-autoupdate@MCBE.service --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mcbe-rmbackup@MCBE.service --now
```
## Bedrock Edition IRC bot setup
If you want to post connect/disconnect messages to IRC:
```bash
sudo su mc -s /bin/bash
mkdir -p ~/.MCBE_Bot
```
Enter `nano ~/.MCBE_Bot/MCBE_BotJoin.txt`, fill this in, and write out (^G = Ctrl-G):
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
sudo systemctl enable mcbe-bot@MCBE.service mcbe-bot@MCBE.timer mcbe-log@MCBE.service --now
```
## Bedrock Edition webhook bots setup
If you want to post connect/disconnect messages to webhooks (Discord and Rocket Chat):
```bash
sudo su mc -s /bin/bash
mkdir -p ~/.MCBE_Bot
```
Enter `nano ~/.MCBE_Bot/MCBE_BotWebhook.txt`, fill this in, and write out (^G = Ctrl-G):
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
## Update MCscripts
Disable the services you use and remove their files:
```bash
cd MCscripts
git pull origin master
sudo ./DisableServices.sh
```
Update the services:
```bash
sudo apt install curl git socat wget zip
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s $ext_drive ~mc/backup_dir
if [ ! -d ~mc/backup_dir ]; then sudo ln -s ~mc ~mc/backup_dir; fi
sudo ./MoveServers.sh
```
Copy and paste this block:
```bash
sudo cp *.sh ~mc/
sudo chown -h mc:nogroup ~mc/*
sudo cp systemd/* /etc/systemd/system/
```
Reenable the services you use:
```bash
sudo systemctl enable "$services" --now
```
