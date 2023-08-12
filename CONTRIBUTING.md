Please run modified Bash scripts through `shellcheck` before making a pull request.
Please run modified Python scripts through `pylint` and `black` before making a pull request.
Like spell checkers, code linters aren't always right, but neither are we.

You can also test modified scripts through `time` to see how runtime is affected by changes.
```bash
sudo true
sudo systemctl start SERVICE &
until [ "$(systemctl show -p MainPID --value SERVICE)" != 0 ]
do sleep 0.1
done
while ps -o pcpu,rss --no-header "$(systemctl show -p MainPID --value SERVICE)"
do sleep 0.1
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
