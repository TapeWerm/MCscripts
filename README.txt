Description:
	Minecraft Java Edition and Bedrock Edition server (also known as Bedrock Dedicated Server or BDS for short) systemd units and scripts for backups, updates, and shutdown warnings
	su mc; tmux -S /tmp/$instance a
	# Attach to the systemd service's tmux session
	service mc@instance status
Notes:
	You can run the scripts without enabling the systemd units
	You cannot enable instances of Java Edition and Bedrock Edition with the same name
	mc@example and mcbe@example
	Have different level-names between instances or backups will get overwritten
	Xbox One can only connect on LAN, Nintendo Switch cannot connect at all
	https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock
	Try https://github.com/jhead/phantom to work around this
	Ubuntu 18.04 Server Setup: https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3

Common setup:
	sudo adduser --home /opt/MC mc
	Copy and paste goodness:
		chmod 700 MCstop.sh MCbackup.sh MCBEbackup.sh MCBEupdate.sh
		sudo chown mc:mc MCstop.sh MCbackup.sh MCBEbackup.sh MCBEupdate.sh
		sudo mv MCstop.sh /opt/MC/
		sudo mv MCbackup.sh /opt/MC/
		sudo mv MCBEbackup.sh /opt/MC/
		sudo mv MCBEupdate.sh /opt/MC/
		sudo mv mc@.service /etc/systemd/system/
		sudo mv mcbe@.service /etc/systemd/system/
Java Edition setup:
	Copy and paste goodness:
		sudo mv $server_dir /opt/MC/MC
		sudo chown -R mc:mc /opt/MC/MC
		sudo systemctl enable mc@MC.service --now
	Enter `sudo crontab -u mc -e` and add this to mc's crontab:
		0 4 * * * ~/MCbackup.sh ~/MC MC ~ /tmp/MC > /dev/null
	I recommend replacing the 3rd argument to MCbackup.sh with an external drive to dump backups on
Bedrock Edition setup:
	Copy and paste goodness:
		sudo mv $server_dir /opt/MC/MCBE
		sudo chown -R mc:mc /opt/MC/MCBE
		sudo systemctl enable mcbe@MCBE.service --now
	Enter `sudo crontab -u mc -e` and add this to mc's crontab:
		3 4 * * * ~/MCBEbackup.sh ~/MCBE MCBE ~ /tmp/MCBE > /dev/null
	I recommend replacing the 3rd argument to MCBEbackup.sh with an external drive to dump backups on
