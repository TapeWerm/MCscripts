# Description
Minecraft Java Edition and Bedrock Dedicated Server (BDS for short) systemd units and bash scripts for backups, automatic updates, installation, and shutdown warnings

Compatible with Ubuntu, Ubuntu on Windows 10 does not support systemd ([Ubuntu Server 18.04 Setup](https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3)). You can run the scripts without enabling the systemd units, except for [MCBEgetZIP.sh](MCBEgetZIP.sh) and [MCBEautoUpdate.sh](MCBEautoUpdate.sh). No automatic update/install scripts for Java Edition.
# Notes
How to attach to the systemd service's tmux session (server console):
```bash
sudo su mc -s /bin/bash
tmux -S /tmp/tmux-mc/$instance a
# Example: service mc@instance status
```
Press Ctrl-B then D to detach from a tmux session.

Backups are in ~mc by default. Outdated bedrock-server ZIPs in ~mc will be removed by [MCBEgetZIP.sh](MCBEgetZIP.sh). [MCBEupdate.sh](MCBEupdate.sh) only keeps packs, worlds, whitelist, permissions, and properties. Other files will be removed. You cannot enable instances of Java Edition and Bedrock Edition with the same name (mc@example and mcbe@example).

[Xbox One can only connect on LAN, Nintendo Switch cannot connect at all.](https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock) Try [jhead/phantom](https://github.com/jhead/phantom) to work around this on Xbox One. Try [ProfessorValko's Bedrock Dedicated Server Tutorial](https://www.reddit.com/user/ProfessorValko/comments/9f438p/bedrock_dedicated_server_tutorial/).
# Common setup
Open Terminal:
```bash
sudo apt install git tmux wget zip
git clone https://github.com/TapeWerm/MCscripts.git
cd MCscripts
```
Copy and paste this block:
```bash
sudo adduser --home /opt/MC --system mc
echo set -g default-shell /bin/bash | sudo tee ~mc/.tmux.conf
for file in `ls *.sh`; do sudo cp $file ~mc/; done
sudo chown mc:nogroup ~mc/*
for file in `ls systemd`; do sudo cp systemd/$file /etc/systemd/system/; done
```
# Java Edition setup
I recommend replacing RequiresMountsFor and the 3rd argument to MCbackup.sh in [/etc/systemd/system/mc-backup@.service](systemd/mc-backup@.service) with an external drive to dump backups on. Stop the Minecraft server.
```bash
sudo mv $server_dir ~mc/MC
echo java -Xms1024M -Xmx2048M -jar server.jar nogui | sudo tee ~mc/MC/start.bat
# Open server.jar with no GUI and 1024-2048 MB of RAM
```
Copy and paste this block:
```bash
sudo chmod 700 ~mc/MC/start.bat
sudo chown -R mc:nogroup ~mc/MC
sudo systemctl enable mc@MC.service --now
sudo systemctl enable mc-backup@MC.timer --now
```
# Bedrock Edition setup
I recommend replacing RequiresMountsFor and the 3rd argument to MCBEbackup.sh in [/etc/systemd/system/mcbe-backup@.service](systemd/mcbe-backup@.service) with an external drive to dump backups on. Stop the Minecraft server.
```bash
sudo mv $server_dir ~mc/MCBE
# Move $server_dir or
sudo ~mc/MCBEgetZIP.sh
sudo ~mc/MCBEautoUpdate.sh ~mc/MCBE
# Make new server directory
```
Copy and paste this block:
```bash
sudo chown -R mc:nogroup ~mc/MCBE
sudo systemctl enable mcbe@MCBE.service --now
sudo systemctl enable mcbe-backup@MCBE.timer --now
sudo systemctl enable mcbe-getzip.timer --now
sudo systemctl enable mcbe-autoupdate@MCBE.service --now
```
