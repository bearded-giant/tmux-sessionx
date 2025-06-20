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
	# Allow alphanumeric, dash, underscore, dot
	if [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
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