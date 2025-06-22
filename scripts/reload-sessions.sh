#!/usr/bin/env bash
set -euo pipefail

# Simple reload script that outputs the session list in the expected format
CURRENT="${1:-$(tmux display-message -p '#S' 2>/dev/null)}"

# Get filter setting
filter_current=$(tmux show-option -gqv "@sessionx-filter-current" || echo "true")

# Get sort mode
sort_mode=$(tmux show-option -gqv "@sessionx-sort" || echo "default")
if [[ "$sort_mode" == "reverse" ]]; then
    sort_order="-rn"
else
    sort_order="-n"
fi

# Get preview location for column width
preview_location=$(tmux show-option -gqv "@sessionx-preview-location" || echo "top")
if [[ "$preview_location" == "right" ]]; then
    name_width=20
else
    name_width=30
fi

# Generate session list
if [[ "$filter_current" == "true" ]]; then
    (tmux list-sessions -F '#{session_last_attached}|#{session_name}' | sort $sort_order -t'|' -k1 | while IFS='|' read -r timestamp name; do
        if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then
            formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
        else
            formatted_time="Unknown"
        fi
        printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
    done | grep -v "^$CURRENT ") || echo "$CURRENT"
else
    tmux list-sessions -F '#{session_last_attached}|#{session_name}' | sort $sort_order -t'|' -k1 | while IFS='|' read -r timestamp name; do
        if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then
            formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
        else
            formatted_time="Unknown"
        fi
        printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
    done
fi