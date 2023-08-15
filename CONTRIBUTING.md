Please run modified Bash scripts through `shellcheck` before making a pull request.
Please run modified Python scripts through `pylint` and `black` before making a pull request.
Like spell checkers, code linters aren't always right, but neither are we.

You can also test modified scripts through `time` to see how runtime is affected by changes.

How to monitor CPU and memory usage of systemd service:
```bash
service=SERVICE
ps_recursive() {
if ! ps -o pid,cputimes,rss,args --no-header "$1"; then
false
else
for child_pid in $(ps -o pid --no-header --ppid "$1"); do
ps_recursive "$child_pid"
done
fi
}
sudo true
sudo systemctl start "$service" &
while pid=$(systemctl show -p MainPID --value -- "$service") && [ "$pid" = 0 ]; do
sleep 0.1
done
echo pid cputimes rss args
while ps_recursive "$pid"; do
sleep 0.1
done
```
Please test modified scripts before making a pull request.
```bash
sudo tests/test_mcbe.sh
tests/test_mcbe_getzip.sh

sudo tests/test_mc.sh
tests/test_mc_getjar.sh
```
The following scripts don't have tests:
- [mcbe_backup.py](src/mcbe_backup.py) --docker
- [mcbe_log.py](src/mcbe_log.py)
