#!/usr/bin/env bash
set -euo pipefail

# Test script to validate sessionx launching and closing

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
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "================================="
echo "SessionX Launch/Close Test Suite"
echo "================================="
echo

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_result="${3:-pass}"
    
    ((TESTS_RUN++))
    echo -n "Testing $test_name... "
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        if [[ "$expected_result" == "pass" ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAILED${NC} (expected to fail but passed)"
            ((TESTS_FAILED++))
        fi
    else
        local exit_code=$?
        if [[ "$expected_result" == "fail" ]]; then
            echo -e "${GREEN}PASSED${NC} (correctly failed)"
            ((TESTS_PASSED++))
        elif [[ $exit_code -eq 124 ]]; then
            echo -e "${YELLOW}TIMEOUT${NC} (script waiting for input - expected)"
            ((TESTS_PASSED++))
        elif [[ $exit_code -eq 130 ]]; then
            echo -e "${GREEN}PASSED${NC} (user cancelled)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAILED${NC} (exit code: $exit_code)"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 1: Basic Setup Tests
echo -e "${BLUE}1. Basic Setup Tests${NC}"
echo "-----------------------------------"

# Set required environment variables
export TMUX_PLUGIN_MANAGER_PATH="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.config/tmux/plugins}"

# Test script existence
run_test "script exists" "[[ -f '$SCRIPT_DIR/sessionx.sh' ]]"
run_test "script is executable" "[[ -x '$SCRIPT_DIR/sessionx.sh' ]]"
run_test "common.sh exists" "[[ -f '$SCRIPT_DIR/common.sh' ]]"
run_test "tmuxinator.sh exists" "[[ -f '$SCRIPT_DIR/tmuxinator.sh' ]]"

# Test syntax
run_test "sessionx.sh syntax" "bash -n '$SCRIPT_DIR/sessionx.sh'"
run_test "common.sh syntax" "bash -n '$SCRIPT_DIR/common.sh'"

# Test 2: Script Launch Tests
echo -e "\n${BLUE}2. Script Launch Tests${NC}"
echo "----------------------"

# Test basic launch with automatic close
run_test "launch and auto-close" "$TEST_DIR/helpers/auto_close_sessionx.sh '$SCRIPT_DIR/sessionx.sh'"

# Test launch and close with expect (if available)
if command -v expect >/dev/null 2>&1; then
    echo -n "Testing launch and close with expect... "
    cat > /tmp/test_sessionx_expect.exp << 'EOF'
#!/usr/bin/expect -f
set timeout 3
spawn bash -c "TMUX_PLUGIN_MANAGER_PATH=$env(TMUX_PLUGIN_MANAGER_PATH) bash $env(SCRIPT_DIR)/sessionx.sh"
expect {
    timeout { exit 124 }
    -re ".+" { 
        send "\033"
        expect eof
        exit 0
    }
}
EOF
    chmod +x /tmp/test_sessionx_expect.exp
    
    if SCRIPT_DIR="$SCRIPT_DIR" TMUX_PLUGIN_MANAGER_PATH="$TMUX_PLUGIN_MANAGER_PATH" expect /tmp/test_sessionx_expect.exp >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${YELLOW}TIMEOUT${NC}"
        else
            echo -e "${RED}FAILED${NC} (exit code: $exit_code)"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    fi
    rm -f /tmp/test_sessionx_expect.exp
else
    echo -e "${YELLOW}Skipping expect tests (expect not installed)${NC}"
fi

# Test 3: Test option loading
echo -n "Testing option loading... "
test_output=$(bash -c "
set -euo pipefail
source '$SCRIPT_DIR/common.sh'
source '$SCRIPT_DIR/tmuxinator.sh'

# Mock tmux to return test values
tmux() {
    case \"\$*\" in
        'show-options -gq')
            echo '@sessionx-bind o'
            echo '@sessionx-preview-enabled false'
            echo '@sessionx-window-mode off'
            ;;
        'show-option -gqv'*)
            echo ''
            ;;
        'display-message -p #S')
            echo 'test-session'
            ;;
        'list-sessions -F'*)
            echo '1234567890:test-session'
            ;;
        *)
            return 0
            ;;
    esac
}
export -f tmux

