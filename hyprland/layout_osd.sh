#!/usr/bin/env bash

# Wait for Hyprland to fully initialize
sleep 2

# We use the primary color from your colors config
COLOR="rgba(d6bbfbee)"

# Function to trigger the visual-only, non-interactive Hyprland notification
show_notification() {
    local layout=$1
    # hyprctl notify format: <icon> <time_ms> <color> <message>
    # icon -1 means no icon, creating a clean text banner.
    hyprctl notify -1 3500 "$COLOR" " ⌨️  Keyboard Layout: $layout  (Switch: Super + Space) "
}

# 1. Show the current layout right after you log in
CURRENT_LAYOUT=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n 1)
if [ -n "$CURRENT_LAYOUT" ]; then
    show_notification "$CURRENT_LAYOUT"
fi

# 2. Listen to Hyprland's IPC socket for future layout changes
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR"/hypr/"$HYPRLAND_INSTANCE_SIGNATURE"/.socket2.sock | while read -r line; do
    if [[ $line == activelayout* ]]; then
        # Extract the layout name (Format: activelayout>>keyboard-name,Layout Name)
        LAYOUT=$(echo "$line" | awk -F',' '{print $2}')
        show_notification "$LAYOUT"
    fi
done