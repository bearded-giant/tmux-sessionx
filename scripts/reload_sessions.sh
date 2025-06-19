#!/usr/bin/env bash
CURRENT_SESSION=$(tmux display-message -p '#S')
# Get sessions sorted by activity (most recent first)
SESSIONS=$(tmux list-sessions -F '#{session_activity}:#{session_name}' | sort -rn | cut -d: -f2)

if [[ $(echo "$SESSIONS" | wc -l) -gt 1 ]]; then
	echo "$SESSIONS" | grep -v "$CURRENT_SESSION"
else
	echo "$SESSIONS"
fi

