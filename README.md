# Description
Minecraft Java Edition and Bedrock Dedicated Server systemd units, bash scripts, and chat bots for backups, automatic updates, installation, and shutdown warnings

**[mcbe_backup.sh](mcbe_backup.sh) also works with Docker**

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd.
Try [Ubuntu Server](https://ubuntu.com/tutorials/install-ubuntu-server).
You can run [mc_getjar.sh](mc_getjar.sh), [mcbe_getzip.sh](mcbe_getzip.sh), and [mcbe_update.sh](mcbe_update.sh) without enabling the systemd units, but not others.
No automatic update scripts nor chat bots for Java Edition.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- [Notes](#notes)
- [Setup](#setup)
  - [Java Edition setup](#java-edition-setup)
  - [Bedrock Edition setup](#bedrock-edition-setup)
  - [Bedrock Edition webhook bots setup](#bedrock-edition-webhook-bots-setup)
  - [Override systemd unit configuration](#override-systemd-unit-configuration)
  - [Update MCscripts](#update-mcscripts)
# Notes
How to run commands in the server console:
```bash
sudo ~mc/mc_cmd.sh SERVICE COMMAND...
# Bedrock Edition server example
sudo ~mc/mc_cmd.sh mcbe@MCBE help 2
```
How to see server output:
```bash
# Press H for help
journalctl -u SERVICE | ~mc/mc_color.sed | less -r +G
```
How to add everyone to whitelist:
```bash
whitelist=$(for x in steve alex herobrine; do echo whitelist add "$x"; done)
sudo ~mc/mc_cmd.sh SERVICE "$whitelist"
```
How to control systemd services:
```bash
# See Minecraft Bedrock Edition server status
systemctl status mcbe@MCBE
# Backup Minecraft Bedrock Edition server
sudo systemctl start mcbe-backup@MCBE
# See backup's location
journalctl -u mcbe-backup@MCBE -t mcbe_backup.sh -n 1 -o cat
# Stop Minecraft Bedrock Edition server
sudo systemctl stop mcbe@MCBE
```

Backups are in ~mc/backup_dir.
Outdated bedrock-server ZIPs in ~mc will be removed by [mcbe_getzip.sh](mcbe_getzip.sh).
[mcbe_update.sh](mcbe_update.sh) only keeps packs, worlds, JSON files, and PROPERTIES files.
Other files will be removed.

[PlayStation and Xbox can only connect on LAN with subscription, Nintendo Switch cannot connect at all.](https://help.minecraft.net/hc/en-us/articles/360035131651-Dedicated-Servers-for-Minecraft-on-Bedrock-)
Try [jhead/phantom](https://github.com/jhead/phantom) to work around this on PlayStation and Xbox.
Try [ProfessorValko's Bedrock Dedicated Server Tutorial](https://www.reddit.com/user/ProfessorValko/comments/9f438p/bedrock_dedicated_server_tutorial/).
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
sudo cp *.{sed,sh} ~mc/
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
echo chmod +x server.jar | sudo tee ~mc/java/MC/start.bat
echo java -Xms1024M -Xmx2048M -jar server.jar nogui | sudo tee -a ~mc/java/MC/start.bat
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
sudo su mc -s /bin/bash -c '~/mcbe_getzip.sh'
sudo ~mc/mcbe_autoupdate.sh ~mc/bedrock/MCBE
```
If you moved a server directory from Windows:
```bash
sudo su mc -s /bin/bash -c '~/mcbe_getzip.sh'
sudo ~mc/mcbe_update.sh ~mc/bedrock/MCBE ~mc/bedrock-server-*.zip
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
## Bedrock Edition webhook bots setup
If you want to post server logs to webhooks (Discord and Rocket Chat):
```bash
sudo su mc -s /bin/bash
mkdir -p ~/.mcbe_log
touch ~/.mcbe_log/MCBE_webhook.txt
chmod 600 ~/.mcbe_log/MCBE_webhook.txt
```
Enter `nano ~/.mcbe_log/MCBE_webhook.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
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
If you want to edit systemd units in a way that won't get overwritten when you update MCscripts, use `systemctl edit SERVICE` to override specific options.
Options that are a list, such as ExecStop, must first be reset by setting it to an empty string.

How to change mcbe@MCBE shutdown warning to 20 seconds:

1. Enter `sudo systemctl edit mcbe@MCBE`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
[Service]
ExecStop=
ExecStop=/opt/MC/mc_stop.sh -s 20 %N
```
2. If you want to revert the edit enter `sudo systemctl revert mcbe@MCBE`

Other services you might want to edit:
- [mcbe-backup@MCBE.timer](systemd/mcbe-backup@.timer) - When backups occur (check time zone with `date`)
- [mcbe-rmbackup@MCBE.service](systemd/mcbe-rmbackup@.service) - How many backups to keep
- [mcbe-getzip.service](systemd/mcbe-getzip.service) - [mcbe_getzip.sh](mcbe_getzip.sh) --no-clobber

How to restart mcbe@MCBE at 3 AM daily:

1. Enter `sudo crontab -e`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
# m h  dom mon dow   command
0 3 * * * systemctl is-active --quiet mcbe@MCBE && systemctl restart mcbe@MCBE
```
## Update MCscripts
```bash
sudo apt install curl git procps socat wget zip
cd MCscripts
git pull origin master
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s EXT_DRIVE ~mc/backup_dir
if [ ! -d ~mc/backup_dir ]; then sudo ln -s ~mc ~mc/backup_dir; fi
sudo ./disable_services.sh
sudo ./move_servers.sh
```
Copy and paste this block:
```bash
sudo cp *.{sed,sh} ~mc/
sudo chown -h mc:nogroup ~mc/*
sudo cp systemd/* /etc/systemd/system/
sudo ./enable_services.sh
```
