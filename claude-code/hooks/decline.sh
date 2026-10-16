#!/bin/sh
# /modelplan:setup's "not now" for the status line: the hook stays quiet about it for 90 days.
case $1 in statusline) ;; *) echo "usage: decline.sh statusline"; exit 1;; esac
mkdir -p "$HOME/.cache/modelplan-claude-code" && : > "$HOME/.cache/modelplan-claude-code/$1-declined" && echo "recorded: $1 declined for 90 days"
