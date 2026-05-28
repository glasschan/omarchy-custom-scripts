#!/bin/bash
# elephant-clipboard-activate.sh
# Bridges walker clipboard selection to elephant's activate command
# This enables auto-paste when selecting items from walker's clipboard provider

# Elephant's clipboard command is configured in ~/.config/elephant/clipboard.toml
# It runs: wl-copy && hyprctl dispatch sendshortcut "SHIFT, Insert,"
# But walker's clipboard "copy" action never triggers elephant's activation.
# This script calls elephant activate via IPC to run the configured command.

CONTENT="$1"

if [ -z "$CONTENT" ]; then
    wl-copy && hyprctl dispatch sendshortcut "SHIFT,Insert,activewindow"
else
    echo -n "$CONTENT" | wl-copy && hyprctl dispatch sendshortcut "SHIFT,Insert,activewindow"
fi
