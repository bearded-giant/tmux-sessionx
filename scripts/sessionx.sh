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

declare -A TMUX_OPTIONS_CACHE

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
		"@sessionx-bind-panes-mode:ctrl-o"
		"@sessionx-bind-window-mode:ctrl-w"
		"@sessionx-bind-configuration-path:ctrl-x"
		"@sessionx-bind-rename-session:ctrl-r"
		"@sessionx-additional-options:--color pointer:9,spinner:92,marker:46"
		"@sessionx-bind-back:ctrl-b"
		"@sessionx-bind-new-window:ctrl-e"
		"@sessionx-bind-kill-session:alt-d"
		"@sessionx-bind-abort:esc"
		"@sessionx-bind-accept:enter"
		"@sessionx-bind-delete-char:bspace"
		"@sessionx-bind-scroll-up:ctrl-u"
		"@sessionx-bind-scroll-down:ctrl-d"
		"@sessionx-enable-preview-scroll:true"
		"@sessionx-bind-select-up:ctrl-n"
		"@sessionx-bind-select-down:ctrl-m"
		"@sessionx-bind-help:?"
		"@sessionx-bind-toggle-preview:ctrl-p"
		"@sessionx-bind-pin:tab"
		"@sessionx-pin-color:1;33"
		"@sessionx-filter-current:true"
		"@sessionx-custom-paths:"
		"@sessionx-zoxide-mode:off"
		"@sessionx-x-path:$HOME/.config"
		"@sessionx-legacy-fzf-support:off"
		"@sessionx-debug:off"
	)
	
	local all_options
	all_options=$(tmux show-options -gq | grep '^@sessionx' || true)
	
	while IFS= read -r line; do
		if [[ -n "$line" ]] && [[ "$line" =~ ^(@[^[:space:]]+)[[:space:]](.*)$ ]]; then
			local key="${BASH_REMATCH[1]}"
			local value="${BASH_REMATCH[2]}"
			TMUX_OPTIONS_CACHE["$key"]="$value"
		fi
	done <<< "$all_options"
	
	for opt in "${options[@]}"; do
		local key="${opt%%:*}"
		local default="${opt#*:}"
		if [[ -z "${TMUX_OPTIONS_CACHE[$key]:-}" ]]; then
			TMUX_OPTIONS_CACHE["$key"]="$default"
		fi
	done
}

cached_tmux_option() {
	local option="$1"
	local fallback="$2"
	local value="${TMUX_OPTIONS_CACHE[$option]:-$fallback}"
	
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
	if [[ "$preview_location" == "left" ]]; then
		preview_location="right"
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
	layout_mode="$sort_mode"
	pointer_icon=$(cached_tmux_option "@sessionx-pointer" "▶")
}

handle_binds() {
	bind_tmuxinator_list=$(cached_tmux_option "@sessionx-bind-tmuxinator-list" "ctrl-/")
	bind_tree_mode=$(cached_tmux_option "@sessionx-bind-tree-mode" "ctrl-t")
	bind_panes_mode=$(cached_tmux_option "@sessionx-bind-panes-mode" "ctrl-o")
	bind_window_mode=$(cached_tmux_option "@sessionx-bind-window-mode" "ctrl-w")
	bind_configuration_mode=$(cached_tmux_option "@sessionx-bind-configuration-path" "ctrl-x")
	bind_rename_session=$(cached_tmux_option "@sessionx-bind-rename-session" "ctrl-r")
	bind_new_session=$(cached_tmux_option "@sessionx-bind-new-session" "ctrl-s")
	additional_fzf_options=$(cached_tmux_option "@sessionx-additional-options" "--color pointer:9,spinner:92,marker:46")

	bind_back=$(cached_tmux_option "@sessionx-bind-back" "ctrl-b")
	bind_new_window=$(cached_tmux_option "@sessionx-bind-new-window" "ctrl-e")
	bind_kill_session=$(cached_tmux_option "@sessionx-bind-kill-session" "alt-d")

	bind_exit=$(cached_tmux_option "@sessionx-bind-abort" "esc")
	bind_accept=$(cached_tmux_option "@sessionx-bind-accept" "enter")
	bind_delete_char=$(cached_tmux_option "@sessionx-bind-delete-char" "bspace")

	enable_preview_scroll=$(cached_tmux_option "@sessionx-enable-preview-scroll" "true")
	if [[ "$enable_preview_scroll" == "true" ]]; then
		bind_scroll_up=$(cached_tmux_option "@sessionx-bind-scroll-up" "ctrl-u")
		bind_scroll_down=$(cached_tmux_option "@sessionx-bind-scroll-down" "ctrl-d")
	fi

	bind_select_up=$(cached_tmux_option "@sessionx-bind-select-up" "ctrl-n")
	bind_select_down=$(cached_tmux_option "@sessionx-bind-select-down" "ctrl-m")

	bind_help=$(cached_tmux_option "@sessionx-bind-help" "?")
	bind_toggle_preview=$(cached_tmux_option "@sessionx-bind-toggle-preview" "ctrl-p")
	bind_pin=$(cached_tmux_option "@sessionx-bind-pin" "tab")
	
	debug_log "Key bindings configured:"
	debug_log "  kill-session: $bind_kill_session"
	debug_log "  rename-session: $bind_rename_session"
	debug_log "  window-mode: $bind_window_mode"
}

