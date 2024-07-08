# Description
Minecraft Java and Bedrock Dedicated Server systemd units and scripts for backups, automatic updates, and posting logs to chat bots

**[mcbe_backup.py](src/mcbe_backup.py) also works with Docker**

@@@ **Compatible with Ubuntu** @@@

Ubuntu on Windows Subsystem for Linux does not support systemctl poweroff.
Try [Ubuntu Server](https://ubuntu.com/tutorials/install-ubuntu-server).
You can run [mc_getjar.py](src/mc_getjar.py), [mcbe_getzip.py](src/mcbe_getzip.py), and [mcbe_update.py](src/mcbe_update.py) without enabling the systemd units, but not others.
No automatic updates nor chat bots for Java Edition.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- [Notes](#notes)
- [Setup](#setup)
  - [Java Edition setup](#java-edition-setup)
  - [Bedrock Edition setup](#bedrock-edition-setup)
  - [Bedrock Edition webhook bots setup](#bedrock-edition-webhook-bots-setup)
  - [Config files](#config-files)
  - [Override systemd unit configuration](#override-systemd-unit-configuration)
  - [Update MCscripts](#update-mcscripts)
  - [Remove MCscripts](#remove-mcscripts)
# Notes
How to run commands in the server console:
```bash
sudo /opt/MCscripts/bin/mc_cmd.py SERVICE COMMAND...
# Minecraft Bedrock Edition server example
sudo /opt/MCscripts/bin/mc_cmd.py mcbe@MCBE help 2
```
How to see server output:
```bash
# Press H for help
journalctl -u SERVICE | /opt/MCscripts/bin/mc_color.sed | less -r +G
```
How to add everyone to allowlist:
```bash
allowlist=$(for x in steve alex herobrine; do echo "allowlist add $x"; done)
sudo /opt/MCscripts/bin/mc_cmd.py SERVICE "$allowlist"
```
How to control systemd services:
```bash
# See Minecraft Bedrock Edition server status
systemctl status mcbe@MCBE
# Backup Minecraft Bedrock Edition server
sudo systemctl start mcbe-backup@MCBE
# See backup's location
journalctl _SYSTEMD_UNIT=mcbe-backup@MCBE.service -n 1 -o cat
# Check for Minecraft Bedrock Edition server updates
sudo systemctl start mcbe-getzip
# Stop Minecraft Bedrock Edition server
sudo systemctl stop mcbe@MCBE
```
How to restore backup for Minecraft Bedrock Edition server:
```bash
sudo systemctl stop mcbe@MCBE
sudo /opt/MCscripts/bin/mcbe_restore.py ~mc/bedrock/MCBE BACKUP
sudo systemctl start mcbe@MCBE
```
How to see MCscripts version:
```bash
cat /opt/MCscripts/version
```
How to see MCscripts commit hash:
```bash
unzip -z /tmp/master.zip | tail -n +2
```

Backups are in /opt/MCscripts/backup_dir.
Outdated bedrock-server ZIPs in ~mc will be removed by [mcbe_getzip.py](src/mcbe_getzip.py).
[mcbe_update.py](src/mcbe_update.py) only keeps packs, worlds, JSON files, and PROPERTIES files.
Other files will be removed.

PlayStation and Xbox can only connect on LAN with subscription, Nintendo Switch cannot connect at all.
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
Bring your own Java or `sudo apt update && sudo apt install openjdk-21-jre-headless`.
```bash
sudo systemd-run -PGqp User=mc -- /opt/MCscripts/bin/mc_getjar.py
```
Do one of the following:
- Import server directory:
  ```bash
  /opt/MCscripts/bin/mc_import.py --help
  # Replace SERVER_DIR with server directory
  sudo /opt/MCscripts/bin/mc_import.py SERVER_DIR MC
  ```
- Make new server directory:
  ```bash
  sudo /opt/MCscripts/bin/mc_setup.py MC
  ```
  Enter `sudo nano ~mc/java/MC/eula.txt`, fill it in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>).
```bash
sudo systemctl enable --now mc@MC.socket mc@MC.service mc-backup@MC.timer
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable --now mc-rmbackup@MC.service
```
## Bedrock Edition setup
```bash
sudo systemd-run -PGqp User=mc -- /opt/MCscripts/bin/mcbe_getzip.py
```
Do one of the following:
- Import server directory:
  ```bash
  /opt/MCscripts/bin/mcbe_import.py --help
  # Replace SERVER_DIR with server directory
  sudo /opt/MCscripts/bin/mcbe_import.py SERVER_DIR MCBE
  ```
- Make new server directory:
  ```bash
  sudo /opt/MCscripts/bin/mcbe_setup.py MCBE
  ```
```bash
sudo systemctl enable --now mcbe@MCBE.socket mcbe@MCBE.service mcbe-backup@MCBE.timer
sudo systemctl enable --now mcbe-getzip.timer mcbe-autoupdate@MCBE.service
```
If you want to automatically remove backups more than 2-weeks-old to save storage:
```bash
sudo systemctl enable --now mcbe-rmbackup@MCBE.service
```
## Bedrock Edition webhook bots setup
If you want to post server logs to webhooks (Discord and Rocket Chat):
```bash
sudo mkdir -p ~mc/.mcbe_log
# Rocket Chat: MCBE_rocket.txt
sudo touch ~mc/.mcbe_log/MCBE_discord.txt
sudo chmod 600 ~mc/.mcbe_log/MCBE_discord.txt
sudo chown -R mc:mc ~mc/.mcbe_log
```
Enter `sudo nano ~mc/.mcbe_log/MCBE_discord.txt`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
```
$url
$url
...
```
```bash
sudo systemctl enable --now mcbe-log@MCBE.service
```
## Config files
How to change mcbe@MCBE shutdown warning to 20 seconds:

1. ```bash
   sudo mkdir -p /etc/MCscripts/mcbe
   sudo cp /etc/MCscripts/mcbe.toml /etc/MCscripts/mcbe/MCBE.toml
   ```
2. Enter `sudo nano /etc/MCscripts/mcbe/MCBE.toml`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
   ```toml
   # Seconds before stopping.
   # 0-60
   seconds = 20
   ```

mcbe.toml configures mcbe@*.
mcbe/MCBE.toml only configures mcbe@MCBE.
mcbe/MCBE.toml overrides mcbe.toml.

MCscripts config files are [TOML format](https://toml.io/en/).
## Override systemd unit configuration
If you want to edit systemd units in a way that won't get overwritten when you update MCscripts, use `sudo systemctl edit SERVICE` to override specific options.
Options that are a list, such as ExecStart, must first be reset by setting it to an empty string.

How to change mcbe-rmbackup@MCBE to keep backups for 4 weeks:

1. Enter `sudo systemctl edit mcbe-rmbackup@MCBE`, fill this in, and write out (^G = <kbd>Ctrl</kbd>-<kbd>G</kbd>):
   ```
   [Service]
   ExecStart=
   ExecStart=/usr/bin/find /opt/MCscripts/backup_dir/bedrock_backups/%i -type f -mtime +28 -delete
   ```
2. If you want to revert the edit enter `sudo systemctl revert mcbe-rmbackup@MCBE`

Other services you might want to edit:
- [mcbe-backup@MCBE.timer](systemd/mcbe-backup@.timer) - When backups occur (check time zone with `date`)

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
sudo /opt/MCscripts/bin/disable_services.sh
sudo userdel mc
sudo groupdel mc
sudo chown -R root:root /opt/MC
sudo mv -T --backup=numbered /opt/MC /opt/MC.old
sudo mv -T --backup=numbered /opt/MCscripts /opt/MCscripts.old
sudo mv -T --backup=numbered /etc/MCscripts /etc/MCscripts.old
```
