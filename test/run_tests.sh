#!/usr/bin/env bash
set -euo pipefail

# Main test runner for tmux-sessionx

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "tmux-sessionx Test Suite"
echo "======================================"
echo

# Run non-interactive tests
echo -e "${BLUE}Running non-interactive tests...${NC}"
if bash "$TEST_DIR/test_non_interactive.sh"; then
    echo -e "${GREEN}✓ Non-interactive tests passed${NC}\n"
else
    echo -e "${RED}✗ Non-interactive tests failed${NC}\n"
    exit 1
fi

# Note about interactive tests
echo -e "${YELLOW}Note: Interactive tests skipped${NC}"
echo "To test sessionx interactively:"
echo "1. Open tmux"
echo "2. Press <prefix>o (usually Ctrl-b o)"
echo "3. Press ESC or Ctrl-C to close"
echo
echo "If it doesn't work:"
echo "- Check binding: tmux list-keys | grep sessionx"
echo "- Reload config: tmux source ~/.config/tmux/tmux.conf"
echo "- Check path: ls -la ~/.config/tmux/plugins/tmux-sessionx/"

exit 0