input() {
	default_window_mode=$(cached_tmux_option "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')
	else
		filter_current_session=$(cached_tmux_option "@sessionx-filter-current" "true")
		sort_mode=$(cached_tmux_option "@sessionx-sort" "default")
		
		# With reverse sort, we need descending sort to show newest first visually
		# With default sort, we need ascending sort to show newest first visually
		if [[ "$sort_mode" == "reverse" ]]; then
			sort_order="-rn"
		else
			sort_order="-n"
		fi
		
		# Minimum name-column width by preview location; the column grows past
		# this to fit the longest session name so the date column stays aligned
		# and long names are shown in full (truncating would break selection,
		# which parses the displayed name back to a real session).
		preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
		if [[ "$preview_location" == "left" ]]; then
			preview_location="right"
		fi
		if [[ "$preview_location" == "right" ]]; then
			name_width=20
		else
			name_width=30
		fi

		pin_color=$(cached_tmux_option "@sessionx-pin-color" "1;33")
		render_session_list "$CURRENT" "$filter_current_session" "$sort_order" "$name_width" "$pin_color"
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
	debug_log "handle_output: raw input: '$raw_output'"
	
	# Remove ALL leading/trailing whitespace including newlines
	raw_output="${raw_output#"${raw_output%%[![:space:]]*}"}"
	raw_output="${raw_output%"${raw_output##*[![:space:]]}"}"
	debug_log "handle_output: after trim: '$raw_output'"
	
	if [ -d "$raw_output" ]; then
		target="${raw_output//[$'\n\r']/}"
		if ! validate_path "$target"; then
			echo "Error: Invalid path" >&2
			exit 1
		fi
	elif echo "$raw_output" | grep ' | ' >/dev/null 2>&1; then
		# This has our delimiter format, extract session name
		debug_log "handle_output: detected delimiter format"
		# Extract session name from delimiter format
		# Remove everything after " | " delimiter
		target="${raw_output%% | *}"
		debug_log "handle_output: after delimiter removal: '$target'"
		# Trim trailing spaces from fixed-width formatting
		target="${target%"${target##*[![:space:]]}"}"
		debug_log "handle_output: after space trim: '$target'"
		if [[ "$target" == *:* ]]; then
			session_part="${target%%:*}"
			window_part="${target#*:}"
			if ! validate_session_name "$session_part" || [[ ! "$window_part" =~ ^[0-9]+$ ]]; then
				debug_log "handle_output: window target validation FAILED for '$target'"
				echo "Error: Invalid window target" >&2
				exit 1
			fi
		elif ! validate_session_name "$target"; then
			debug_log "handle_output: session name validation FAILED for '$target'"
			echo "Error: Invalid session name" >&2
			exit 1
		fi
		debug_log "handle_output: target validation PASSED"
	else
		# Plain session name without delimiter
		debug_log "handle_output: plain session name"
		target="${raw_output}"
		if ! validate_session_name "$target"; then
			debug_log "handle_output: session name validation FAILED for '$target'"
			echo "Error: Invalid session name" >&2
			exit 1
		fi
		debug_log "handle_output: session name validation PASSED"
	fi

	if [[ -z "$target" ]]; then
		debug_log "handle_output: target is empty, exiting"
		exit 0
	fi

	debug_log "handle_output: checking if session exists: '$target'"
	if ! tmux has-session -t="$target" 2>/dev/null; then
		debug_log "handle_output: session does not exist, will create"
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
	debug_log "handle_output: switching to session: '$target'"
	tmux switch-client -t "$target"
	debug_log "handle_output: switch command completed"
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
	PANES_MODE="$bind_panes_mode:change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -a {1})"
	# Validate CONFIGURATION_PATH to prevent command injection
	if [[ ! -d "$CONFIGURATION_PATH" ]]; then
		CONFIGURATION_PATH="$HOME/.config"
	fi
	CONFIGURATION_MODE="$bind_configuration_mode:reload(find '$CONFIGURATION_PATH' -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
	WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_index} | #{window_name}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

	NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
	# Use reload script for back functionality too
	BACK="$bind_back:reload($SCRIPT_DIR/reload-sessions.sh '$CURRENT')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {1})"
	# Use helper script for cleaner execution
	KILL_SESSION_CMD="$SCRIPT_DIR/kill-session.sh {} $DEBUG_MODE $DEBUG_LOG"
	# Use simpler reload script
	RELOAD_CMD="$SCRIPT_DIR/reload-sessions.sh '$CURRENT'"
	# Keep cursor position after deletion (--track handles this)
	KILL_SESSION="$bind_kill_session:execute-silent($KILL_SESSION_CMD)+reload($RELOAD_CMD)"
	PIN_SESSION="$bind_pin:execute-silent($SCRIPT_DIR/toggle-pin.sh {} $DEBUG_MODE $DEBUG_LOG)+reload($RELOAD_CMD)"
	TOGGLE_PREVIEW="$bind_toggle_preview:toggle-preview"
	debug_log "KILL_SESSION binding created: $KILL_SESSION"

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

	# Extract session name before delimiter for rename and trim ALL spaces
	if [[ "$DEBUG_MODE" == "on" ]]; then
		RENAME_SESSION_EXEC='bash -c '\''echo "[$(date +%Y-%m-%d\ %H:%M:%S)] RENAME_SESSION: input={}" >> '"$DEBUG_LOG"'; session=$(echo {} | cut -d"|" -f1); session="${session%"${session##*[![:space:]]}"}"; echo "[$(date +%Y-%m-%d\ %H:%M:%S)] RENAME_SESSION: extracted session=$session" >> '"$DEBUG_LOG"'; printf >&2 "New name: ";read name; tmux rename-session -t "$session" "${name}" 2>&1 | sed "s/^/[$(date +%Y-%m-%d\ %H:%M:%S)] RENAME_SESSION: /" >> '"$DEBUG_LOG"''\'''
	else
		RENAME_SESSION_EXEC='bash -c '\''session=$(echo {} | cut -d"|" -f1); session="${session%"${session##*[![:space:]]}"}"; printf >&2 "New name: ";read name; tmux rename-session -t "$session" "${name}"; '\'''
	fi
	# Get sort mode and column width for proper sorting in rename reload
	if [[ "$sort_mode" == "reverse" ]]; then
		sort_order_rename="-rn"
	else
		sort_order_rename="-n"
	fi
	# Get preview location for column width
	preview_location=$(cached_tmux_option "@sessionx-preview-location" "top")
	if [[ "$preview_location" == "left" ]]; then
		preview_location="right"
	fi
	if [[ "$preview_location" == "right" ]]; then
		name_width_rename=20
	else
		name_width_rename=30
	fi
	# Use the same reload command as kill session for consistency
	RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RELOAD_CMD)"

	# New session command
	if [[ "$DEBUG_MODE" == "on" ]]; then
		NEW_SESSION_EXEC='bash -c '\''echo "[$(date +%Y-%m-%d\ %H:%M:%S)] NEW_SESSION: prompting for name" >> '"$DEBUG_LOG"'; printf >&2 "New session name: ";read name; if [[ -n "$name" ]]; then tmux new-session -ds "$name" 2>&1 | sed "s/^/[$(date +%Y-%m-%d\ %H:%M:%S)] NEW_SESSION: /" >> '"$DEBUG_LOG"'; fi'\'''
	else
		NEW_SESSION_EXEC='bash -c '\''printf >&2 "New session name: ";read name; if [[ -n "$name" ]]; then tmux new-session -ds "$name"; fi'\'''
	fi
	NEW_SESSION="$bind_new_session:execute($NEW_SESSION_EXEC)+reload($RELOAD_CMD)"

	HELP="$bind_help:show-preview+change-preview(${SCRIPT_DIR}/help.sh)"

	HEADER="[$(short_key "$bind_new_session")]new [$(short_key "$bind_kill_session")]kill [$(short_key "$bind_rename_session")]rename [$(short_key "$bind_pin")]pin"
	LIST_HEADER="[$(short_key "$bind_window_mode")]win [$(short_key "$bind_panes_mode")]panes [$(short_key "$bind_tree_mode")]tree [$(short_key "$bind_back")]back
[$(short_key "$bind_toggle_preview")]preview [$(short_key "$bind_new_window")]dirs [$(short_key "$bind_configuration_mode")]config [$(short_key "$bind_help")]help"

	args=(
		--bind "$TMUXINATOR_MODE"
		--bind "$TREE_MODE"
		--bind "$PANES_MODE"
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
		--bind "$NEW_SESSION"
		--bind "$HELP"
		--bind "$TOGGLE_PREVIEW"
		--bind "$PIN_SESSION"
		--ansi
		--header "$LIST_HEADER"
		--exit-0
		--print-query
		--layout="$layout_mode"
		--pointer=$pointer_icon
		-p "$window_width,$window_height"
		--prompt "$prompt_icon"
		--scrollbar '▌▐'
		--delimiter ' \| '
	)
	
	if [[ "$preview_enabled" == "true" ]]; then
		args+=(--preview "${PREVIEW_LINE}")
		# Calculate preview window size based on location
		if [[ "$preview_location" == "right" ]] || [[ "$preview_location" == "left" ]]; then
			# For side previews, use list-pane-width to determine split
			# If list is 35%, preview should be 65%
			list_width_num="${list_pane_width%\%}"
			preview_width=$((100 - list_width_num))
			args+=(--preview-window "${preview_location},${preview_width}%,,")
		else
			# For top/bottom previews, preview-ratio controls the preview size
			# This means the list gets (100 - ratio) space
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

# Global variable to store result
RESULT=""

# Debug mode
DEBUG_MODE=""
DEBUG_LOG="/tmp/sessionx-debug.log"

# Debug logging function
debug_log() {
	if [[ "$DEBUG_MODE" == "on" ]]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
	fi
}

run_plugin() {
	load_tmux_options
	DEBUG_MODE=$(cached_tmux_option "@sessionx-debug" "off")
	
	# Initialize debug log if enabled
	if [[ "$DEBUG_MODE" == "on" ]]; then
		echo "=== SessionX Debug Log Started at $(date) ===" > "$DEBUG_LOG"
		debug_log "Current session: $CURRENT"
		debug_log "Debug mode enabled"
	fi
	
	preview_settings
	window_settings
	handle_binds
	handle_args
	
	debug_log "Running fzf with $(echo "${args[@]}" | wc -w) arguments"
	debug_log "Input sessions: $(echo "$INPUT" | wc -l) lines"
	
	# Debug the actual fzf command
	debug_log "fzf command: fzf-tmux ${args[@]}"
	
	# Use printf instead of echo -e and quote array expansions
	debug_log "About to run fzf..."
	debug_log "fzf_opts: ${fzf_opts[*]:-none}"
	
	# Run fzf and capture output
	local fzf_output
	if [[ -n "${fzf_opts[*]:-}" ]]; then
		fzf_output=$(printf '%s\n' "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${fzf_opts[@]}" "${args[@]}")
	else
		fzf_output=$(printf '%s\n' "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${args[@]}")
	fi
	local fzf_exit=$?
	debug_log "fzf returned: exit_code=$fzf_exit, raw output lines: $(echo "$fzf_output" | wc -l)"
	
	# With replace-query+print-query, fzf outputs only the query/selection
	RESULT="$fzf_output"
	debug_log "fzf final RESULT='$RESULT'"
}

run_plugin
exit_code=$?

debug_log "Main: fzf exit code: $exit_code"
debug_log "Main: RESULT value: '$RESULT'"

# Exit code 130 means user cancelled (Ctrl-C or ESC)
if [[ $exit_code -eq 130 ]]; then
	debug_log "Main: User cancelled (ESC or Ctrl-C)"
	exit 0
fi

# Exit code 1 typically means fzf error or no selection made
if [[ $exit_code -eq 1 ]]; then
	debug_log "Main: No selection made or fzf error"
	exit 0
fi

# Exit code 2 means actual error
if [[ $exit_code -eq 2 ]]; then
	debug_log "Main: fzf error occurred"
	exit 1
fi

if [[ -n "$RESULT" ]]; then
	debug_log "Main: About to handle output: '$RESULT'"
	handle_output "$RESULT"
else
	debug_log "Main: No result to handle"
fi
