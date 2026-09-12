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

printf >&2 "New name: "
read -r -e -i "$SESSION_NAME" new_name
new_name="${new_name#"${new_name%%[![:space:]]*}"}"
new_name="${new_name%"${new_name##*[![:space:]]}"}"

if [[ -z "$new_name" || "$new_name" == "$SESSION_NAME" ]]; then
	exit 0
fi
if ! validate_session_name "$new_name"; then
	echo >&2 "Invalid session name: '$new_name'"
	sleep 1
	exit 1
fi

tmux rename-session -t "$SESSION_NAME" "$new_name"
forget_session_meta "$SESSION_NAME"
save_session_meta "$new_name"

if [[ "$DEBUG_MODE" == "on" ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] RENAME_SESSION: '$SESSION_NAME' -> '$new_name'" >> "$DEBUG_LOG"
fi
