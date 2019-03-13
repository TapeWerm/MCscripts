Description:
	Minecraft Java Edition and Bedrock Edition server (also known as Bedrock Dedicated Server or BDS for short) systemd units and bash scripts for backups, updates, and shutdown warnings
	Compatible with Ubuntu, Ubuntu on Windows 10 does not support systemd
	Ubuntu 18.04 Server Setup: https://gist.github.com/TapeWerm/d65ae4aeb6653b669e68b0fb25ec27f3
	You can run the scripts without enabling the systemd units
Notes:
	How to attach to the systemd service's tmux session:
		sudo su mc -s /bin/bash
		tmux -S /tmp/tmux-mc/$instance a
		Example: service mc@instance status
	You cannot enable instances of Java Edition and Bedrock Edition with the same name
	mc@example and mcbe@example
	Xbox One can only connect on LAN, Nintendo Switch cannot connect at all
	https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock
	Try https://github.com/jhead/phantom to work around this

Common setup:
	cd MCscripts
	Copy and paste goodness:
		sudo adduser --home /opt/MC --system mc
		echo set-option -g default-shell /bin/bash >> .tmux.conf
		sudo mv .tmux.conf ~mc/
		for file in `ls *.sh`; do sudo cp $file ~mc/; done
		sudo chown mc:nogroup ~mc/*
		for file in `ls systemd`; do sudo cp systemd/$file /etc/systemd/system/; done
Java Edition setup:
	sudo mv $server_dir /opt/MC/MC
	Copy and paste goodness:
		sudo chown -R mc:nogroup /opt/MC/MC
		sudo systemctl enable mc@MC.service --now
		sudo systemctl enable mc-backup@MC.timer --now
	I recommend replacing the 3rd argument to MCbackup.sh in mc-backup@.service with an external drive to dump backups on
Bedrock Edition setup:
	sudo mv $server_dir /opt/MC/MCBE
	Copy and paste goodness:
		sudo chown -R mc:nogroup /opt/MC/MCBE
		sudo systemctl enable mcbe@MCBE.service --now
		sudo systemctl enable mcbe-backup@MC.timer --now
	I recommend replacing the 3rd argument to MCBEbackup.sh in mcbe-backup@.service with an external drive to dump backups on
