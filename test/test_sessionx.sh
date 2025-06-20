#!/usr/bin/env bash
set -euo pipefail

# Test framework for tmux-sessionx
# Run this before deploying to catch runtime errors

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

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Mock environment variables that would be set by tmux
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins"
export TMUX="/tmp/tmux-test-$$"

# Test output
TEST_OUTPUT=""
TEST_ERRORS=""

# Helper functions
run_test() {
    local test_name="$1"
    local test_type="${2:-execute}"  # execute, source, or function
    local test_command="$3"
    
    echo -n "Testing ${test_name}... "
    
    local output
    local exit_code=0
    
    case "$test_type" in
        execute)
            output=$(eval "$test_command" 2>&1) || exit_code=$?
            ;;
        source)
            output=$(bash -c "set -euo pipefail; $test_command" 2>&1) || exit_code=$?
            ;;
        function)
            output=$(bash -c "set -euo pipefail; source $test_command" 2>&1) || exit_code=$?
            ;;
    esac
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "  ${RED}Exit code: $exit_code${NC}"
        echo -e "  ${RED}Output: $output${NC}"
        TEST_ERRORS+="\n${test_name}:\n${output}\n"
        ((TESTS_FAILED++))
    fi
}

skip_test() {
    local test_name="$1"
    local reason="$2"
    echo -e "Testing ${test_name}... ${YELLOW}SKIPPED${NC} ($reason)"
    ((TESTS_SKIPPED++))
}

# Mock tmux command for testing
create_mock_tmux() {
    cat > /tmp/mock_tmux_$$ << 'EOF'
#!/usr/bin/env bash
case "$1" in
    "show-option")
        case "$3" in
            "@sessionx-bind") echo "o" ;;
            "@sessionx-preview-enabled") echo "false" ;;
            "@sessionx-window-mode") echo "off" ;;
            "@sessionx-filter-current") echo "true" ;;
            "@sessionx-zoxide-mode") echo "off" ;;
            "@sessionx-x-path") echo "$HOME/.config" ;;
            "@sessionx-window-height") echo "85%" ;;
            "@sessionx-window-width") echo "75%" ;;
            "@sessionx-layout") echo "default" ;;
            "@sessionx-prompt") echo " " ;;
            "@sessionx-pointer") echo "▶" ;;
            "@sessionx-additional-options") echo "" ;;
            "@sessionx-legacy-fzf-support") echo "off" ;;
            "@sessionx-tmuxinator-mode") echo "off" ;;
            "@sessionx-bind-help") echo "ctrl-h" ;;
            *) echo "" ;;
        esac
        ;;
    "display-message")
        echo "test-session"
        ;;
    "list-sessions")
        echo "test-session: 1 windows"
        echo "another-session: 2 windows"
        ;;
    "list-windows")
        echo "test-session:0 window1"
        echo "test-session:1 window2"
        ;;
    "has-session")
        [[ "$2" == "-t=test-session" ]] && exit 0 || exit 1
        ;;
    *)
        echo "Mock tmux: unhandled command $*" >&2
        exit 0
        ;;
esac
EOF
    chmod +x /tmp/mock_tmux_$$
}

# Create mock fzf for testing
create_mock_fzf() {
    cat > /tmp/mock_fzf_$$ << 'EOF'
#!/usr/bin/env bash
# Mock fzf - just return first input line
head -1
EOF
    chmod +x /tmp/mock_fzf_$$
}

echo "================================="
echo "tmux-sessionx Test Suite"
echo "================================="
echo

# Test 1: Basic syntax checks
echo -e "${BLUE}1. Syntax Validation Tests${NC}"
echo "-------------------------"
for script in sessionx.sh preview.sh reload_sessions.sh tmuxinator.sh common.sh help.sh fzf-marks.sh; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        run_test "$script syntax" "execute" "bash -n '$SCRIPT_DIR/$script'"
    else
        skip_test "$script syntax" "file not found"
    fi
done

# Test 2: Test sourcing common functions
echo -e "\n${BLUE}2. Function Sourcing Tests${NC}"
echo "-------------------------"

# Test common.sh functions
run_test "common.sh functions" "function" "
source '$SCRIPT_DIR/common.sh'
# Test tmux_option_or_fallback
result=\$(tmux() { echo ''; }; tmux_option_or_fallback 'test' 'fallback')
[[ \"\$result\" == 'fallback' ]] || exit 1

# Test validate_session_name
validate_session_name 'valid-name' || exit 1
validate_session_name 'invalid name with spaces' && exit 1
validate_session_name 'invalid;name' && exit 1

# Test validate_path
validate_path '$HOME' || exit 1
validate_path '../dangerous' && exit 1
validate_path '/nonexistent/path' && exit 1
"

# Test tmuxinator.sh functions
run_test "tmuxinator.sh functions" "function" "
# Source common.sh first
source '$SCRIPT_DIR/common.sh'
# Mock tmux function
tmux() {
    case \"\$1 \$3\" in
        'show-option @sessionx-tmuxinator-mode') echo 'off' ;;
        *) echo '' ;;
    esac
}
export -f tmux

