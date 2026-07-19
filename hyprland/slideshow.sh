#!/usr/bin/env bash

# Directory containing your wallpapers
WALLPAPER_DIR="$HOME/Pictures/wallpaper"

# Start awww-daemon if it isn't running already (using -f for NixOS store-path robustness)
if ! pgrep -f "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

# Function to rotate the wallpaper and update color schemes
rotate_wallpaper() {
    # Pick a random image from the folder
    local wallpaper
    wallpaper=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)

    if [ -z "$wallpaper" ]; then
        echo "No images found in $WALLPAPER_DIR"
        return 1
    fi

    # 1. Update wallpaper via awww with a smooth visual transition
    awww img "$wallpaper" \
        --transition-type grow \
        --transition-pos top-right \
        --transition-duration 2.5 \
        --transition-fps 60

    # 2. Extract colors and write config files
    # We pass --source-color-index 0 to skip the interactive selection prompt
    matugen image "$wallpaper" --source-color-index 0

    # 3. Request Waybar to soft-reload its styles
    pkill -SIGUSR2 waybar

    # 4. Refresh Hyprland config (updates active border colors dynamically)
    hyprctl reload
}

# Run the rotation instantly, then loop every 30 minutes (1800 seconds)
while true; do
    rotate_wallpaper
    sleep 1800
done