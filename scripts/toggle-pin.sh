#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="${1%%|*}"
SESSION_NAME="${SESSION_NAME%"${SESSION_NAME##*[![:space:]]}"}"
DEBUG_MODE="${2:-off}"
DEBUG_LOG="${3:-/tmp/sessionx-debug.log}"

if [[ -z "$SESSION_NAME" ]]; then
	exit 0
fi

if [[ -n "$(tmux show-option -t "$SESSION_NAME" -qv @sessionx-pinned)" ]]; then
	tmux set-option -t "$SESSION_NAME" -u @sessionx-pinned
	state="unpinned"
else
	tmux set-option -t "$SESSION_NAME" @sessionx-pinned 1
	state="pinned"
fi

if [[ "$DEBUG_MODE" == "on" ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] TOGGLE_PIN: $state '$SESSION_NAME'" >> "$DEBUG_LOG"
fi
