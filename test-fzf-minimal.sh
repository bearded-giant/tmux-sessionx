#!/usr/bin/env bash
set -euo pipefail

echo "Testing fzf with minimal options..."

# Test 1: Basic fzf
echo -e "session1\nsession2\nsession3" | fzf-tmux --exit-0 --print-query
echo "Exit code: $?"

# Test 2: With delimiter
echo -e "session1 | time1\nsession2 | time2" | fzf-tmux --exit-0 --print-query --delimiter ' | '
echo "Exit code: $?"