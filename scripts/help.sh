#!/usr/bin/env bash
cat << 'EOF'
╭─────────────────────────────────────────────────────────────────────────╮
│                        SessionX Keybindings Help                        │
├─────────────────────────────────────────────────────────────────────────┤
│ Navigation                                                              │
│ ─────────────────────────────────────────────────────────────────────── │
│ ↑/↓ or C-n/C-m   Navigate list                                          │
│ Enter            Open selected session/window                           │
│ Esc              Exit SessionX                                          │
│ Alt-h            Show this help screen                                  │
│                                                                         │
│ Session Management                                                      │
│ ─────────────────────────────────────────────────────────────────────── │
│ Alt-d            Kill/delete selected session                           │
│ Ctrl-r           Rename selected session                                │
│                                                                         │
│ View Modes                                                              │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-w           Switch to window mode (list all windows)               │
│ Ctrl-t           Show tree preview (use Ctrl-b to go back)              │
│ Ctrl-/           Show tmuxinator templates                              │
│ Ctrl-e           Expand current directory for new sessions              │
│ Ctrl-x           Browse configuration directory                         │
│ Ctrl-b           Go back to session list                                │
│                                                                         │
│ Preview Controls                                                        │
│ ─────────────────────────────────────────────────────────────────────── │
│ ?                Toggle preview pane on/off                             │
│ Ctrl-p           Scroll preview up (if enabled in config)               │
│ Ctrl-f           Scroll preview down (if enabled in config)             │
│                                                                         │
│ Sorting                                                                 │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-s           Sort list ascending                                    │
│ Ctrl-a           Sort list descending                                   │
│                                                                         │
│ Tips                                                                    │
│ ─────────────────────────────────────────────────────────────────────── │
│ • Type a new name and press Enter to create a new session               │
│ • With zoxide enabled, non-existing paths will be searched              │
│ • Custom paths from config are shown with ✗ replacing spaces            │ 
│                                                                         │
│ Press Ctrl-b to return to session preview                              │
╰─────────────────────────────────────────────────────────────────────────╯
EOF

