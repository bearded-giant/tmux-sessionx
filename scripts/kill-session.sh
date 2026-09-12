#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Helper script for killing sessions with proper debugging
SESSION_INPUT="$1"
DEBUG_MODE="${2:-off}"
DEBUG_LOG="${3:-/tmp/sessionx-debug.log}"
CONFIRM="${4:-off}"

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

if [[ "$CONFIRM" == "on" && -t 0 ]]; then
    printf >&2 "Kill session '%s'? [y/N] " "$SESSION_NAME"
    read -r -n 1 answer
    echo >&2
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        if [[ "$DEBUG_MODE" == "on" ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: cancelled for '$SESSION_NAME'" >> "$DEBUG_LOG"
        fi
        exit 0
    fi
fi

if tmux kill-session -t "$SESSION_NAME" 2>&1; then
    forget_session_meta "$SESSION_NAME"
    if [[ "$DEBUG_MODE" == "on" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: successfully killed session '$SESSION_NAME'" >> "$DEBUG_LOG"
    fi
else
    if [[ "$DEBUG_MODE" == "on" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILL_SESSION: failed to kill session '$SESSION_NAME'" >> "$DEBUG_LOG"
    fi
fi