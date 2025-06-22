#!/usr/bin/env bash
set -euo pipefail

echo "==================================="
echo "tmux-sessionx Clean Reinstall"
echo "==================================="

# Get the plugin path
PLUGIN_PATH="${HOME}/.config/tmux/plugins/tmux-sessionx"
TPM_PATH="${HOME}/.config/tmux/plugins/tpm"

echo "1. Clearing tmux option cache..."
tmux set-option -gu @sessionx-_built-args 2>/dev/null || true
tmux set-option -gu @sessionx-_built-extra-options 2>/dev/null || true

echo "2. Removing existing plugin installation..."
if [ -d "$PLUGIN_PATH" ]; then
    rm -rf "$PLUGIN_PATH"
    echo "   Removed: $PLUGIN_PATH"
else
    echo "   Plugin directory not found (already clean)"
fi

echo "3. Installing fresh copy from current directory..."
# Get the current directory (where this script is)
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy to plugin directory
mkdir -p "$(dirname "$PLUGIN_PATH")"
cp -r "$CURRENT_DIR" "$PLUGIN_PATH"
echo "   Installed to: $PLUGIN_PATH"

echo "4. Making scripts executable..."
chmod +x "$PLUGIN_PATH"/*.tmux
chmod +x "$PLUGIN_PATH"/scripts/*.sh
chmod +x "$PLUGIN_PATH"/test/*.sh

echo "5. Reloading tmux configuration..."
tmux source-file ~/.config/tmux/tmux.conf || echo "   Note: Reload tmux config manually if this failed"

echo
echo "==================================="
echo "Reinstall complete!"
echo "==================================="
echo
echo "Test the plugin:"
echo "1. Press your sessionx binding (default: prefix + o)"
echo "2. Try alt-d to delete a session"
echo "3. Try Enter to switch sessions"
echo
echo "If bindings don't work, try:"
echo "- Exit and restart tmux completely"
echo "- Run: tmux kill-server && tmux"