#!/usr/bin/env bash
set -euo pipefail

# Validate required commands
for cmd in tmux fzf; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed" >&2
        exit 1
    fi
done

# Get current session with error handling
if ! CURRENT="$(tmux display-message -p '#S' 2>/dev/null)"; then
    echo "Error: Not in a tmux session" >&2
    exit 1
fi

Z_MODE="off"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/tmuxinator.sh"

# Cache for tmux options to avoid repeated calls
declare -A TMUX_OPTIONS_CACHE

# Batch load all tmux options at once
load_tmux_options() {
	local options=(
		"@sessionx-window-mode:off"
		"@sessionx-tree-mode:off"
		"@sessionx-preview-location:top"
		"@sessionx-preview-ratio:75%"
		"@sessionx-preview-enabled:true"
		"@sessionx-list-pane-width:35%"
		"@sessionx-window-height:75%"
		"@sessionx-window-width:75%"
		"@sessionx-sort:default"
		"@sessionx-prompt: "
		"@sessionx-pointer:▶"
		"@sessionx-bind-tmuxinator-list:ctrl-/"
		"@sessionx-bind-tree-mode:ctrl-t"
		"@sessionx-bind-window-mode:ctrl-w"
		"@sessionx-bind-configuration-path:ctrl-x"
		"@sessionx-bind-rename-session:ctrl-r"
		"@sessionx-additional-options:--color pointer:9,spinner:92,marker:46"
		"@sessionx-bind-back:ctrl-b"
		"@sessionx-bind-new-window:ctrl-e"
		"@sessionx-bind-kill-session:alt-bspace"
		"@sessionx-bind-abort:esc"
		"@sessionx-bind-accept:enter"
		"@sessionx-bind-delete-char:bspace"
		"@sessionx-bind-scroll-up:ctrl-p"
		"@sessionx-bind-scroll-down:ctrl-d"
		"@sessionx-enable-preview-scroll:true"
		"@sessionx-bind-select-up:ctrl-n"
		"@sessionx-bind-select-down:ctrl-m"
		"@sessionx-bind-sort-asc:ctrl-u"
		"@sessionx-bind-sort-desc:ctrl-d"
		"@sessionx-bind-help:ctrl-h"
		"@sessionx-filter-current:true"
		"@sessionx-custom-paths:"
		"@sessionx-zoxide-mode:off"
		"@sessionx-x-path:$HOME/.config"
		"@sessionx-legacy-fzf-support:off"
	)
	
	# Get all options that start with @sessionx in one call
	local all_options
	all_options=$(tmux show-options -gq | grep '^@sessionx' || true)
	
	# Parse and cache the results
	while IFS= read -r line; do
		if [[ -n "$line" ]] && [[ "$line" =~ ^(@[^[:space:]]+)[[:space:]](.*)$ ]]; then
			local key="${BASH_REMATCH[1]}"
			local value="${BASH_REMATCH[2]}"
			TMUX_OPTIONS_CACHE["$key"]="$value"
		fi
	done <<< "$all_options"
	
	# Set defaults for any missing options
	for opt in "${options[@]}"; do
		local key="${opt%%:*}"
		local default="${opt#*:}"
		if [[ -z "${TMUX_OPTIONS_CACHE[$key]:-}" ]]; then
			TMUX_OPTIONS_CACHE["$key"]="$default"
		fi
	done
}

# Enhanced cached_tmux_option with caching
cached_tmux_option() {
	local option="$1"
	local fallback="$2"
	local value="${TMUX_OPTIONS_CACHE[$option]:-$fallback}"
	
	# Strip surrounding quotes if present
	value="${value#\"}"
	value="${value%\"}"
	
	echo "$value"
}

