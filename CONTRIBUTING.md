Please run modified scripts through `shellcheck` before making a pull request. Like spell checkers, code linters aren't always right, but neither are we.

You can also test modified scripts through `time` to see how runtime is affected by changes.

```bash
# Good: echo 1 | cut -d ' ' -f 2 -s
# Bad:  echo 1 | cut -d ' ' -f 2
git grep -E 'cut.*-f ([2-9]|[1-9][0-9]+)' | grep -Ev '\-s|^CONTRIBUTING.md:'
```
