# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

tmux-sessionx is a fuzzy tmux session manager with preview capabilities. This is an enhanced fork with security improvements, performance optimizations, and comprehensive testing. The plugin integrates with tmux via TPM (Tmux Plugin Manager) and uses fzf for interactive fuzzy selection.

## Core Architecture

### Entry Points
- `sessionx.tmux` - TPM plugin entry point that sets up keybindings and loads configuration
- `scripts/sessionx.sh` - Main script that runs the fzf interface and handles session operations

### Script Organization
- `scripts/common.sh` - Shared utility functions (validation, tmux option handling)
- `scripts/preview.sh` - Generates previews of sessions/windows for fzf
- `scripts/reload-sessions.sh` - Reloads session list (used after operations like delete/rename)
- `scripts/kill-session.sh` - Helper script for deleting sessions
- `scripts/help.sh` - Displays help screen with keybindings
- `scripts/tmuxinator.sh` - Tmuxinator integration
- `scripts/fzf-marks.sh` - fzf-marks integration

### Key Design Patterns

**Options Caching**: `sessionx.sh` uses `TMUX_OPTIONS_CACHE` associative array to batch-load all tmux options once, avoiding repeated IPC calls. Use `cached_tmux_option()` instead of calling tmux directly.

**Input Validation**: All user input (session names, paths) is validated via `validate_session_name()` and `validate_path()` in `scripts/common.sh` to prevent command injection.

**Delimiter Format**: Sessions are displayed with fixed-width formatting: `"%-${name_width}s | %s"` where the first field is the session name and second is the timestamp. The delimiter ` | ` is used to parse session names from fzf output.

**Debug Mode**: When `@sessionx-debug` is `on`, all operations log to `/tmp/sessionx-debug.log` with timestamps. Use `debug_log()` function.

## Development Commands

### Testing
```bash
# Run all non-interactive tests
bash test/run_tests.sh

# Run specific test file
bash test/test_non_interactive.sh
bash test/test_session_deletion.sh
bash test/test_session_names.sh
```

### Manual Testing in tmux
```bash
# Reload tmux config to pick up changes
tmux source-file ~/.config/tmux/tmux.conf

# Run sessionx directly without keybinding
bash scripts/sessionx.sh

# Enable debug mode in tmux config
set -g @sessionx-debug 'on'
# Then check logs
cat /tmp/sessionx-debug.log
```

### Installation/Reinstallation
```bash
# Reinstall plugin to TPM directory
./reinstall.sh
```

## Critical Implementation Details

### Session Name Extraction
When extracting session names from fzf output in `handle_output()`:
1. Strip all leading/trailing whitespace including newlines
2. Check for delimiter format ` | `
3. Extract text before delimiter: `${raw_output%% | *}`
4. Trim trailing spaces from fixed-width formatting
5. Validate with `validate_session_name()`

### Sort Order Logic
The `@sessionx-sort` setting controls visual layout:
- `default`: input at bottom, list grows downward → needs `-n` (ascending) sort for newest first
- `reverse`: input at top, list grows upward → needs `-rn` (descending) sort for newest first
Sessions are always sorted by `#{session_last_attached}` timestamp.

### Preview Size Configuration
Two different options control preview vs list sizing depending on preview location:

**For side previews (right/left):**
- `@sessionx-list-pane-width` controls the SESSION LIST width (default: 35%)
- Preview gets the remaining space (e.g., 35% list = 65% preview)
- To show more sessions: increase this value (e.g., '50%' or '60%')
- Use narrower name column (20 chars) to prevent timestamp cutoff

**For top/bottom previews:**
- `@sessionx-preview-ratio` controls the PREVIEW size (default: 75%)
- Session list gets the remaining space (e.g., 75% preview = 25% list)
- To show more sessions: decrease this value (e.g., '50%' or '40%')
- Use wider name column (30 chars) for better readability

Note: 'left' is automatically converted to 'right' for UX consistency

### fzf Bindings Structure
All interactive operations use fzf bindings:
- `execute-silent()`: Run command without showing output (e.g., delete)
- `reload()`: Refresh the session list (used after delete/rename/new)
- `change-preview()`: Switch preview mode (tree/window/help)
- `replace-query+print-query`: For the accept action (Enter key)

The `--bind` format: `"key:action1+action2"`

## Common Patterns

### Adding New Keybindings
1. Add tmux option in `load_tmux_options()` with default value
2. Load in `handle_binds()` via `cached_tmux_option()`
3. Create the binding action in `handle_args()`
4. Add to `args` array in `handle_args()`
5. Document in README.md configuration section

### Adding New Operations
1. Create helper script in `scripts/` if complex logic needed
2. Use `execute-silent()` for operations that modify state
3. Chain with `reload()` to refresh the list
4. Add debug logging: `debug_log "operation: details"`
5. Validate all inputs with functions from `common.sh`

### Session List Formatting
Always use this pattern for session lists with timestamps:
```bash
tmux list-sessions -F '#{session_last_attached}|#{session_name}' | \
  sort $sort_order -t'|' -k1 | \
  while IFS='|' read -r timestamp name; do
    formatted_time=$(date -r "$timestamp" "+%b %d %H:%M" 2>&1 || echo "Unknown")
    printf "%-${name_width}s | %s\n" "$name" "$formatted_time"
  done
```

**Important:** The fixed-width formatting (`%-${name_width}s`) adds trailing spaces to session names. The preview script (`scripts/preview.sh`) automatically trims these trailing spaces before looking up sessions. Any script that receives session names from fzf's `{1}` field should also trim trailing spaces.

## Security Considerations

- All session names validated via regex in `validate_session_name()` - only allows alphanumeric, dash, underscore, dot, and spaces
- Paths validated to reject `..` and leading `-` to prevent traversal and flag injection
- CONFIGURATION_PATH is validated as existing directory before use in find command
- Shell interpolation minimized; prefer quoted variables
- Debug mode logs to temporary file with predictable path

## Performance Notes

- Options caching reduces tmux IPC calls from ~40 to 1
- Session list sorted once in shell rather than multiple tmux calls
- Preview scripts should complete in <100ms for responsive UX
- Batch tmux operations when possible (e.g., `show-options -gq` once)

## Testing Philosophy

Tests validate:
- Bash syntax and function definitions
- Input validation edge cases
- Security measures (injection prevention)
- Error handling and graceful failures

Interactive behavior (fzf integration, actual tmux operations) requires manual testing per TESTING.md.
