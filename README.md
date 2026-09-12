# Tmux SessionX (Enhanced Fork)

A fuzzy Tmux session manager with preview capabilities, deleting, renaming and more!

> **Note:** This is an enhanced standalone fork of the original [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) by omerxx. This version includes significant security improvements, performance optimizations, and additional features while maintaining compatibility with the original configuration.

![image](./img/sessionxv2.png)

## Prerequisits 🛠️

- [tpm](https://github.com/tmux-plugins/tpm)
- [fzf](https://github.com/junegunn/fzf)
- [fzf-tmux](https://github.com/junegunn/fzf#fzf-tmux-script)
- [bat](https://github.com/sharkdp/bat)
- Optional: [zoxide](https://github.com/ajeetdsouza/zoxide)

## Install 💻

Add this to your `.tmux.conf` and run `Ctrl-I` for TPM to install the plugin.

```conf
set -g @plugin 'bearded-giant/tmux-sessionx'
```

## Configure ⚙️

The default binding for this plugin is `<prefix>+O`
You can change it by adding this line with your desired key:

```bash
# I recommend using `o` if not already in use, for least key strokes when launching
set -g @sessionx-bind '<mykey>'
```

### Additional configuration options:

```bash
# `C-x` is a customizeable, by default it indexes directories in `$HOME/.config`,
# but this can be changed by adding the config below.
# e.g. set -g @sessionx-x-path '~/dotfiles'
set -g @sessionx-x-path '<some-path>'

# A comma delimited absolute-paths list of custom paths
# always visible in results and ready to create a session from.
# Tip: if you're using zoxide mode, there's a good chance this is redundant
set -g @sessionx-custom-paths '/Users/me/projects,/Users/me/second-brain'

# By default, the current session will not be shown on first view
# This is to support quick switch of sessions
# Only after other actions (e.g. rename) will the current session appear
# Setting this option to 'false' changes this default behavior
set -g @sessionx-filter-current 'false'

# Window mode can be turned on so that the default layout
# Has all the windows listed rather than sessions only
set -g @sessionx-window-mode 'on'

# Tree mode can be enabled which means that instead of a preview,
# a hierarchy of sessions and windows will be shown
set -g @sessionx-tree-mode 'on'

# Preview location and screenspace can be adjusted with these
# Available options: 'top' (default), 'bottom', 'right', 'left'
# Note: 'left' is automatically converted to 'right' for consistency
# Reminder: it can be toggled on/off with `?`
set -g @sessionx-preview-location 'right'

# For top/bottom preview: controls how much space the preview takes (session list gets the rest)
# For example, '75%' means preview takes 75%, session list takes 25%
# To get a longer session list with top/bottom preview, use a smaller ratio like '50%' or '40%'
set -g @sessionx-preview-ratio '75%'

# For right/left preview: controls how much space the SESSION LIST takes (preview gets the rest)
# For example, '35%' means session list takes 35%, preview takes 65%
# To get a longer session list with right/left preview, use a larger width like '50%' or '60%'
# This helps prevent session timestamps from being cut off
set -g @sessionx-list-pane-width '35%'

# The preview can also be disabled altogether
set -g @sessionx-preview-enabled 'false'

# Change window dimensions
set -g @sessionx-window-height '90%'
set -g @sessionx-window-width '75%'

# Sort order for session list
# 'default' - input at bottom, list grows downward, most recent sessions at top
# 'reverse' - input at top, list grows upward, most recent sessions at bottom (visually first)
# The plugin automatically adjusts the session order to ensure most recent sessions
# always appear first in the visual order regardless of this setting
set -g @sessionx-sort 'reverse'

# If you want to change the prompt, the space is nedded to not overlap the icon
set -g @sessionx-prompt " "

# If you want to change the pointer
set -g @sessionx-pointer "▶ "

# When set to 'on' a non-result will be sent to zoxide for path matching
# Requires zoxide installed
set -g @sessionx-zoxide-mode 'on'

# If you want to pass in your own FZF options. This is passed in before all other
# arguments to FZF to ensure that other options like `sessionx-pointer` and 
# `sessionx-window-height/width` still work. See `man fzf` for config options.
set -g @sessionx-additional-options "--color pointer:9,spinner:92,marker:46"

# If you're running fzf lower than 0.35.0 there are a few missing features
# Upgrade, or use this setting for support
set -g @sessionx-legacy-fzf-support 'on'

# Enable or disable preview pane scrolling (default 'true')
# When disabled, the scroll keybindings (ctrl-p/ctrl-d) will not be active
set -g @sessionx-enable-preview-scroll 'true'

# With Tmuxinaor turned 'on' (off by default), the plugin will take a given name
# and look for a tmuxinator project with that name. 
# If found, it'll launch the template using tmuxinator
set -g @sessionx-tmuxinator-mode 'off'

# Enable debug mode for troubleshooting issues
# Creates detailed logs at /tmp/sessionx-debug.log
set -g @sessionx-debug 'off'
```

## Working with SessionX 👷

Launching the plugin pops up an fzf-tmux "popup" with fuzzy search over existing sessions (-current session).
**Sessions are sorted by most recently used** - the sort order automatically adjusts based on your sort setting to ensure the most recent sessions always appear first visually.

Each row shows `name | last attached | window count | label`. The window count gets a `!` suffix when tmux has flagged activity or a bell in one of that session's windows (requires `set -g monitor-activity on` or `monitor-bell on` in your tmux config; the flag clears when you visit the window).

### Creating New Sessions
There are two ways to create a new session:
1. **Type and Enter**: Simply type a session name that doesn't exist and press Enter - a new session will be created
2. **Ctrl-s**: Press Ctrl-s to get a prompt for the new session name

### Key Enhancements in This Fork

- **Security**: Input validation for paths and session names, protection against command injection
- **Performance**: Batch loading of tmux options, intelligent caching to reduce IPC calls
- **Reliability**: Comprehensive error handling and graceful exit code management
- **Testing**: Full test suite including non-interactive tests (`bash test/run_tests.sh`)
- **Help System**: Enhanced help display with `?` showing all available keybindings
- **Session Sorting**: Sessions automatically sorted by last accessed time

- `Enter` on existing session: switch to that session
- `Enter` on typed text: create new session with that name
- `Ctrl-s` "session": prompt for a new session name and create it
- `Alt-d` will delete/kill the selected session
- `Ctrl-r` "rename": will launch a prompt to rename a session within the list
- `Tab` "pin": toggles a color highlight on the selected session so the few sessions you are actually working in stand out. Stored as a tmux session option, so it survives reopening sessionx and clears when the session is killed. Color is configurable with `@sessionx-pin-color` (ANSI SGR attributes, default `1;33` = bold yellow)
- `Shift-Tab` "pins": filters the list down to pinned sessions (use `Ctrl-b` to return to the full list)
- `Ctrl-l` "label": prompts for a short free-text label shown next to the session in the list (what you are doing there today). Empty input clears it. Stored as the tmux session option `@sessionx-label`
- `Ctrl-u` scroll preview up (when `@sessionx-enable-preview-scroll` is 'on')
- `Ctrl-d` scroll preview down (when `@sessionx-enable-preview-scroll` is 'on')
- `Ctrl-w` "window": will reload the list with all the available _windows_ and their preview
- `Ctrl-x` will fuzzy read `~/.config` or a configureable path of your choice (with `@session-x-path`)
- `Ctrl-e` "expand": will expand `PWD` and search for local directories to create additional session from
- `Ctrl-b` "back": reloads the first query. Useful when going into window or expand mode, to go back
- `Ctrl-t` "tree": shows the preview with the tree of sessions+windows familiar from the native session manager (use `Ctrl-b` to return to normal preview)
- `Ctrl-o` "panes": shows every pane of the selected session's active window stacked in the preview, active pane marked with `*` (use `Ctrl-b` to return to normal preview)
- `Ctrl-/` "tmuxinator": fetches a list of tmuxinator sessions and previews them
- `?` "help": displays a help screen with all keybindings in the preview pane (use `Ctrl-b` to return to normal preview)
- `Ctrl-p` toggles the preview pane

### Rebind keys:

If you want to change the default key bindings, you can do using this configuration options:

```bash
# Configuring Key Bindings:
# I've remapped these commands to 'alt'.
# To modify default key bindings, you can use these configuration options:

# This command is equivalent to the 'Enter' key.
set -g @sessionx-bind-accept 'alt-j'

# This command opens the current window list.
# By default, it is set to `ctrl-w`.
set -g @sessionx-bind-window-mode 'alt-s'

# This command opens the tree.
# By default, it is set to `ctrl-t`.
set -g @sessionx-bind-tree-mode 'alt-w'

# This command shows all panes of the active window in the preview.
# By default, it is set to `ctrl-o`.
set -g @sessionx-bind-panes-mode 'alt-p'

# This command opens the configuration path.
# By default, it is set to `ctrl-x`.
set -g @sessionx-bind-new-window 'alt-c'

# By default, it is set to `ctrl-r`.
set -g @sessionx-bind-rename-session 'alt-r'

# This command creates a new session.
# By default, it is set to `ctrl-s`.
set -g @sessionx-bind-new-session 'alt-n'

# This command rebinds scrolling up/down inside the preview.
set -g @sessionx-bind-scroll-up 'alt-m'
set -g @sessionx-bind-scroll-down 'alt-n'

# Sessionx Commands:
# These commands are used within sessionx when it's open.

# This command is equivalent to killing the selected session.
# This command kills the selected session.
# By default, it is set to `alt-d`.
set -g @sessionx-bind-kill-session 'alt-x'

# This command opens the configuration path.
set -g @sessionx-bind-configuration-path 'alt-e'

# This command goes back to the previous command.
set -g @sessionx-bind-back 'alt-h'

# These commands are bindings to select arrows.
set -g @sessionx-bind-select-up 'alt-l'
set -g @sessionx-bind-select-down 'alt-k'

# These commands are bindings to delete characters.
set -g @sessionx-bind-delete-char 'alt-p'

# These commands are bindings to exit sessionx.
set -g @sessionx-bind-abort 'alt-q'

# This command opens the tmuxinator list.
set -g @sessionx-bind-tmuxinator-list 'alt-t'

# This command toggles the pin highlight on the selected session.
# By default, it is set to `tab`.
set -g @sessionx-bind-pin 'alt-i'

# This command filters the list to pinned sessions only.
# By default, it is set to `btab` (shift-tab).
set -g @sessionx-bind-pinned-filter 'alt-o'

# This command sets a label on the selected session.
# By default, it is set to `ctrl-l`.
set -g @sessionx-bind-label 'alt-l'

# ANSI SGR attributes used to color pinned sessions. Default `1;33` (bold yellow).
set -g @sessionx-pin-color '1;35'

# This command toggles the preview pane.
# By default, it is set to `ctrl-p`.
set -g @sessionx-bind-toggle-preview 'alt-v'

# This command opens the help screen.
# By default, it is set to `?`.
set -g @sessionx-bind-help 'alt-h'
```

## [Tmuxinator](https://github.com/tmuxinator/tmuxinator) Integration 🚀

If you want sessionx to detect existing tmuxinator projects, you can set a `sessionx-tmuxinator-mode` in your config (see snippet below). 
With Tmuxinaor turned 'on' (off by default), the plugin will take a given name and look for a tmuxinator project with that name. If found, it'll **launch the template using tmuxinator**!.
There's also a binding to list tmuxinator projects, defaulting to `Ctrl-/`, configurable via:
```bash
# Tmuxinator mode on
set -g @sessionx-tmuxinator-mode 'on'

# Changing the binding from the default Ctrl-/
set -g @sessionx-bind-tmuxinator-list 'alt-t'
```


## Testing 🧪

This fork includes a comprehensive test suite:

```bash
# Run all tests
bash test/run_tests.sh

# Run non-interactive tests only
bash test/test_non_interactive.sh
```

For manual testing instructions, see [TESTING.md](./TESTING.md).

## Troubleshooting 🔍

### Debug Mode

If you're experiencing issues with SessionX (e.g., sessions not switching, deletion not working), enable debug mode to get detailed logs:

```bash
# Enable debug logging
set -g @sessionx-debug 'on'
```

After enabling debug mode:
1. Reload your tmux configuration: `prefix + r` (or `tmux source-file ~/.config/tmux/tmux.conf`)
2. Use SessionX and reproduce the issue
3. Check the debug log: `cat /tmp/sessionx-debug.log`

The debug log includes:
- Session detection and parsing
- Key binding captures
- fzf exit codes
- Session name extraction for switching/deletion/renaming
- Any errors that occur

### Common Issues

**Sessions not switching:**
- Check if session names contain special characters
- Verify the session exists: `tmux list-sessions`
- Enable debug mode and check what session name is being extracted

**Delete (alt-d) not working:**
- Some terminals may not pass alt+backspace correctly
- Try setting a different binding: `set -g @sessionx-bind-kill-session 'ctrl-x'`
- Check debug logs to see if the key press is being captured

**Modal closes instead of performing action:**
- This usually indicates the command failed
- Check debug logs for error messages
- Verify tmux permissions and that sessions aren't attached elsewhere

## WARNING ⚠️

- If you're running `fzf` lower than [0.35.0](https://github.com/junegunn/fzf/releases/tag/0.35.0) there are a few missing missing features that might break the plugin. Either consider upgrading or add `@sessionx-legacy-fzf-support 'on'` to your config (see [configuration](#additional-configuration-options))
- This plugin is not designed to be used outside Tmux, although PRs are happily recieved!

## Development Notes 📝

This fork is maintained as a standalone project with a focus on:
- Security and reliability improvements
- Performance optimizations
- Enhanced user experience
- Comprehensive testing

Future development will continue to streamline session management while maintaining backward compatibility where possible.

## Thanks ❤️

Based on the original [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) by omerxx.

Inspired by these:

- https://github.com/joshmedeski/t-smart-tmux-session-manager
- https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer
- https://crates.io/crates/tmux-sessionizer
- https://github.com/petobens/dotfiles/commit/c21c306660142d93d283186210ad9d301a2f5186

## Contributors

<a href="https://github.com/omerxx/tmux-sessionx/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=omerxx/tmux-sessionx" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
