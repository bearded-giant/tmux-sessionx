#!/usr/bin/env bash
set -euo pipefail

# Comprehensive debug script for tmux-sessionx
LOGFILE="/tmp/sessionx-debug-standalone.log"
echo "=== SessionX Standalone Debug Started at $(date) ===" > "$LOGFILE"

# System info
echo "=== System Information ===" >> "$LOGFILE"
echo "OS: $(uname -s)" >> "$LOGFILE"
echo "Shell: $SHELL" >> "$LOGFILE"
echo "Tmux version: $(tmux -V)" >> "$LOGFILE"
echo "fzf version: $(fzf --version 2>&1 || echo "not found")" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Tmux environment
echo "=== Tmux Environment ===" >> "$LOGFILE"
CURRENT=$(tmux display-message -p '#S')
echo "Current session: $CURRENT" >> "$LOGFILE"
echo "Session list:" >> "$LOGFILE"
tmux list-sessions -F '  #{session_name} (created: #{session_created}, attached: #{session_attached})' >> "$LOGFILE" 2>&1
echo "" >> "$LOGFILE"

# SessionX configuration
echo "=== SessionX Configuration ===" >> "$LOGFILE"
echo "Checking tmux options:" >> "$LOGFILE"
tmux show-options -g | grep '@sessionx' >> "$LOGFILE" 2>&1 || echo "  No sessionx options found" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Test session list generation
echo "=== Session List Generation Test ===" >> "$LOGFILE"
get_sessions() {
    tmux list-sessions -F '#{session_last_attached}|#{session_name}' | \
    sort -rn -t'|' -k1 | \
    while IFS='|' read -r timestamp name; do
        if [[ -n "$timestamp" ]] && [[ "$timestamp" =~ ^[0-9]+$ ]]; then
            formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
        else
            formatted_time="Unknown"
        fi
        printf "%-30s | %s\n" "$name" "$formatted_time"
    done
}

INPUT=$(get_sessions)
echo "Generated session list:" >> "$LOGFILE"
echo "$INPUT" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Test fzf interaction
echo "=== Testing FZF Interaction ===" >> "$LOGFILE"
echo "Running fzf with minimal options..." >> "$LOGFILE"

# Create test bindings with detailed logging
RESULT=$(echo "$INPUT" | fzf-tmux \
    --bind 'enter:accept' \
    --bind 'alt-d:execute(echo "DELETE pressed for: {}" >> '"$LOGFILE"')+execute-silent(echo "Would delete: {}" >> '"$LOGFILE"')+reload('"$0"' --reload-only)' \
    --bind 'ctrl-r:execute(echo "RENAME pressed for: {}" >> '"$LOGFILE"')' \
    --bind 'esc:abort' \
    -p "80%,80%" \
    --header="SessionX Debug Mode - Enter=select, Alt-d=delete test, Ctrl-r=rename test, Esc=exit" \
    --preview='echo "Preview for: {}"' \
    --delimiter ' | ')

EXIT_CODE=$?
echo "FZF exit code: $EXIT_CODE" >> "$LOGFILE"
echo "Raw result: '$RESULT'" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Test result parsing
if [[ $EXIT_CODE -eq 0 ]] && [[ -n "$RESULT" ]]; then
    echo "=== Result Parsing Test ===" >> "$LOGFILE"
    echo "Raw output: '$RESULT'" >> "$LOGFILE"
    
    # Test whitespace removal
    CLEANED="${RESULT#"${RESULT%%[![:space:]]*}"}"
    CLEANED="${CLEANED%"${CLEANED##*[![:space:]]}"}"
    echo "After whitespace trim: '$CLEANED'" >> "$LOGFILE"
    
    # Test session name extraction methods
    echo "" >> "$LOGFILE"
    echo "Testing extraction methods:" >> "$LOGFILE"
    
    # Method 1: Delimiter split
    if echo "$CLEANED" | grep ' | ' >/dev/null 2>&1; then
        SESSION_NAME="${CLEANED%% | *}"
        SESSION_NAME="${SESSION_NAME%"${SESSION_NAME##*[![:space:]]}"}"
        echo "  Delimiter method: '$SESSION_NAME'" >> "$LOGFILE"
    fi
    
    # Method 2: Cut command (as used in kill/rename)
    SESSION_CUT=$(echo "$CLEANED" | cut -d"|" -f1)
    SESSION_CUT="${SESSION_CUT%"${SESSION_CUT##*[![:space:]]}"}"
    echo "  Cut method: '$SESSION_CUT'" >> "$LOGFILE"
    
    # Test if session exists
    if [[ -n "${SESSION_NAME:-}" ]]; then
        echo "" >> "$LOGFILE"
        echo "Testing session existence:" >> "$LOGFILE"
        if tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
            echo "  Session '$SESSION_NAME' EXISTS" >> "$LOGFILE"
            echo "  Would switch to: $SESSION_NAME" >> "$LOGFILE"
            
            # Actually switch if not in reload mode
            if [[ "${1:-}" != "--reload-only" ]]; then
                tmux switch-client -t "$SESSION_NAME"
                echo "  Switch command executed" >> "$LOGFILE"
            fi
        else
            echo "  Session '$SESSION_NAME' NOT FOUND" >> "$LOGFILE"
            echo "  Available sessions:" >> "$LOGFILE"
            tmux list-sessions -F '    #{session_name}' >> "$LOGFILE" 2>&1
        fi
    fi
elif [[ $EXIT_CODE -eq 130 ]]; then
    echo "User cancelled (ESC or Ctrl-C)" >> "$LOGFILE"
else
    echo "No selection made or error occurred" >> "$LOGFILE"
fi

# Summary
echo "" >> "$LOGFILE"
echo "=== Debug Summary ===" >> "$LOGFILE"
echo "Log file: $LOGFILE" >> "$LOGFILE"
echo "To view: cat $LOGFILE" >> "$LOGFILE"

# Special mode for reload
if [[ "${1:-}" == "--reload-only" ]]; then
    get_sessions
    exit 0
fi

echo ""
echo "Debug session completed. Check log at: $LOGFILE"