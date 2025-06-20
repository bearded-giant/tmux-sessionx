# Testing tmux-sessionx

## Automated Tests

Run the test suite:
```bash
bash test/run_tests.sh
```

This runs non-interactive tests that validate:
- Script syntax
- Function definitions
- Input validation
- Error handling
- Security measures

## Manual Testing

Since sessionx is an interactive tool, manual testing is important:

### 1. Basic Launch Test
1. Open tmux: `tmux`
2. Press `<prefix>o` (usually `Ctrl-b o`)
3. SessionX should open showing your sessions
4. Press `ESC` to close

### 2. Session Navigation
1. Open sessionx (`<prefix>o`)
2. Use arrow keys or `Ctrl-n`/`Ctrl-p` to navigate
3. Press `Enter` to switch to a session
4. Verify you switched to the correct session

### 3. Session Operations
1. Open sessionx
2. Select a session (don't press Enter)
3. Press `Ctrl-r` to rename
4. Enter new name and press Enter
5. Verify session was renamed

### 4. Kill Session
1. Create a test session: `tmux new -s test-session -d`
2. Open sessionx
3. Navigate to test-session
4. Press `Alt-Backspace` to kill it
5. Verify session was killed

### 5. Help System
1. Open sessionx
2. Press `Ctrl-h` or `?`
3. Verify help is displayed
4. Press `q` to exit help
5. Press `ESC` to close sessionx

### 6. Preview Toggle
1. Open sessionx
2. Press `?` to toggle preview
3. Verify preview appears/disappears

## Performance Testing

Check startup time:
```bash
time bash ~/.config/tmux/plugins/tmux-sessionx/scripts/sessionx.sh
```

Should start in under 500ms.

## Troubleshooting

If sessionx doesn't open:
1. Check keybinding: `tmux list-keys | grep sessionx`
2. Check installation: `ls -la ~/.config/tmux/plugins/tmux-sessionx/`
3. Reload tmux config: `tmux source ~/.config/tmux/tmux.conf`
4. Run directly: `bash ~/.config/tmux/plugins/tmux-sessionx/scripts/sessionx.sh`

## Test Coverage

The test suite covers:
- ✓ Syntax validation
- ✓ Function existence
- ✓ Input validation
- ✓ Security measures
- ✓ Error handling
- ✗ Interactive behavior (requires manual testing)
- ✗ fzf integration (requires manual testing)
- ✗ tmux integration (requires manual testing)