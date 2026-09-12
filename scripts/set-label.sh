#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

SESSION_NAME="${1%%|*}"
SESSION_NAME="${SESSION_NAME%"${SESSION_NAME##*[![:space:]]}"}"
DEBUG_MODE="${2:-off}"
DEBUG_LOG="${3:-/tmp/sessionx-debug.log}"

if [[ -z "$SESSION_NAME" ]]; then
	exit 0
fi

current=$(tmux show-option -t "$SESSION_NAME" -qv @sessionx-label)
printf >&2 "Label for '%s': " "$SESSION_NAME"
read -r -e -i "$current" label
label="${label//[$'\n\r']/}"

if [[ -z "$label" ]]; then
	tmux set-option -t "$SESSION_NAME" -u @sessionx-label
else
	tmux set-option -t "$SESSION_NAME" @sessionx-label "$label"
fi

if [[ "$DEBUG_MODE" == "on" ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] SET_LABEL: '$SESSION_NAME' -> '$label'" >> "$DEBUG_LOG"
fi
