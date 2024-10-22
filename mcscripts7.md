Breaking changes that may or may not happen...
# Hierarchy
| MCscripts 6.2 | MCscripts 7.0 |
| - | - |
| ~mc/bedrock | /opt/mcscripts/mcbe_servers |
| /opt/MCscripts/backup_dir/bedrock_backups | /opt/mcscripts/backup_dir/mcbe_backups |
| ~mc/bedrock_zips | /opt/mcscripts/mcbe_zips |
| ~mc/.mcbe_log | /etc/mcscripts/mcbe_log |
* [mcbe_getzip.py](src/mcbe_getzip.py) downloads in the working directory instead of homedir.
* Remove mc homedir.
* Move install scripts to install directory.
* Disable [mcbe@.socket](systemd/mcbe@.socket).
# Rename everything
| MCscripts 6.2 | MCscripts 7.0 |
| - | - |
| mcbe@ | mcscripts-mcbe-server@ |
| mcbe-backup@ | mcscripts-mcbe-backup@ |
| ... | ... |
| mc@ | mcscripts-mcje-server@ |
| mc-backup@ | mcscripts-mcje-backup@ |
| ... | ... |
| mc_stop.py | mc_stop.py |
| mc_backup.py | mcje_backup.py |
| ... | ... |
* Rename user mc to mcscripts.
* Symlink old systemd units.
