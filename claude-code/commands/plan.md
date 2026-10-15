---
description: Plan your model, effort and fast mode around your remaining quota and reset times
argument-hint: "[what you are about to do]"
allowed-tools: Bash(modelplan:*)
---

Your quota, read on this machine (from the Model Plan status line's last snapshot):

!`modelplan quota --no-color 2>&1`

What Model Plan would flag now (step up before a reset, step down, switch back after one, peak hours, cards):

!`modelplan advise --no-color 2>&1`

Your current model's effort ladder:

!`modelplan effort --no-color --offline 2>&1`

The user is about to: $ARGUMENTS

Use the model-plan Skill's rules to answer in the user's language, in at most five lines:

1. What to use now: model and effort (and whether fast mode makes sense), with the step-up multipliers from the ladder (ability +N points, cost ×R against the step below).
2. Why, starting from the flagged hints above and the Claude Code account's `headroom` and the deciding window: surplus before a reset means unused allowance is lost, so stepping up is cheap; conserve means stay at ★ or step down; exhausted means wait for the reset (say how long).
3. When to switch back (after the reset, or once the window turns tight).

If the quota shows no Claude Code account, say the status line has not recorded anything yet and suggest `/modelplan:statusline`; give the ladder advice without quota. Do not change any setting yourself; tell the user which command changes it (`/model`, `/effort`, `/fast`).
