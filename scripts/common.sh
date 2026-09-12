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
	echo "$key"
}

render_session_list() {
	local current="$1" filter_current="$2" sort_order="$3" name_width="$4" pin_color="$5"
	local session_data timestamp pinned name formatted_time output
	session_data=$(tmux list-sessions -F '#{session_last_attached}|#{@sessionx-pinned}|#{session_name}' | sort $sort_order -t'|' -k1)

	while IFS='|' read -r _ _ name; do
		[[ -z "$name" ]] && continue
		if (( ${#name} > name_width )); then
			name_width=${#name}
		fi
	done <<< "$session_data"

	output=$(while IFS='|' read -r timestamp pinned name; do
		[[ -z "$name" ]] && continue
		[[ "$filter_current" == "true" && "$name" == "$current" ]] && continue
		if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
			formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>/dev/null || echo "Unknown")
		else
			formatted_time="Unknown"
		fi
		if [[ -n "$pinned" ]]; then
			printf "\033[%sm%-${name_width}s | %s\033[0m\n" "$pin_color" "$name" "$formatted_time"
		else
			printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
		fi
	done <<< "$session_data")

	if [[ -z "$output" ]]; then
		echo "$current"
	else
		echo "$output"
	fi
}
