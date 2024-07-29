Please run modified Bash scripts through `shellcheck` before making a pull request.
Please run modified Python scripts through `pylint` and `black` before making a pull request.
Like spell checkers, code linters aren't always right, but neither are we.

You can also test modified scripts through `time` to see how runtime is affected by changes.

How to monitor CPU and memory usage of systemd service in CSV:
```bash
service=SERVICE
ps_recursive() {
local cputimes
if ! cputimes=$(ps -o cputimes --no-header "$1"); then
return 1
fi
# Trim off $cputimes before last space
cputimes=${cputimes##* }
local rss
if ! rss=$(ps -o rss --no-header "$1"); then
return 1
fi
# Trim off $rss before last space
rss=${rss##* }
local cmd
if ! cmd=$(ps -o args --no-header "$1"); then
return 1
fi
cmd=${cmd//'"'/'""'}
echo "\"$timestamp\",$1,$cputimes,$rss,\"$cmd\""
local child_pid
for child_pid in $(ps -o pid --no-header --ppid "$1"); do
ps_recursive "$child_pid" || true
done
}
sudo systemctl start --no-block "$service"
pid=$(systemctl show -p MainPID --value "$service")
{
echo 'Timestamp,PID,CPU Time,RSS,Command'
while timestamp=$(date --iso-8601=ns) && ps_recursive "$pid"; do
sleep 0.1
done
} | tee /dev/null
```
Please test modified scripts before making a pull request.
```bash
sudo tests/test_mcbe.sh
tests/test_mcbe_getzip.sh

sudo tests/test_mc.sh
tests/test_mc_getjar.sh
```
The following scripts don't have tests:
- [mc_log.py](src/mc_log.py)
- [mcbe_backup.py](src/mcbe_backup.py) --docker
- [mcbe_log.py](src/mcbe_log.py)
