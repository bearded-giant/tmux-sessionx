#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CURRENT="${1:-$(tmux display-message -p '#S' 2>/dev/null)}"
filter_current=$(tmux_option_or_fallback "@sessionx-filter-current" "true")
sort_mode=$(tmux_option_or_fallback "@sessionx-sort" "default")
preview_location=$(tmux_option_or_fallback "@sessionx-preview-location" "top")
pin_color=$(tmux_option_or_fallback "@sessionx-pin-color" "1;33")
claude_status=$(tmux_option_or_fallback "@sessionx-claude-status" "on")
pinned_only="false"
if [[ "${2:-}" == "pinned" ]]; then
    pinned_only="true"
fi

if [[ "$sort_mode" == "reverse" ]]; then
    sort_order="-rn"
else
    sort_order="-n"
fi

if [[ "$preview_location" == "right" || "$preview_location" == "left" ]]; then
    name_width=20
else
    name_width=30
fi

render_session_list "$CURRENT" "$filter_current" "$sort_order" "$name_width" "$pin_color" "$pinned_only" "$claude_status"
