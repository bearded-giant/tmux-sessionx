#!/usr/bin/env bash
# Helper script to test sessionx by automatically closing it

# Launch sessionx in background
TMUX_PLUGIN_MANAGER_PATH="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.config/tmux/plugins}"
bash "$1" &
PID=$!

# Give it time to start
sleep 0.5

# Check if process is still running
if kill -0 $PID 2>/dev/null; then
    # Send SIGINT (Ctrl-C) to simulate ESC
    kill -INT $PID 2>/dev/null || true
    
    # Wait for it to exit
    wait $PID
    exit_code=$?
    
    # Exit code 130 is expected (user cancelled)
    if [[ $exit_code -eq 0 || $exit_code -eq 130 ]]; then
        exit 0
    else
        exit $exit_code
    fi
else
    # Process already exited
    wait $PID
    exit_code=$?
    
    # If it exited immediately with 0 or 130, that's OK
    if [[ $exit_code -eq 0 || $exit_code -eq 130 ]]; then
        exit 0
    else
        exit $exit_code
    fi
fi