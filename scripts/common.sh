#!/usr/bin/env bash

# Common functions used across sessionx scripts

# Get tmux option or fallback to default
tmux_option_or_fallback() {
	local option="$1"
	local fallback="$2"
	local value
	value=$(tmux show-option -gqv "$option")
	if [[ -z "$value" ]]; then
		echo "$fallback"
	else
		echo "$value"
	fi
}

# Validate session name to prevent command injection
validate_session_name() {
	local name="$1"
	# Allow alphanumeric, dash, underscore, dot, and spaces
	# Disallow only dangerous characters like $, `, ;, |, &, etc.
	if [[ "$name" =~ ^[a-zA-Z0-9._[:space:]-]+$ ]]; then
		return 0
	fi
	return 1
}

# Validate path to prevent directory traversal
validate_path() {
	local path="$1"
	# Reject paths with .. or starting with -
	if [[ "$path" == *".."* ]] || [[ "$path" == -* ]]; then
		return 1
	fi
	# Check if path exists and is a directory
	if [[ -d "$path" ]]; then
		return 0
	fi
	return 1
}

# Check if a tmuxinator template exists
is_known_tmuxinator_template() {
	local template="$1"
	if ! command -v tmuxinator &>/dev/null; then
		return 1
	fi
	tmuxinator list --newline 2>/dev/null | grep -q "^${template}$"
}

# Get the tmux plugin manager path
get_tmux_plugin_manager_path() {
	local path="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.config/tmux/plugins}"
	echo "${path%/}"
}

short_key() {
	local key="$1"
	key="${key//ctrl-/C-}"
	key="${key//alt-/M-}"
	key="${key/btab/S-tab}"
	echo "$key"
}

render_session_list() {
	local current="$1" filter_current="$2" sort_order="$3" name_width="$4" pin_color="$5" pinned_only="${6:-false}"
	local session_data timestamp pinned windows alerts name label formatted_time output row
	session_data=$(tmux list-sessions -F '#{session_last_attached}|#{@sessionx-pinned}|#{session_windows}|#{session_alerts}|#{session_name}|#{@sessionx-label}' | sort $sort_order -t'|' -k1,1)

	while IFS='|' read -r _ _ _ _ name _; do
		[[ -z "$name" ]] && continue
		if (( ${#name} > name_width )); then
			name_width=${#name}
		fi
	done <<< "$session_data"

	output=$(while IFS='|' read -r timestamp pinned windows alerts name label; do
		[[ -z "$name" ]] && continue
		[[ "$filter_current" == "true" && "$name" == "$current" ]] && continue
		[[ "$pinned_only" == "true" && -z "$pinned" ]] && continue
		if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
			formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>/dev/null || echo "Unknown")
		else
			formatted_time="Unknown"
		fi
		row=$(printf "%-${name_width}s | %s | %sw" "$name" "$formatted_time" "$windows")
		if [[ -n "$alerts" ]]; then
			row+="!"
		fi
		if [[ -n "$label" ]]; then
			row+=" | $label"
		fi
		if [[ -n "$pinned" ]]; then
			printf "\033[%sm%s\033[0m\n" "$pin_color" "$row"
		else
			printf "%s\n" "$row"
		fi
	done <<< "$session_data")

	if [[ -z "$output" ]]; then
		echo "$current"
	else
		echo "$output"
	fi
}

SESSIONX_STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sessionx/sessions"

save_session_meta() {
	local name="$1" pinned label tmp
	pinned=$(tmux show-option -t "$name" -qv @sessionx-pinned 2>/dev/null || true)
	label=$(tmux show-option -t "$name" -qv @sessionx-label 2>/dev/null || true)
	mkdir -p "$(dirname "$SESSIONX_STATE_FILE")"
	touch "$SESSIONX_STATE_FILE"
	tmp=$(mktemp)
	awk -F'|' -v n="$name" '$1 != n' "$SESSIONX_STATE_FILE" > "$tmp"
	if [[ -n "$pinned$label" ]]; then
		printf '%s|%s|%s\n' "$name" "$pinned" "$label" >> "$tmp"
	fi
	mv "$tmp" "$SESSIONX_STATE_FILE"
}

forget_session_meta() {
	local name="$1" tmp
	[[ -f "$SESSIONX_STATE_FILE" ]] || return 0
	tmp=$(mktemp)
	awk -F'|' -v n="$name" '$1 != n' "$SESSIONX_STATE_FILE" > "$tmp"
	mv "$tmp" "$SESSIONX_STATE_FILE"
}

restore_session_meta() {
	[[ -f "$SESSIONX_STATE_FILE" ]] || return 0
	local name pinned label live_name live_pinned live_label
	declare -A seen live_pinned_by live_label_by
	while IFS='|' read -r live_name live_pinned live_label; do
		[[ -z "$live_name" ]] && continue
		seen[$live_name]=1
		live_pinned_by[$live_name]="$live_pinned"
		live_label_by[$live_name]="$live_label"
	done < <(tmux list-sessions -F '#{session_name}|#{@sessionx-pinned}|#{@sessionx-label}')
	while IFS='|' read -r name pinned label; do
		[[ -z "$name" || -z "${seen[$name]:-}" ]] && continue
		if [[ -n "$pinned" && -z "${live_pinned_by[$name]:-}" ]]; then
			tmux set-option -t "$name" @sessionx-pinned 1
		fi
		if [[ -n "$label" && -z "${live_label_by[$name]:-}" ]]; then
			tmux set-option -t "$name" @sessionx-label "$label"
		fi
	done < "$SESSIONX_STATE_FILE"
}
