#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/scripts/common.sh"

tmux bind-key "$(tmux_option_or_fallback "@sessionx-bind" "O")" run-shell "$CURRENT_DIR/scripts/sessionx.sh"
