Minecraft Java Edition and Bedrock Edition server systemd services and scripts for backups and shutdown warning
You must restart the server after backup in Bedrock Edition
https://bugs.mojang.com/browse/BDS-198
Xbox One can only connect on LAN, Nintendo Switch cannot connect at all
https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock

Common setup
	sudo adduser --home /opt/MC mc
	Copy and paste goodness:
		chmod 700 MCstop.sh MCbackup.sh MCBEbackup.sh
		sudo chown mc:mc MCstop.sh MCbackup.sh MCBEbackup.sh
		sudo mv MCstop.sh /opt/MC/
		sudo mv MCbackup.sh /opt/MC/
		sudo mv MCBEbackup.sh /opt/MC/
		sudo mv mc@.service /etc/systemd/system/
		sudo mv mcbe@.service /etc/systemd/system/

Java Edition setup
	Copy and paste goodness:
		sudo mv $server_dir /opt/MC/MC
		sudo chown -R mc:mc /opt/MC/MC
		sudo systemctl enable mc@MC.service --now
	Enter `sudo crontab -u mc -e` and add this to mc's crontab:
		0 4 * * * ~/MCbackup.sh ~/MC MC ~ /tmp/MC > /dev/null 2>&1
	I recommend replacing the 3rd argument to MCbackup.sh with an external drive to dump backups on

Bedrock Edition setup
	Copy and paste goodness:
		sudo mv $server_dir /opt/MC/MCBE
		sudo chown -R mc:mc /opt/MC/MCBE
		sudo systemctl enable mcbe@MCBE.service --now
	Enter `sudo crontab -u mc -e` and add this to mc's crontab:
		3 4 * * * ~/MCBEbackup.sh ~/MCBE MCBE ~ /tmp/MCBE > /dev/null 2>&1
	Enter `sudo crontab -e` and add this to root's crontab:
		30 4 * * * sudo service mcbe@MCBE restart > /dev/null 2>&1
	WARNING: level-name cannot contain ,
	I recommend replacing the 3rd argument to MCBEbackup.sh with an external drive to dump backups on