preview_settings() {
	PREVIEW_OPTIONS=""
	default_window_mode=$(cached_tmux_option "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-w"
	fi
	default_window_mode=$(cached_tmux_option "@sessionx-tree-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-t"
	fi
	preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
	# Handle left as top since left preview is awkward
	if [[ "$preview_location" == "left" ]]; then
		preview_location="top"
	fi
	preview_ratio=$(cached_tmux_option "@sessionx-preview-ratio" "75%")
	preview_enabled=$(cached_tmux_option "@sessionx-preview-enabled" "true")
	list_pane_width=$(cached_tmux_option "@sessionx-list-pane-width" "35%")
}

window_settings() {
	window_height=$(cached_tmux_option "@sessionx-window-height" "75%")
	window_width=$(cached_tmux_option "@sessionx-window-width" "75%")
	sort_mode=$(cached_tmux_option "@sessionx-sort" "default")
	prompt_icon=$(cached_tmux_option "@sessionx-prompt" " ")
	# For fzf --layout, use the sort mode value (they are the same)
	layout_mode="$sort_mode"
	pointer_icon=$(cached_tmux_option "@sessionx-pointer" "▶")
}

handle_binds() {
	bind_tmuxinator_list=$(cached_tmux_option "@sessionx-bind-tmuxinator-list" "ctrl-/")
	bind_tree_mode=$(cached_tmux_option "@sessionx-bind-tree-mode" "ctrl-t")
	bind_window_mode=$(cached_tmux_option "@sessionx-bind-window-mode" "ctrl-w")
	bind_configuration_mode=$(cached_tmux_option "@sessionx-bind-configuration-path" "ctrl-x")
	bind_rename_session=$(cached_tmux_option "@sessionx-bind-rename-session" "ctrl-r")
	additional_fzf_options=$(cached_tmux_option "@sessionx-additional-options" "--color pointer:9,spinner:92,marker:46")

	bind_back=$(cached_tmux_option "@sessionx-bind-back" "ctrl-b")
	bind_new_window=$(cached_tmux_option "@sessionx-bind-new-window" "ctrl-e")
	bind_kill_session=$(cached_tmux_option "@sessionx-bind-kill-session" "alt-bspace")

	bind_exit=$(cached_tmux_option "@sessionx-bind-abort" "esc")
	bind_accept=$(cached_tmux_option "@sessionx-bind-accept" "enter")
	bind_delete_char=$(cached_tmux_option "@sessionx-bind-delete-char" "bspace")

	enable_preview_scroll=$(cached_tmux_option "@sessionx-enable-preview-scroll" "true")
	if [[ "$enable_preview_scroll" == "true" ]]; then
		bind_scroll_up=$(cached_tmux_option "@sessionx-bind-scroll-up" "ctrl-p")
		bind_scroll_down=$(cached_tmux_option "@sessionx-bind-scroll-down" "ctrl-d")
	fi

	bind_select_up=$(cached_tmux_option "@sessionx-bind-select-up" "ctrl-n")
	bind_select_down=$(cached_tmux_option "@sessionx-bind-select-down" "ctrl-m")

	# Changed from ctrl-u/ctrl-d to avoid conflicts with scroll bindings
	bind_sort_asc=$(cached_tmux_option "@sessionx-bind-sort-asc" "ctrl-s")
	bind_sort_desc=$(cached_tmux_option "@sessionx-bind-sort-desc" "ctrl-a")

	bind_help=$(cached_tmux_option "@sessionx-bind-help" "alt-h")
}

input() {
	default_window_mode=$(cached_tmux_option "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		# Include window index for uniqueness but format for better searching
		(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')
	else
		filter_current_session=$(cached_tmux_option "@sessionx-filter-current" "true")
		# Get sort mode to determine sort order
		sort_mode=$(cached_tmux_option "@sessionx-sort" "default")
		
		# With reverse sort, we need descending sort to show newest first visually
		# With default sort, we need ascending sort to show newest first visually
		if [[ "$sort_mode" == "reverse" ]]; then
			sort_order="-rn"
		else
			sort_order="-n"
		fi
		
		# Adjust column width based on preview location
		preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
		if [[ "$preview_location" == "left" ]]; then
			preview_location="top"
		fi
		if [[ "$preview_location" == "right" ]]; then
			# Narrower columns when preview is on the right
			name_width=20
		else
			# Wider columns when preview is on top/bottom
			name_width=30
		fi
		
		if [[ "$filter_current_session" == "true" ]]; then
			(tmux list-sessions -F '#{session_last_attached}|#{session_name}' | sort $sort_order -t'|' -k1 | while IFS='|' read -r timestamp name; do
				if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then
					formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
				else
					formatted_time="Unknown"
				fi
				# Use fixed width for alignment with a unique delimiter
				printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
			done | grep -v "^$CURRENT ") || echo "$CURRENT"
		else
			(tmux list-sessions -F '#{session_last_attached}|#{session_name}' | sort $sort_order -t'|' -k1 | while IFS='|' read -r timestamp name; do
				if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then
					formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
				else
					formatted_time="Unknown"
				fi
				# Use fixed width for alignment with a unique delimiter
				printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
			done) || echo "$CURRENT"
		fi
	fi
}

# Handle input for pre-built args mode
handle_input() {
	INPUT=$(input)
	ADDITIONAL_INPUT=$(additional_input)
	if [[ -n $ADDITIONAL_INPUT ]]; then
		ADDITIONAL=$(additional_input)
	if [[ -n "$ADDITIONAL" ]]; then
		INPUT="${ADDITIONAL}
${INPUT}"
	fi
	fi
	# Fix the BACK binding to use the INPUT properly
	BACK="ctrl-b:reload(printf '%s\n' \"$INPUT\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {1})"
}

additional_input() {
	sessions=$(tmux list-sessions -F '#{session_name}')
	custom_paths=$(cached_tmux_option "@sessionx-custom-paths" "")
	if [[ -z "$custom_paths" ]]; then
		echo ""
	else
		clean_paths=$(echo "$custom_paths" | sed -E 's/ *, */,/g' | sed -E 's/^ *//' | sed -E 's/ *$//' | sed -E 's/ /✗/g')
		IFS=',' read -ra paths_arr <<< "$clean_paths"
		for i in "${paths_arr[@]}"; do
			if [[ "$sessions" == *"${i##*/}"* ]]; then
				continue
			fi
			echo "$i"
		done
	fi
}

handle_output() {
	local raw_output="$*"
	if [ -d "$raw_output" ]; then
		target="${raw_output//[$'\n\r']/}"
		if ! validate_path "$target"; then
			echo "Error: Invalid path" >&2
			exit 1
		fi
	elif echo "$raw_output" | grep ':' >/dev/null 2>&1; then
		session_name="${raw_output%%:*}"
		session_name="${session_name%% *}"
		num="${raw_output#*:}"
		num="${num%% *}"
		target="${session_name}:${num}"
		if ! validate_session_name "$session_name"; then
			echo "Error: Invalid session name" >&2
			exit 1
		fi
	else
		# Extract session name from delimiter format
		# Remove everything after " | " delimiter
		target="${raw_output%% | *}"
		# Trim trailing spaces from fixed-width formatting
		target="$(echo "$target" | sed 's/[[:space:]]*$//')"
		target="${target//[$'\n\r']/}"
		if ! validate_session_name "$target"; then
			echo "Error: Invalid session name" >&2
			exit 1
		fi
	fi

	if [[ -z "$target" ]]; then
		exit 0
	fi

	if ! tmux has-session -t="$target" 2>/dev/null; then
		if is_known_tmuxinator_template "$target"; then
			tmuxinator start "$target"
		elif test -d "$target"; then
			local session_name="${target##*/}"
			if ! validate_session_name "$session_name"; then
				echo "Error: Invalid session name derived from path" >&2
				exit 1
			fi
			tmux new-session -ds "$session_name" -c "$target"
			target="$session_name"
		else
			if [[ "$Z_MODE" == "on" ]] && command -v zoxide &>/dev/null; then
				if z_target=$(zoxide query "$target" 2>/dev/null); then
					if ! validate_session_name "$target"; then
						echo "Error: Invalid session name" >&2
						exit 1
					fi
					tmux new-session -ds "$target" -c "$z_target" -n "$z_target"
				else
					tmux new-session -ds "$target"
				fi
			else
				tmux new-session -ds "$target"
			fi
		fi
	fi
	tmux switch-client -t "$target"
}

handle_args() {
	INPUT=$(input)
	ADDITIONAL_INPUT=$(additional_input)
	if [[ -n $ADDITIONAL_INPUT ]]; then
		ADDITIONAL=$(additional_input)
	if [[ -n "$ADDITIONAL" ]]; then
		INPUT="${ADDITIONAL}
${INPUT}"
	fi
	fi
	if [[ "$preview_enabled" == "true" ]]; then
		PREVIEW_LINE="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {1}"
	else
		PREVIEW_LINE=""
	fi
	Z_MODE=$(cached_tmux_option "@sessionx-zoxide-mode" "off")
	CONFIGURATION_PATH=$(cached_tmux_option "@sessionx-x-path" "$HOME/.config")

	TMUXINATOR_MODE="$bind_tmuxinator_list:reload(tmuxinator list | sed '1d')+change-preview(cat ~/.config/tmuxinator/{}.yml 2>/dev/null)"
	TREE_MODE="$bind_tree_mode:change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -t {1})"
	# Validate CONFIGURATION_PATH to prevent command injection
	if [[ ! -d "$CONFIGURATION_PATH" ]]; then
		CONFIGURATION_PATH="$HOME/.config"
	fi
	CONFIGURATION_MODE="$bind_configuration_mode:reload(find '$CONFIGURATION_PATH' -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
	WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

	NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
	# Use printf instead of echo -e for better portability and safety
	BACK="$bind_back:reload(printf '%s\n' \"$INPUT\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {1})"
	KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {})+reload(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/reload_sessions.sh)"

	ACCEPT="$bind_accept:replace-query+print-query"
	DELETE="$bind_delete_char:backward-delete-char"
	EXIT="$bind_exit:abort"

	SELECT_UP="$bind_select_up:up"
	SELECT_DOWN="$bind_select_down:down"
	if [[ "$enable_preview_scroll" == "true" ]]; then
		SCROLL_UP="$bind_scroll_up:preview-half-page-up"
		SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"
	else
		SCROLL_UP=""
		SCROLL_DOWN=""
	fi

	# Disable sort commands for now - they're complex and conflict with other bindings
	SORT_ASC=""
	SORT_DESC=""

	RENAME_SESSION_EXEC='bash -c '\'' printf >&2 "New name: ";read name; tmux rename-session -t {1} "${name}"; '\'''
	# Get sort mode and column width for proper sorting in rename reload
	if [[ "$sort_mode" == "reverse" ]]; then
		sort_order_rename="-rn"
	else
		sort_order_rename="-n"
	fi
	# Get preview location for column width
	preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
	if [[ "$preview_location" == "left" ]]; then
		preview_location="top"
	fi
	if [[ "$preview_location" == "right" ]]; then
		name_width_rename=20
	else
		name_width_rename=30
	fi
	RENAME_SESSION_RELOAD='bash -c '\'' tmux list-sessions -F "#{session_last_attached}|#{session_name}" | sort '"$sort_order_rename"' -t"|" -k1 | while IFS="|" read -r timestamp name; do if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown"); else formatted_time="Unknown"; fi; printf "%-'"$name_width_rename"'s | %s\\n" "$name" "$formatted_time"; done; '\'''
	RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)"

	HELP="$bind_help:change-preview(${SCRIPT_DIR}/help.sh)"

	# Simplified header with only core functions
	HEADER="[$bind_kill_session]kill [$bind_rename_session]rename [$bind_window_mode]windows [$bind_tree_mode]tree [$bind_help]help"

	args=(
		--bind "$TMUXINATOR_MODE"
		--bind "$TREE_MODE"
		--bind "$CONFIGURATION_MODE"
		--bind "$WINDOWS_MODE"
		--bind "$NEW_WINDOW"
		--bind "$BACK"
		--bind "$KILL_SESSION"
		--bind "$DELETE"
		--bind "$EXIT"
		--bind "$SELECT_UP"
		--bind "$SELECT_DOWN"
		--bind "$ACCEPT"
		--bind "$RENAME_SESSION"
		--bind "$HELP"
		--bind '?:toggle-preview'
		--bind 'change:first'
		--exit-0
		--layout="$layout_mode"
		--pointer=$pointer_icon
		-p "$window_width,$window_height"
		--prompt "$prompt_icon"
		--print-query
		--scrollbar '▌▐'
		--delimiter ' | '
	)
	
	if [[ "$preview_enabled" == "true" ]]; then
		args+=(--preview "${PREVIEW_LINE}")
		# For right preview, calculate the preview ratio based on list pane width
		if [[ "$preview_location" == "right" ]]; then
			# Convert list pane width to preview ratio (inverse)
			# If list is 35%, preview should be 65%
			list_width_num="${list_pane_width%\%}"
			preview_width=$((100 - list_width_num))
			args+=(--preview-window "${preview_location},${preview_width}%,,")
		else
			args+=(--preview-window "${preview_location},${preview_ratio},,")
		fi
		args+=(--preview-label "$HEADER")
	fi

	legacy=$(cached_tmux_option "@sessionx-legacy-fzf-support" "off")
	if [[ "$enable_preview_scroll" == "true" ]] && [[ -n "$SCROLL_UP" ]] && [[ -n "$SCROLL_DOWN" ]]; then
		args+=(--bind "$SCROLL_UP")
		args+=(--bind "$SCROLL_DOWN")
	fi
	
	if [[ "${legacy}" == "off" ]]; then
		args+=(--border-label "Current session: \"$CURRENT\" ")
	fi

	# Parse additional fzf options properly
	fzf_opts=()
	if [[ -n "$additional_fzf_options" ]]; then
		# Use eval to properly parse the options string into an array
		eval "fzf_opts=($additional_fzf_options)"
	fi
}

run_plugin() {
	load_tmux_options
	preview_settings
	window_settings
	handle_binds
	handle_args
	
	# Use printf instead of echo -e and quote array expansions
	if [[ -n "${fzf_opts[*]:-}" ]]; then
		RESULT=$(printf '%s\n' "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${fzf_opts[@]}" "${args[@]}")
	else
		RESULT=$(printf '%s\n' "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${args[@]}")
	fi
	return $?
}

run_plugin
exit_code=$?

# Exit code 130 means user cancelled (Ctrl-C or ESC)
if [[ $exit_code -eq 130 ]]; then
	exit 0
fi

# Exit code 1 typically means fzf error or no selection made
if [[ $exit_code -eq 1 ]]; then
	exit 0
fi

# Exit code 2 means actual error
if [[ $exit_code -eq 2 ]]; then
	exit 1
fi

handle_output "$RESULT"
