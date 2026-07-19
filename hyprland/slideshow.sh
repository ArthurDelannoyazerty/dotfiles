#!/usr/bin/env bash

# Directory containing your wallpapers
WALLPAPER_DIR="$HOME/Pictures/wallpaper"
LOCKFILE="/tmp/slideshow.lock"

# --- 1. Robust Single-Instance Check using Lockfile ---
if [ -f "$LOCKFILE" ]; then
    DAEMON_PID=$(cat "$LOCKFILE" 2>/dev/null)
    # Check if the process in the lockfile is actually active
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        # Send signal to the running daemon and exit the duplicate process
        kill -USR1 "$DAEMON_PID"
        exit 0
    fi
fi

# Write current PID to the lockfile to claim the daemon role
echo "$$" > "$LOCKFILE"

# Clean up lockfile if the daemon exits cleanly
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

# --- 2. Daemon Setup ---
if ! pgrep -f "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

# Global variable to track the active sleep process
SLEEP_PID=""

rotate_wallpaper() {
    # If a sleep process is currently running, terminate it so it doesn't leak
    if [ -n "$SLEEP_PID" ]; then
        kill "$SLEEP_PID" 2>/dev/null
    fi

    # Pick a random image from the folder
    local wallpaper
    wallpaper=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)

    if [ -z "$wallpaper" ]; then
        echo "No images found in $WALLPAPER_DIR"
        return 1
    fi

    # Update wallpaper
    awww img "$wallpaper" \
        --transition-type grow \
        --transition-pos top-right \
        --transition-duration 2.5 \
        --transition-fps 60

    # Extract colors
    matugen image "$wallpaper" --source-color-index 0

    # Reload UI components
    pkill -SIGUSR2 waybar
    hyprctl reload
}

# Register signal handler to trigger rotation
trap 'rotate_wallpaper' USR1

# Run the initial rotation
rotate_wallpaper

# --- 3. Interruptible Loop ---
while true; do
    # Run sleep in background and store its process ID
    sleep 1800 &
    SLEEP_PID=$!
    
    # Wait for the background sleep to finish or get interrupted
    wait "$SLEEP_PID"
done