#!/usr/bin/env bash
set -euo pipefail

# Helper script for killing sessions with proper debugging
SESSION_INPUT="$1"
DEBUG_MODE="${2:-off}"
DEBUG_LOG="${3:-/tmp/sessionx-debug.log}"

if [[ "$DEBUG_MODE" == "on" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: input='$SESSION_INPUT'" >> "$DEBUG_LOG"
fi

# Extract session name from delimiter format
SESSION_NAME=$(echo "$SESSION_INPUT" | cut -d"|" -f1)
# Trim trailing spaces
SESSION_NAME=$(echo "$SESSION_NAME" | sed 's/[[:space:]]*$//')

if [[ "$DEBUG_MODE" == "on" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: extracted session='$SESSION_NAME'" >> "$DEBUG_LOG"
fi

# Kill the session
if tmux kill-session -t "$SESSION_NAME" 2>&1; then
    if [[ "$DEBUG_MODE" == "on" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: successfully killed session '$SESSION_NAME'" >> "$DEBUG_LOG"
    fi
else
    if [[ "$DEBUG_MODE" == "on" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: failed to kill session '$SESSION_NAME'" >> "$DEBUG_LOG"
    fi
fi