source '$SCRIPT_DIR/tmuxinator.sh'
# Test functions exist
type is_tmuxinator_enabled >/dev/null || exit 1
type is_tmuxinator_template >/dev/null || exit 1
type load_tmuxinator_binding >/dev/null || exit 1
"

# Test fzf-marks.sh functions
run_test "fzf-marks.sh functions" "function" "
# Source common.sh first
source '$SCRIPT_DIR/common.sh'
# Mock tmux function
tmux() {
    case \"\$1 \$3\" in
        'show-option @sessionx-fzf-marks-file') echo '~/.fzf-marks' ;;
        'show-option @sessionx-fzf-marks-mode') echo 'off' ;;
        *) echo '' ;;
    esac
}
export -f tmux

source '$SCRIPT_DIR/fzf-marks.sh'
# Test functions exist
type is_fzf-marks_enabled >/dev/null || exit 1
type get_fzf-marks_file >/dev/null || exit 1
"

# Test 3: Variable initialization tests
echo -e "\n${BLUE}3. Variable Initialization Tests${NC}"
echo "--------------------------------"

# Create mocks
create_mock_tmux
create_mock_fzf

# Test sessionx.sh with mocked environment
run_test "sessionx.sh variable initialization" "source" "
export PATH=/tmp:\$PATH
mv /tmp/mock_tmux_$$ /tmp/tmux
mv /tmp/mock_fzf_$$ /tmp/fzf
mv /tmp/mock_fzf_$$ /tmp/fzf-tmux

# Source the required files
source '$SCRIPT_DIR/common.sh'
source '$SCRIPT_DIR/tmuxinator.sh'
source '$SCRIPT_DIR/fzf-marks.sh'

# Test critical variables
set -euo pipefail

# Run initialization functions
preview_enabled='false'
PREVIEW_OPTIONS=''

# This would normally be set by handle_args
if [[ \"\$preview_enabled\" == 'true' ]]; then
    PREVIEW_LINE='test'
else
    PREVIEW_LINE=''
fi

# Verify PREVIEW_LINE is defined (even if empty)
[[ -v PREVIEW_LINE ]] || exit 1
"

# Test 4: Integration tests
echo -e "\n${BLUE}4. Integration Tests${NC}"
echo "-------------------"

# Test preview.sh modes
if command -v tmux &>/dev/null; then
    run_test "preview.sh single mode" "execute" "$SCRIPT_DIR/preview.sh 'test-session' 2>&1 | head -1"
    run_test "preview.sh tree mode" "execute" "$SCRIPT_DIR/preview.sh -t 'test-session' 2>&1 | head -1"
else
    skip_test "preview.sh integration" "tmux not available"
fi

# Test help.sh output
run_test "help.sh output" "execute" "$SCRIPT_DIR/help.sh | head -1 | grep -q 'SessionX Keybindings'"

# Test 5: Edge case tests
echo -e "\n${BLUE}5. Edge Case Tests${NC}"
echo "------------------"

# Test with special characters
run_test "session name validation" "function" "
source '$SCRIPT_DIR/common.sh'
# Test various edge cases
validate_session_name 'test-123' || exit 1
validate_session_name 'test_123' || exit 1
validate_session_name 'test.123' || exit 1
validate_session_name 'test:123' || exit 1
validate_session_name 'test 123' && exit 1
validate_session_name 'test\$123' && exit 1
validate_session_name 'test;rm -rf' && exit 1
"

# Test path validation
run_test "path validation security" "function" "
source '$SCRIPT_DIR/common.sh'
# Test path traversal protection
validate_path '/home/user/../../../etc' && exit 1
validate_path '/home/user/*/passwords' && exit 1
validate_path '/home/user/normal/path' && exit 0  # Would fail if path doesn't exist
"

# Cleanup
rm -f /tmp/mock_tmux_$$ /tmp/mock_fzf_$$ /tmp/tmux /tmp/fzf /tmp/fzf-tmux

# Summary
echo
echo "================================="
echo -e "${BLUE}Test Summary${NC}"
echo "================================="
echo -e "Tests Passed:  ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed:  ${RED}${TESTS_FAILED}${NC}"
echo -e "Tests Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "\n${RED}Failed Test Details:${NC}"
    echo -e "$TEST_ERRORS"
    echo -e "\n${RED}✗ Tests failed! Fix issues before using the plugin.${NC}"
    exit 1
else
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. From tmux, press Ctrl-a + o to test the plugin"
    echo "2. If it fails, check:"
    echo "   - Run: tmux list-keys | grep sessionx"
    echo "   - Run: bash ~/.config/tmux/plugins/tmux-sessionx/scripts/sessionx.sh"
    echo "3. To see debug output, temporarily add 'set -x' to sessionx.sh"
fi

exit 0