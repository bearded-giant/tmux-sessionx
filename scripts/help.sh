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
│ ?                Show this help screen                                  │
│                                                                         │
│ Session Management                                                      │
│ ─────────────────────────────────────────────────────────────────────── │
│ Alt-d            Kill/delete selected session                           │
│ Ctrl-r           Rename selected session                                │
│ Tab              Toggle pin highlight on selected session               │
│ Shift-Tab        Show only pinned sessions (Ctrl-b to go back)          │
│ Ctrl-l           Set a one-line label on selected session               │
│                                                                         │
│ View Modes                                                              │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-w           Switch to window mode (list all windows)               │
│ Ctrl-t           Show tree preview (use Ctrl-b to go back)              │
│ Ctrl-o           Show all panes of active window (Ctrl-b to go back)    │
│ Ctrl-/           Show tmuxinator templates                              │
│ Ctrl-e           Expand current directory for new sessions              │
│ Ctrl-x           Browse configuration directory                         │
│ Ctrl-b           Go back to session list                                │
│                                                                         │
│ Preview Controls                                                        │
│ ─────────────────────────────────────────────────────────────────────── │
│ Ctrl-p           Toggle preview pane on/off                             │
│ Ctrl-u           Scroll preview up (if enabled in config)               │
│ Ctrl-d           Scroll preview down (if enabled in config)             │
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

