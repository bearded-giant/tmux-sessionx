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

# Enhanced cached_tmux_option with caching
cached_tmux_option() {
	local option="$1"
	local fallback="$2"
	
	# Check cache first
	if [[ -n "${TMUX_OPTIONS_CACHE[$option]:-}" ]]; then
		echo "${TMUX_OPTIONS_CACHE[$option]}"
		return
	fi
	
	# Get value and cache it
	local value
	value=$(tmux_option_or_fallback "$option" "$fallback")
	TMUX_OPTIONS_CACHE[$option]="$value"
	echo "$value"
}

preview_settings() {
	default_window_mode=$(cached_tmux_option "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-w"
	fi
	default_window_mode=$(cached_tmux_option "@sessionx-tree-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-t"
	fi
	preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
	preview_ratio=$(cached_tmux_option "@sessionx-preview-ratio" "75%")
	preview_enabled=$(cached_tmux_option "@sessionx-preview-enabled" "true")
}

window_settings() {
	window_height=$(cached_tmux_option "@sessionx-window-height" "75%")
	window_width=$(cached_tmux_option "@sessionx-window-width" "75%")
	layout_mode=$(cached_tmux_option "@sessionx-layout" "default")
	prompt_icon=$(cached_tmux_option "@sessionx-prompt" " ")
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

	bind_scroll_up=$(cached_tmux_option "@sessionx-bind-scroll-up" "ctrl-p")
	bind_scroll_down=$(cached_tmux_option "@sessionx-bind-scroll-down" "ctrl-d")

	bind_select_up=$(cached_tmux_option "@sessionx-bind-select-up" "ctrl-n")
	bind_select_down=$(cached_tmux_option "@sessionx-bind-select-down" "ctrl-m")

	bind_sort_asc=$(cached_tmux_option "@sessionx-bind-sort-asc" "ctrl-u")
	bind_sort_desc=$(cached_tmux_option "@sessionx-bind-sort-desc" "ctrl-d")

	bind_help=$(cached_tmux_option "@sessionx-bind-help" "ctrl-h")
}

input() {
	default_window_mode=$(cached_tmux_option "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')
	else
		filter_current_session=$(cached_tmux_option "@sessionx-filter-current" "true")
		# Get sessions sorted by activity (most recent first)
		if [[ "$filter_current_session" == "true" ]]; then
			(tmux list-sessions -F '#{session_activity}:#{session_name}' | sort -rn | cut -d: -f2 | grep -v "$CURRENT$") || echo "$CURRENT"
		else
			(tmux list-sessions -F '#{session_activity}:#{session_name}' | sort -rn | cut -d: -f2) || echo "$CURRENT"
		fi
	fi
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
	if [ -d "$*" ]; then
		target="${*//[$'\n\r']/}"
		if ! validate_path "$target"; then
			echo "Error: Invalid path" >&2
			exit 1
		fi
	elif echo "$@" | grep ':' >/dev/null 2>&1; then
		session_name="${1%%:*}"
		num="${1#*:}"
		num="${num%% *}"
		target="${session_name}:${num}"
		if ! validate_session_name "$session_name"; then
			echo "Error: Invalid session name" >&2
			exit 1
		fi
	else
		target="${*//[$'\n\r']/}"
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
		PREVIEW_LINE="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {}"
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
	WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_index}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

	NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
	# Use printf instead of echo -e for better portability and safety
	BACK="$bind_back:reload(printf '%s\n' \"${INPUT// /}\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {1})"
	KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {})+reload(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/reload_sessions.sh)"

	ACCEPT="$bind_accept:replace-query+print-query"
	DELETE="$bind_delete_char:backward-delete-char"
	EXIT="$bind_exit:abort"

	SELECT_UP="$bind_select_up:up"
	SELECT_DOWN="$bind_select_down:down"
	SCROLL_UP="$bind_scroll_up:preview-half-page-up"
	SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"

	SORT_ASC="$bind_sort_asc:reload(sort)+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"
	SORT_DESC="$bind_sort_desc:reload(sort -r)+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

	RENAME_SESSION_EXEC='bash -c '\'' printf >&2 "New name: ";read name; tmux rename-session -t {1} "${name}"; '\'''
	RENAME_SESSION_RELOAD='bash -c '\'' tmux list-sessions -F "#{session_activity}:#{session_name}" | sort -rn | cut -d: -f2; '\'''
	RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)"

	HELP="$bind_help:execute-silent(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/help.sh | less -R)"

	HEADER="Press [$bind_help] for help"

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
		--bind "$SORT_ASC"
		--bind "$SORT_DESC"
		--bind "$SCROLL_UP"
		--bind "$SCROLL_DOWN"
		--bind "$RENAME_SESSION"
		--bind "$HELP"
		--bind '?:toggle-preview'
		--bind 'change:first'
		--exit-0
		--header="$HEADER"
		--preview="${PREVIEW_LINE}"
		--preview-window="${preview_location},${preview_ratio},,"
		--layout="$layout_mode"
		--pointer=$pointer_icon
		-p "$window_width,$window_height"
		--prompt "$prompt_icon"
		--print-query
		--scrollbar '▌▐'
	)

	legacy=$(cached_tmux_option "@sessionx-legacy-fzf-support" "off")
	if [[ "${legacy}" == "off" ]]; then
		args+=(--border-label "Current session: \"$CURRENT\" ")
		args+=(--bind 'focus:transform-preview-label:echo [ {} ]')
	fi

	# Safer array assignment without eval
	IFS=' ' read -ra fzf_opts <<< "$additional_fzf_options"
}

run_plugin() {
	preview_settings
	window_settings
	handle_binds
	handle_args
	# Use printf instead of echo -e and quote array expansions
	RESULT=$(printf '%s\n' "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${fzf_opts[@]}" "${args[@]}")
}

run_plugin
handle_output "$RESULT"
