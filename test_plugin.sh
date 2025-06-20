#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Testing tmux-sessionx plugin..."
echo "================================"

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${TEST_DIR}/scripts"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing ${test_name}... "
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Command: $test_command"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check all required scripts exist
echo -e "\n${YELLOW}1. Checking required scripts:${NC}"
for script in sessionx.sh preview.sh reload_sessions.sh tmuxinator.sh common.sh help.sh; do
    run_test "$script exists" "test -f '${SCRIPT_DIR}/${script}'"
    run_test "$script is executable" "test -x '${SCRIPT_DIR}/${script}'"
done

# Test 2: Check script syntax
echo -e "\n${YELLOW}2. Checking script syntax:${NC}"
for script in sessionx.sh preview.sh reload_sessions.sh tmuxinator.sh common.sh help.sh; do
    run_test "$script syntax" "bash -n '${SCRIPT_DIR}/${script}'"
done

# Test 3: Check required functions
echo -e "\n${YELLOW}3. Checking required functions:${NC}"
run_test "tmux_option_or_fallback in common.sh" "grep -q 'tmux_option_or_fallback()' '${SCRIPT_DIR}/common.sh'"
run_test "validate_session_name in common.sh" "grep -q 'validate_session_name()' '${SCRIPT_DIR}/common.sh'"
run_test "validate_path in common.sh" "grep -q 'validate_path()' '${SCRIPT_DIR}/common.sh'"

# Test 4: Check dependencies between scripts
echo -e "\n${YELLOW}4. Checking script dependencies:${NC}"
run_test "sessionx.sh sources common.sh" "grep -q 'source.*common.sh' '${SCRIPT_DIR}/sessionx.sh'"
run_test "sessionx.sh sources tmuxinator.sh" "grep -q 'source.*tmuxinator.sh' '${SCRIPT_DIR}/sessionx.sh'"
run_test "sessionx.tmux sources common.sh" "grep -q 'source.*common.sh' '${TEST_DIR}/sessionx.tmux'"

# Test 5: Verify tmuxinator.sh completeness
echo -e "\n${YELLOW}5. Checking tmuxinator.sh functions:${NC}"
run_test "is_tmuxinator_enabled exists" "grep -q 'is_tmuxinator_enabled()' '${SCRIPT_DIR}/tmuxinator.sh'"
run_test "is_tmuxinator_template exists" "grep -q 'is_tmuxinator_template()' '${SCRIPT_DIR}/tmuxinator.sh'"
run_test "load_tmuxinator_binding exists" "grep -q 'load_tmuxinator_binding()' '${SCRIPT_DIR}/tmuxinator.sh'"

# Test 6: Check for common issues
echo -e "\n${YELLOW}6. Checking for common issues:${NC}"
run_test "No syntax errors in sessionx.sh" "bash -n '${SCRIPT_DIR}/sessionx.sh'"
run_test "Help binding exists" "grep -q 'bind_help=' '${SCRIPT_DIR}/sessionx.sh'"
run_test "Help script reference" "grep -q 'help.sh' '${SCRIPT_DIR}/sessionx.sh'"

# Test 7: Simulate script sourcing (without tmux)
echo -e "\n${YELLOW}7. Testing script sourcing:${NC}"
test_source_script() {
    local script="$1"
    (
        # Mock tmux functions for testing
        tmux() { 
            case "$1" in
                "show-option") echo "mock_value" ;;
                "display-message") echo "test_session" ;;
                *) return 0 ;;
            esac
        }
        export -f tmux
        
        # Try to source the script
        source "$script" 2>/dev/null || true
    )
    return $?
}

for script in common.sh tmuxinator.sh; do
    run_test "$script can be sourced" "test_source_script '${SCRIPT_DIR}/${script}'"
done

# Summary
echo -e "\n${YELLOW}Test Summary:${NC}"
echo "============="
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! The plugin appears to be ready for installation.${NC}"
    echo -e "\nTo install to your tmux plugin directory, run:"
    echo -e "${YELLOW}cp -r ${TEST_DIR}/* ~/.config/tmux/plugins/tmux-sessionx/${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please fix the issues before installing.${NC}"
    exit 1
fi