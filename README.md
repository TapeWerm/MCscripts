# Description
Minecraft Java Edition and Bedrock Dedicated Server (BDS for short) systemd units and bash scripts for backups, automatic updates, installation, and shutdown warnings

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd (Try [my Ubuntu Server 18.04 Setup](https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3)). You can run the scripts without enabling the systemd units, except for [MCBEautoUpdate.sh](MCBEautoUpdate.sh). No automatic update scripts for Java Edition.
# Notes
How to attach to the systemd service's tmux session (server console):
```bash
sudo su mc -s /bin/bash
# Example: systemctl status mc@$instance
tmux -S "/tmp/tmux-mc/$instance" a
```
Press <kbd>Ctrl</kbd>-<kbd>B</kbd> then <kbd>D</kbd> to detach from a tmux session. `exit` to switch back to previous user.

Backups are in ~mc by default. `systemctl status mc-backup@MC mcbe-backup@MCBE` says the last backup's location. Outdated bedrock-server ZIPs in ~mc will be removed by [MCBEgetZIP.sh](MCBEgetZIP.sh). [MCBEupdate.sh](MCBEupdate.sh) only keeps packs, worlds, JSON files, and PROPERTIES files. Other files will be removed. You cannot enable instances of Java Edition and Bedrock Edition with the same name (mc@example and mcbe@example).

[Xbox One can only connect on LAN, Nintendo Switch cannot connect at all.](https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock) Try [jhead/phantom](https://github.com/jhead/phantom) to work around this on Xbox One. Try [ProfessorValko's Bedrock Dedicated Server Tutorial](https://www.reddit.com/user/ProfessorValko/comments/9f438p/bedrock_dedicated_server_tutorial/).
# Setup
Open Terminal:
```bash
sudo apt install git tmux wget zip
git clone https://github.com/TapeWerm/MCscripts.git
cd MCscripts
sudo adduser --home /opt/MC --system mc
# I recommend replacing the 1st argument to ln with an external drive to dump backups on
# Example: sudo ln -s $ext_drive ~mc/backup_dir
sudo ln -s ~mc ~mc/backup_dir
```
Copy and paste this block:
```bash
echo set -g default-shell /bin/bash | sudo tee ~mc/.tmux.conf
for file in $(ls *.sh); do sudo cp "$file" ~mc/; done
sudo chown -h mc:nogroup ~mc/*
for file in $(ls systemd); do sudo cp "systemd/$file" /etc/systemd/system/; done
```
## Java Edition setup
Stop the Minecraft server.
```bash
# Move server directory
sudo mv "$server_dir" ~mc/MC
# Open server.jar with no GUI and 1024-2048 MB of RAM
echo java -Xms1024M -Xmx2048M -jar server.jar nogui | sudo tee ~mc/MC/start.bat
```
Copy and paste this block:
```bash
sudo chmod 700 ~mc/MC/start.bat
sudo chown -R mc:nogroup ~mc/MC
sudo systemctl enable mc@MC.service mc-backup@MC.timer --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mc-rmbackup@MCBE.service --now
```
## Bedrock Edition setup
Stop the Minecraft server.
```bash
# Move server directory or
sudo mv "$server_dir" ~mc/MCBE
# Make new server directory
sudo su mc -s /bin/bash
~/MCBEgetZIP.sh
exit
sudo ~mc/MCBEautoUpdate.sh ~mc/MCBE
```
Copy and paste this block:
```bash
sudo chown -R mc:nogroup ~mc/MCBE
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
mkdir ~/.MCBE_Bot
```
Enter `nano ~/.MCBE_Bot/MCBE_BotJoin.txt`, fill this in, and write out (^G = Ctrl-G):
```
JOIN #chan,#chan $key,$key
irc.domain.tld:$port
```
Copy and paste this block:
```bash
exit
sudo systemctl enable mcbe-bot@MCBE.service mcbe-log@MCBE.timer --now
```
