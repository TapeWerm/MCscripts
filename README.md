# Description
Minecraft Java and Bedrock Dedicated Server systemd units and scripts for backups, automatic updates, and posting logs to chat bots

**[mcbe_backup.sh](mcbe_backup.sh) also works with Docker**

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd.
Try [Ubuntu Server](https://ubuntu.com/tutorials/install-ubuntu-server).
You can run [mc_getjar.sh](mc_getjar.sh), [mcbe_getzip.sh](mcbe_getzip.sh), and [mcbe_update.sh](mcbe_update.sh) without enabling the systemd units, but not others.
No automatic updates nor chat bots for Java Edition.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- [Notes](#notes)
- [Setup](#setup)
  - [Java Edition setup](#java-edition-setup)
  - [Bedrock Edition setup](#bedrock-edition-setup)
  - [Bedrock Edition webhook bots setup](#bedrock-edition-webhook-bots-setup)
  - [Override systemd unit configuration](#override-systemd-unit-configuration)
  - [Update MCscripts](#update-mcscripts)
  - [Remove MCscripts](#remove-mcscripts)
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
sudo apt install curl procps socat zip
curl -L https://github.com/TapeWerm/MCscripts/archive/refs/heads/master.zip -o /tmp/master.zip
unzip /tmp/master.zip -d /tmp
sudo /tmp/MCscripts-master/install.sh
```
If you want to change where backups are stored:
```bash
# Replace EXT_DRIVE with external drive
sudo ln -snf ~mc ~mc/backup_dir
```
## Java Edition setup
Do one of the following:
- Import server directory:
  ```bash
  # Replace SERVER_DIR with Minecraft server directory
  sudo ~mc/mc_setup.sh --import SERVER_DIR MC
  ```
- Make new server directory:
  ```bash
  sudo ~mc/mc_setup.sh MC
  ```
  Enter `sudo nano ~mc/java/MC/eula.txt`, fill it in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>).
```bash
sudo systemctl enable mc@MC.socket mc@MC.service mc-backup@MC.timer --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mc-rmbackup@MC.service --now
```
## Bedrock Edition setup
Do one of the following:
- Import server directory:
  ```bash
  # Replace SERVER_DIR with Minecraft server directory
  sudo ~mc/mcbe_setup.sh --import SERVER_DIR MCBE
  ```
- Make new server directory:
  ```bash
  sudo ~mc/mcbe_setup.sh MCBE
  ```
```bash
sudo systemctl enable mcbe@MCBE.socket mcbe@MCBE.service mcbe-backup@MCBE.timer --now
sudo systemctl enable mcbe-getzip.timer mcbe-autoupdate@MCBE.service --now
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable mcbe-rmbackup@MCBE.service --now
```
## Bedrock Edition webhook bots setup
If you want to post server logs to webhooks (Discord and Rocket Chat):
```bash
sudo mkdir ~mc/.mcbe_log
sudo touch ~mc/.mcbe_log/MCBE_webhook.txt
sudo chown -R mc:nogroup ~mc/.mcbe_log
sudo chmod 600 ~mc/.mcbe_log/MCBE_webhook.txt
```
Enter `sudo nano ~mc/.mcbe_log/MCBE_webhook.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
$url
$url
...
```
Copy and paste this block:
```bash
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
   0 3 * * * systemctl try-restart mcbe@MCBE
   ```
## Update MCscripts
```bash
sudo apt install curl procps socat zip
curl -L https://github.com/TapeWerm/MCscripts/archive/refs/heads/master.zip -o /tmp/master.zip
rm -rf /tmp/MCscripts-master
unzip /tmp/master.zip -d /tmp
sudo /tmp/MCscripts-master/install.sh --update
```
If you want to change where backups are stored:
```bash
# Replace EXT_DRIVE with external drive
sudo ln -snf ~mc ~mc/backup_dir
```
## Remove MCscripts
Server directories and backups in ~mc will remain.
```bash
sudo ~mc/disable_services.sh
```
