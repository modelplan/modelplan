# Response accounting fixtures

These are synthetic, text-free shapes of local Codex and Claude Code logs. IDs
are placeholders, not production identities. No prompt or response text is included.

Oracle: ccusage 20.0.51, upstream 58866ba681343634ab6e5add61f18f3b70aa98f7 (MIT).
From this directory, run:

```sh
CODEX_HOME="$PWD" npx --yes ccusage@20.0.51 codex daily --json --no-cost --timezone UTC
CLAUDE_CONFIG_DIR="$PWD/claude" npx --yes ccusage@20.0.51 claude daily --json --offline --timezone UTC
```

Both commands were run. Codex reports input 300, cache read 2700, cache write 0,
output 30 (including reasoning 10), total 3030. The unchanged cumulative notice
is not another response. The missing turn-complete line is deliberate: usage is
already spent, even though the timing parser cannot close the turn.

Claude reports input 300, cache read 2700, cache write 60, output 30, total 3090.
The first two streaming blocks belong to one response; the larger block wins.
