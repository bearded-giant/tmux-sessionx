#!/usr/bin/env bash
# Common test helper functions

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Cleanup function to remove test sessions
cleanup_test_sessions() {
    local prefix="${1:-test-}"
    tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${prefix}" | while read -r session; do
        tmux kill-session -t "$session" 2>/dev/null || true
    done
}