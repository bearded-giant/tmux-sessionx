#!/usr/bin/env bash
set -euo pipefail

# Test session name handling, especially with spaces

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test directory setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_DIR="$PROJECT_DIR/scripts"

echo "Testing Session Name Handling"
echo "============================"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

test_session_name() {
    local name="$1"
    local expected="$2"
    local test_desc="$3"
    
    echo -n "Testing $test_desc... "
    if validate_session_name "$name"; then
        if [[ "$expected" == "pass" ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAILED${NC} (expected to fail but passed)"
            ((TESTS_FAILED++))
        fi
    else
        if [[ "$expected" == "fail" ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAILED${NC} (expected to pass but failed)"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test various session names
test_session_name "simple-session" "pass" "simple session with dashes"
test_session_name "my_session_123" "pass" "session with underscores and numbers"
test_session_name "project.dev" "pass" "session with dots"
test_session_name "configs and things" "pass" "session with spaces"
test_session_name "my awesome project" "pass" "session with multiple spaces"
test_session_name "test-123_abc.xyz" "pass" "session with mixed valid chars"

# These should fail (dangerous characters)
test_session_name "bad;command" "fail" "session with semicolon"
test_session_name "bad|pipe" "fail" "session with pipe"
test_session_name "bad&background" "fail" "session with ampersand"
test_session_name "bad\$variable" "fail" "session with dollar sign"
test_session_name "bad\`backtick\`" "fail" "session with backticks"
test_session_name "bad>redirect" "fail" "session with redirect"

# Test delimiter parsing with fixed-width formatting
echo -e "\nTesting delimiter format parsing..."
test_output="configs and things      | Jan 15 14:28"
target="${test_output%% | *}"
# Trim trailing spaces
target="$(echo "$target" | sed 's/[[:space:]]*$//')"
if [[ "$target" == "configs and things" ]]; then
    echo -e "${GREEN}PASSED${NC} - Correctly extracted session name with spaces"
    ((TESTS_PASSED++))
else
    echo -e "${RED}FAILED${NC} - Got '$target' instead of 'configs and things'"
    ((TESTS_FAILED++))
fi

# Summary
echo
echo "========================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All session name tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi