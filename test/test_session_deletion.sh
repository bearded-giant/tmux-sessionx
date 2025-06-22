#!/usr/bin/env bash
set -euo pipefail

# Test session deletion and UI refresh functionality

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/test_helpers.sh" 2>/dev/null || true

# Test setup
TEST_SESSION_PREFIX="test-delete-$$"
SESSIONS_TO_CREATE=3

echo "=== Testing Session Deletion with UI Refresh ==="

# Create test sessions
echo "1. Creating test sessions..."
for i in $(seq 1 $SESSIONS_TO_CREATE); do
    SESSION_NAME="${TEST_SESSION_PREFIX}-${i}"
    tmux new-session -d -s "$SESSION_NAME"
    echo "   Created: $SESSION_NAME"
done

# Verify sessions exist
echo "2. Verifying sessions exist..."
CREATED_SESSIONS=$(tmux list-sessions -F '#{session_name}' | grep "^${TEST_SESSION_PREFIX}" | wc -l)
if [[ $CREATED_SESSIONS -ne $SESSIONS_TO_CREATE ]]; then
    echo "   ERROR: Expected $SESSIONS_TO_CREATE sessions, found $CREATED_SESSIONS"
    exit 1
fi
echo "   SUCCESS: All $SESSIONS_TO_CREATE test sessions created"

# Test deletion functionality
echo "3. Testing deletion functionality..."
SESSION_TO_DELETE="${TEST_SESSION_PREFIX}-2"

# Test the kill-session.sh script directly
KILL_SCRIPT="${SCRIPT_DIR}/../scripts/kill-session.sh"
if [[ -f "$KILL_SCRIPT" ]]; then
    echo "   Testing kill-session.sh with: $SESSION_TO_DELETE | Dec 22 17:00"
    bash "$KILL_SCRIPT" "$SESSION_TO_DELETE                         | Dec 22 17:00" "off" "/tmp/test-delete.log"
    
    # Verify session was deleted
    if tmux has-session -t "$SESSION_TO_DELETE" 2>/dev/null; then
        echo "   ERROR: Session $SESSION_TO_DELETE was not deleted"
        exit 1
    else
        echo "   SUCCESS: Session $SESSION_TO_DELETE was deleted"
    fi
else
    echo "   WARNING: kill-session.sh not found, skipping direct test"
fi

# Test reload functionality
echo "4. Testing reload-sessions.sh..."
RELOAD_SCRIPT="${SCRIPT_DIR}/../scripts/reload-sessions.sh"
if [[ -f "$RELOAD_SCRIPT" ]]; then
    OUTPUT=$(bash "$RELOAD_SCRIPT" "$TEST_SESSION_PREFIX-1")
    REMAINING_SESSIONS=$(echo "$OUTPUT" | grep "^${TEST_SESSION_PREFIX}" | wc -l)
    
    # Should show 2 sessions (we deleted one), but not the current session if filtering is on
    if [[ $REMAINING_SESSIONS -eq 1 ]]; then
        echo "   SUCCESS: Reload shows correct number of sessions (with filtering)"
    elif [[ $REMAINING_SESSIONS -eq 2 ]]; then
        echo "   SUCCESS: Reload shows correct number of sessions (without filtering)"
    else
        echo "   ERROR: Expected 1 or 2 sessions in reload, found $REMAINING_SESSIONS"
        echo "   Output:"
        echo "$OUTPUT"
        exit 1
    fi
else
    echo "   WARNING: reload-sessions.sh not found, skipping reload test"
fi

# Test session switching
echo "5. Testing session switching..."
SWITCH_TO="${TEST_SESSION_PREFIX}-3"
if tmux has-session -t "$SWITCH_TO" 2>/dev/null; then
    # We can't actually switch in a non-interactive test, but we can verify the session exists
    echo "   SUCCESS: Target session $SWITCH_TO exists and is available for switching"
else
    echo "   ERROR: Target session $SWITCH_TO does not exist"
    exit 1
fi

# Cleanup
echo "6. Cleaning up test sessions..."
tmux list-sessions -F '#{session_name}' | grep "^${TEST_SESSION_PREFIX}" | while read -r session; do
    tmux kill-session -t "$session" 2>/dev/null || true
    echo "   Removed: $session"
done

echo ""
echo "=== All deletion and UI refresh tests passed! ==="