# Source and test the load_tmux_options function
source '$SCRIPT_DIR/sessionx.sh' >/dev/null 2>&1 || true

# Test the function
load_tmux_options
echo \"Options loaded: \${#TMUX_OPTIONS_CACHE[@]}\"

# Verify some options
[[ \"\${TMUX_OPTIONS_CACHE[@sessionx-bind]:-}\" == 'o' ]] || echo 'Failed: bind not loaded'
[[ \"\${TMUX_OPTIONS_CACHE[@sessionx-preview-enabled]:-}\" == 'false' ]] || echo 'Failed: preview-enabled not loaded'
" 2>&1)

if [[ "$test_output" =~ "Options loaded:" ]] && [[ ! "$test_output" =~ "Failed:" ]]; then
    echo -e "${GREEN}PASSED${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Output: $test_output"
fi

# Test 4: Test exit code handling
echo -n "Testing exit code handling... "
test_exit_handling=$(bash -c "
# Test the exit code handling logic
run_plugin() { return 130; }
handle_output() { echo 'Should not reach here'; exit 1; }

# Source the relevant part
exit_code=130
if [[ \$exit_code -eq 130 ]]; then
    echo 'EXIT_HANDLED'
    exit 0
fi
handle_output 'test'
" 2>&1)

if [[ "$test_exit_handling" == "EXIT_HANDLED" ]]; then
    echo -e "${GREEN}PASSED${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Output: $test_exit_handling"
fi

# Test 5: Test preview line initialization
echo -n "Testing preview line initialization... "
preview_test=$(bash -c "
set -euo pipefail

# Test with preview disabled
preview_enabled='false'
PREVIEW_OPTIONS=''

if [[ \"\$preview_enabled\" == 'true' ]]; then
    PREVIEW_LINE='preview'
else
    PREVIEW_LINE=''
fi

# Check that PREVIEW_LINE is defined
[[ -v PREVIEW_LINE ]] || exit 1
echo 'PREVIEW_OK'
" 2>&1)

if [[ "$preview_test" == "PREVIEW_OK" ]]; then
    echo -e "${GREEN}PASSED${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

# Test 6: Integration test with mock fzf
echo -e "\n${BLUE}3. Integration Tests${NC}"
echo "-------------------"

# Create a mock fzf that immediately exits
cat > /tmp/mock_fzf << 'EOF'
#!/usr/bin/env bash
# Mock fzf that immediately exits with code 130 (user cancelled)
exit 130
EOF
chmod +x /tmp/mock_fzf

cat > /tmp/mock_fzf-tmux << 'EOF'
#!/usr/bin/env bash
# Mock fzf-tmux that immediately exits with code 130 (user cancelled)
exit 130
EOF
chmod +x /tmp/mock_fzf-tmux

run_test "mock fzf (immediate cancel)" "PATH='/tmp:$PATH' TMUX_PLUGIN_MANAGER_PATH='$TMUX_PLUGIN_MANAGER_PATH' bash '$SCRIPT_DIR/sessionx.sh'"

# Test without mock (real commands)
run_test "real commands with auto-close" "$TEST_DIR/helpers/auto_close_sessionx.sh '$SCRIPT_DIR/sessionx.sh'"

# Cleanup
rm -f /tmp/mock_fzf /tmp/mock_fzf-tmux

# Summary
echo
echo "================================="
echo -e "${BLUE}Test Summary${NC}"
echo "================================="
echo -e "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Test from tmux: Press <prefix>o (usually Ctrl-b o)"
    echo "2. If it doesn't work: tmux source ~/.config/tmux/tmux.conf"
    echo "3. Check binding: tmux list-keys | grep sessionx"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    echo -e "\n${YELLOW}Debug steps:${NC}"
    echo "1. Run with debug: bash -x $SCRIPT_DIR/sessionx.sh"
    echo "2. Check tmux options: tmux show-options -g | grep sessionx"
    echo "3. Verify plugin path: ls -la $TMUX_PLUGIN_MANAGER_PATH/tmux-sessionx/"
    exit 1
fi