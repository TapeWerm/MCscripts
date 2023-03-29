# Description
Minecraft Java and Bedrock Dedicated Server systemd units and scripts for backups, automatic updates, and posting logs to chat bots

**[mcbe_backup.sh](src/mcbe_backup.sh) also works with Docker**

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows 10 does not support systemd.
Try [Ubuntu Server](https://ubuntu.com/tutorials/install-ubuntu-server).
You can run [mc_getjar.sh](src/mc_getjar.sh), [mcbe_getzip.sh](src/mcbe_getzip.sh), and [mcbe_update.sh](src/mcbe_update.sh) without enabling the systemd units, but not others.
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
sudo /opt/MCscripts/mc_cmd.sh SERVICE COMMAND...
# Minecraft Bedrock Edition server example
sudo /opt/MCscripts/mc_cmd.sh mcbe@MCBE help 2
```
How to see server output:
```bash
# Press H for help
journalctl -u SERVICE | /opt/MCscripts/mc_color.sed | less -r +G
```
How to add everyone to allowlist:
```bash
allowlist=$(for x in steve alex herobrine; do echo allowlist add "$x"; done)
sudo /opt/MCscripts/mc_cmd.sh SERVICE "$allowlist"
```
How to control systemd services:
```bash
# See Minecraft Bedrock Edition server status
systemctl status mcbe@MCBE
# Backup Minecraft Bedrock Edition server
sudo systemctl start mcbe-backup@MCBE
# See backup's location
journalctl -u mcbe-backup@MCBE -t mcbe_backup.sh -n 1 -o cat
# Check for Minecraft Bedrock Edition server updates
sudo systemctl start mcbe-getzip
# Stop Minecraft Bedrock Edition server
sudo systemctl stop mcbe@MCBE
```
How to restore backup for Minecraft Bedrock Edition server:
```bash
sudo systemctl stop mcbe@MCBE
sudo /opt/MCscripts/mcbe_restore.sh ~mc/bedrock/MCBE BACKUP
sudo systemctl start mcbe@MCBE
```
How to see MCscripts commit hash:
```bash
unzip -z /tmp/master.zip | tail -n +2
```

Backups are in /opt/MCscripts/backup_dir.
Outdated bedrock-server ZIPs in ~mc will be removed by [mcbe_getzip.sh](src/mcbe_getzip.sh).
[mcbe_update.sh](src/mcbe_update.sh) only keeps packs, worlds, JSON files, and PROPERTIES files.
Other files will be removed.

[PlayStation and Xbox can only connect on LAN with subscription, Nintendo Switch cannot connect at all.](https://help.minecraft.net/hc/en-us/articles/4408873961869-Minecraft-Dedicated-and-Featured-Servers-FAQ-)
Try [ProfessorValko's Bedrock Dedicated Server Tutorial](https://www.reddit.com/user/ProfessorValko/comments/9f438p/bedrock_dedicated_server_tutorial/).
# Setup
Open Terminal:
```bash
curl -L https://github.com/TapeWerm/MCscripts/archive/refs/heads/master.zip -o /tmp/master.zip
unzip /tmp/master.zip -d /tmp
sudo /tmp/MCscripts-master/src/install.sh
```
If you want to change where backups are stored:
```bash
# Replace EXT_DRIVE with external drive
sudo ln -snf EXT_DRIVE /opt/MCscripts/backup_dir
```
## Java Edition setup
Bring your own Java or `sudo apt update && sudo apt install openjdk-17-jre-headless`.

Do one of the following:
- Import server directory:
  ```bash
  # Replace SERVER_DIR with Minecraft server directory
  sudo /opt/MCscripts/mc_setup.sh --import SERVER_DIR MC
  ```
- Make new server directory:
  ```bash
  sudo /opt/MCscripts/mc_setup.sh MC
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
  sudo /opt/MCscripts/mcbe_setup.sh --import SERVER_DIR MCBE
  ```
- Make new server directory:
  ```bash
  sudo /opt/MCscripts/mcbe_setup.sh MCBE
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
sudo mkdir -p ~mc/.mcbe_log
sudo touch ~mc/.mcbe_log/MCBE_webhook.txt
sudo chmod 600 ~mc/.mcbe_log/MCBE_webhook.txt
sudo chown -R mc:nogroup ~mc/.mcbe_log
```
Enter `sudo nano ~mc/.mcbe_log/MCBE_webhook.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
$url
$url
...
```
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
   ExecStop=/opt/MCscripts/mc_stop.sh -s 20 %N
   ```
2. If you want to revert the edit enter `sudo systemctl revert mcbe@MCBE`

Other services you might want to edit:
- [mcbe-backup@MCBE.timer](systemd/mcbe-backup@.timer) - When backups occur (check time zone with `date`)
- [mcbe-rmbackup@MCBE.service](systemd/mcbe-rmbackup@.service) - How many backups to keep
- [mcbe-getzip.service](systemd/mcbe-getzip.service) - [mcbe_getzip.sh](src/mcbe_getzip.sh) --no-clobber --both
- [mcbe-autoupdate@MCBE.service](systemd/mcbe-autoupdate@.service) - [mcbe_autoupdate.sh](src/mcbe_autoupdate.sh) --preview

How to restart mcbe@MCBE at 3 AM daily:

1. Enter `sudo crontab -e`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
   ```
   # m h  dom mon dow   command
   0 3 * * * systemctl try-restart mcbe@MCBE
   ```
## Update MCscripts
```bash
curl -L https://github.com/TapeWerm/MCscripts/archive/refs/heads/master.zip -o /tmp/master.zip
rm -rf /tmp/MCscripts-master
unzip /tmp/master.zip -d /tmp
sudo /tmp/MCscripts-master/src/install.sh
```
If you want to change where backups are stored:
```bash
# Replace EXT_DRIVE with external drive
sudo ln -snf EXT_DRIVE /opt/MCscripts/backup_dir
```
## Remove MCscripts
```bash
sudo /opt/MCscripts/disable_services.sh
sudo deluser --system mc
sudo chown -R root:root /opt/MC
sudo mv -T --backup=numbered /opt/MC /opt/MC.old
sudo mv -T --backup=numbered /opt/MCscripts /opt/MCscripts.old
```
