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
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
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
    ! validate_session_name 'my session with spaces'
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