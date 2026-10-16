---
description: Which engine — compare a developer's models at their ★ recommended effort (ability vs cost)
argument-hint: "[anthropic|openai|zhipuai|…]"
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/run-cli.sh" lineup --no-color --dev "$ARGUMENTS" 2>&1`

Show the output above to the user as-is in a code block. Then, in at most three sentences in the user's language:

- Say which model is 最划算 / best value and what the step to the strongest one costs (ability points vs cost multiple).
- If the user's current model (if known) carries 不如 X or ≈ X 但更贵, say that X is as strong or stronger for less.
- Do not recommend anything the output does not show. Do not change any settings.

If the output says the CLI was not found, suggest `/modelplan:setup` and stop.
