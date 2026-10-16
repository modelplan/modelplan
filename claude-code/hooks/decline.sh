#!/bin/sh
# /modelplan:setup's "not now": decline.sh cli|statusline keeps the hook quiet about it for 90 days.
case $1 in cli|statusline) ;; *) echo "usage: decline.sh cli|statusline"; exit 1;; esac
mkdir -p "$HOME/.cache/modelplan-claude-code" && : > "$HOME/.cache/modelplan-claude-code/$1-declined" && echo "recorded: $1 declined for 90 days"
