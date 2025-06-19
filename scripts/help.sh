#!/usr/bin/env bash

# Generate help text for sessionx keybindings
cat << 'EOF'
╭─────────────────────────────────────────────────────────────────────────╮
│                        SessionX Keybindings Help                        │
├─────────────────────────────────────────────────────────────────────────┤
│ Navigation                                                              │
│ ─────────────────────────────────────────────────────────────────────── │
│ ↑/↓ or C-n/C-m   Navigate list                                         │
│ Enter            Open selected session/window                           │
│ Esc              Exit SessionX                                          │
│                                                                         │
│ Session Management                                                      │
│ ─────────────────────────────────────────────────────────────────────── │
│ Alt+Backspace    Kill selected session                                  │
│ Ctrl-r           Rename selected session                                │
│                                                                         │
│ View Modes                                                              │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-w           Switch to window mode (list all windows)              │
│ Ctrl-t           Switch to tree mode (hierarchical view)               │
│ Ctrl-/           Show tmuxinator templates                              │
│ Ctrl-e           Expand current directory for new sessions              │
│ Ctrl-x           Browse configuration directory                        │
│ Ctrl-b           Go back to session list                               │
│                                                                         │
│ Preview Controls                                                        │
│ ─────────────────────────────────────────────────────────────────────── │
│ ?                Toggle preview pane on/off                             │
│ Ctrl-p           Scroll preview up                                      │
│ Ctrl-d           Scroll preview down                                    │
│                                                                         │
│ Sorting                                                                 │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-u           Sort list ascending                                    │
│ Ctrl-d           Sort list descending                                   │
│                                                                         │
│ Tips                                                                    │
│ ─────────────────────────────────────────────────────────────────────── │
│ • Type a new name and press Enter to create a new session              │
│ • With zoxide enabled, non-existing paths will be searched             │
│ • Custom paths from config are shown with ✗ replacing spaces           │
│                                                                         │
│ Press any key to return...                                              │
╰─────────────────────────────────────────────────────────────────────────╯
EOF