---
description: Effort ladder — what each effort of a model buys relative to its ★ recommended effort
argument-hint: "<model, e.g. opus, sonnet-5.5, sol-6.1>"
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/run-cli.sh" effort --no-color $ARGUMENTS 2>&1`

Show the ladder above in a code block. Then explain in two sentences, in the user's language, how much ability the efforts above ★ add and how many times the cost they take. Mention 估算 when time values are estimates. Do not change the session's model or effort; if the user wants to, tell them which setting to change.
