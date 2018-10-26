You must restart the server after backup in Bedrock Edition
https://bugs.mojang.com/browse/BDS-198
Xbox One can only connect on LAN, Nintendo Switch cannot connect at all
https://help.mojang.com/customer/en/portal/articles/2954250-dedicated-servers-for-minecraft-on-bedrock

Common setup:
sudo adduser --home /opt/MC mc

Copy and paste goodness:
chmod 700 MCstop.sh MCbackup.sh MCBEbackup.sh
sudo chown mc:mc MCstop.sh MCbackup.sh MCBEbackup.sh
sudo mv mc@.service /etc/systemd/service/
sudo mv mcbe@.service /etc/systemd/service/

Java Edition setup:
sudo systemctl enable mc@MC.service --now
Enter `crontab -u mc -e` and add this to mc's crontab:
0 4 * * * ~/MCbackup.sh MC MC > /dev/null

Pass a 3rd argument to MCbackup.sh for an external drive to dump backups on

Bedrock Edition setup:
sudo systemctl enable mcbe@MCBE.service --now
Enter `crontab -u mc -e` and add this to mc's crontab:
0 4 * * * ~/MCBEbackup.sh MCBE MCBE > /dev/null

Pass a 3rd argument to MCBEbackup.sh for an external drive to dump backups on
