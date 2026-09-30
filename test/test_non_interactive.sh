#!/usr/bin/env bash
set -euo pipefail

# Non-interactive tests for tmux-sessionx

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_DIR="$PROJECT_DIR/scripts"

echo "==========================================="
echo "SessionX Non-Interactive Test Suite"
echo "==========================================="
echo

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function
test_function() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo -n "Testing $test_name... "
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# 1. Test common.sh functions
echo -e "${BLUE}1. Testing common.sh functions${NC}"
echo "------------------------------"

test_function "validate_session_name (valid)" "
    source '$SCRIPT_DIR/common.sh'
    validate_session_name 'my-session_123'
"

test_function "validate_session_name (invalid)" "
    source '$SCRIPT_DIR/common.sh'
    ! validate_session_name 'bad;name$(id)'
"

test_function "validate_path (valid)" "
    source '$SCRIPT_DIR/common.sh'
    validate_path '$HOME'
"

test_function "validate_path (invalid ../)" "
    source '$SCRIPT_DIR/common.sh'
    ! validate_path '../../../etc/passwd'
"

# 2. Test tmuxinator.sh functions
echo -e "\n${BLUE}2. Testing tmuxinator.sh functions${NC}"
echo "---------------------------------"

test_function "is_tmuxinator_enabled function exists" "
    source '$SCRIPT_DIR/common.sh'
    source '$SCRIPT_DIR/tmuxinator.sh'
    type -t is_tmuxinator_enabled >/dev/null
"

# 3. Test sessionx.sh loading
echo -e "\n${BLUE}3. Testing sessionx.sh loading${NC}"
echo "-----------------------------"

test_function "sessionx.sh sources without error" "
    (
        # Mock functions that would require tmux
        tmux() { return 0; }
        export -f tmux
        
        # Source in subshell to avoid polluting environment
        source '$SCRIPT_DIR/sessionx.sh' 2>/dev/null || true
        
        # Check if key functions are defined
        type -t load_tmux_options >/dev/null
    )
"

# 4. Test option parsing
echo -e "\n${BLUE}4. Testing option parsing${NC}"
echo "------------------------"

test_function "tmux option parsing regex" "
    line='@sessionx-bind o'
    [[ \"\$line\" =~ ^(@[^[:space:]]+)[[:space:]](.*)$ ]]
    [[ \"\${BASH_REMATCH[1]}\" == '@sessionx-bind' ]]
    [[ \"\${BASH_REMATCH[2]}\" == 'o' ]]
"

test_function "preview scroll option parsing" "
    line='@sessionx-enable-preview-scroll true'
    [[ \"\$line\" =~ ^(@[^[:space:]]+)[[:space:]](.*)$ ]]
    [[ \"\${BASH_REMATCH[1]}\" == '@sessionx-enable-preview-scroll' ]]
    [[ \"\${BASH_REMATCH[2]}\" == 'true' ]]
"

# 5. Test help script
echo -e "\n${BLUE}5. Testing help.sh${NC}"
echo "-----------------"

test_function "help.sh executes" "
    bash '$SCRIPT_DIR/help.sh' | grep -q 'Keybindings'
"

# 6. Test error conditions
echo -e "\n${BLUE}6. Testing error conditions${NC}"
echo "--------------------------"

test_function "sessionx.sh fails outside tmux" "
    (
        unset TMUX
        ! bash '$SCRIPT_DIR/sessionx.sh' 2>/dev/null
    )
"

# 7. Test helper scripts
echo -e "\n${BLUE}7. Testing helper scripts${NC}"
echo "------------------------"

test_function "kill-session.sh exists and is executable" "
    [[ -f '$SCRIPT_DIR/kill-session.sh' ]] && [[ -x '$SCRIPT_DIR/kill-session.sh' ]]
"

test_function "reload-sessions.sh exists and is executable" "
    [[ -f '$SCRIPT_DIR/reload-sessions.sh' ]] && [[ -x '$SCRIPT_DIR/reload-sessions.sh' ]]
"

test_function "kill-session.sh handles input correctly" "
    (
        # Create a test session
        tmux new-session -d -s test-kill-$$
        # Run kill script
        bash '$SCRIPT_DIR/kill-session.sh' 'test-kill-$$                         | Dec 22 17:00' 'off' '/tmp/test-kill.log'
        # Verify session was killed
        ! tmux has-session -t test-kill-$$ 2>/dev/null
    )
"

# 8. Test claude status column
echo -e "\n${BLUE}8. Testing claude status column${NC}"
echo "------------------------"

# a copied binary, not a symlink: tmux reports the real binary name for symlinks
FAKE_BIN=$(mktemp -d)
cp "$(command -v bash)" "$FAKE_BIN/claude"
# trailing ':' stops bash from exec-ing sleep, which would rename the pane command
FAKE_CLAUDE="$FAKE_BIN/claude -c 'sleep 60; :'"
CLAUDE_A="sx-claude-a-$$"
CLAUDE_B="sx-claude-b-$$"
tmux new-session -d -s "$CLAUDE_A" "$FAKE_CLAUDE"
tmux set-option -p -t "$CLAUDE_A" @claude_state ask
tmux set-option -p -t "$CLAUDE_A" @claude_state_at $(($(date +%s) - 600))
tmux new-session -d -s "$CLAUDE_B" "$FAKE_BIN/claude -c 'printf \"❯ \\n\"; sleep 60; :'"
tmux set-option -p -t "$CLAUDE_B" @claude_state busy
sleep 0.5

test_function "lone claude pane shows hook state and idle age" "
    bash '$SCRIPT_DIR/reload-sessions.sh' x | grep '$CLAUDE_A ' | grep -q '| ask 10m\$'
"

test_function "stale hook busy is corrected by the screen" "
    bash '$SCRIPT_DIR/reload-sessions.sh' x | grep '$CLAUDE_B ' | grep -q '| ready\$'
"

PANE_READY=$(tmux split-window -d -P -F '#{pane_id}' -t "$CLAUDE_A" "$FAKE_CLAUDE")
tmux set-option -p -t "$PANE_READY" @claude_state ready

test_function "several claude panes show counts per state" "
    bash '$SCRIPT_DIR/reload-sessions.sh' x | grep '$CLAUDE_A ' | grep -q '| ask 1 · ready 1\$'
"

tmux set-option -p -t "$PANE_READY" remain-on-exit on
tmux respawn-pane -k -t "$PANE_READY" "$FAKE_BIN/claude -c ':'"
sleep 0.3

test_function "dead claude pane is skipped" "
    bash '$SCRIPT_DIR/reload-sessions.sh' x | grep '$CLAUDE_A ' | grep -q '| ask 10m\$'
"

tmux kill-session -t "$CLAUDE_A"
tmux kill-session -t "$CLAUDE_B"
rm -r "${FAKE_BIN:?}"

# Summary
echo
echo "==========================================="
echo -e "${BLUE}Test Summary${NC}"
echo "==========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All non-interactive tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi