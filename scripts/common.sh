#!/usr/bin/env bash
# Common utilities for sessionx scripts

# Get tmux option value with fallback
tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

# Validate session name for security
validate_session_name() {
	local name="$1"
	# Allow alphanumeric, dash, underscore, dot, and colon
	if [[ ! "$name" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
		return 1
	fi
	return 0
}

# Validate path for security
validate_path() {
	local path="$1"
	# Check if path contains dangerous characters
	if [[ "$path" =~ \.\. ]] || [[ "$path" =~ [*?[\]{}] ]]; then
		return 1
	fi
	# Check if path exists and is a directory
	if [[ ! -d "$path" ]]; then
		return 1
	fi
	return 0
}