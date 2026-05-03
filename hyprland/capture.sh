#!/usr/bin/env bash

ACTION=$1

# Define your target directories
IMG_DIR="$HOME/Images"
VID_DIR="$HOME/Videos"

# 1. STOP RECORDING LOGIC
if [ "$ACTION" == "record" ] && pgrep -x "wl-screenrec" > /dev/null; then
    pkill -INT -x wl-screenrec
    
    # Give the video file a second to finish writing to disk
    sleep 1 
    
    # Find the most recent recording
    LATEST_VID=$(ls -t "$VID_DIR"/record_*.mp4 2>/dev/null | head -n 1)
    
    # Run notification in background
    (
        if [ -n "$LATEST_VID" ]; then
            CHOICE=$(notify-send -A "open=📂 Show in Dolphin" "⏺️ Recording Stopped" "Video saved to Videos")
            if [ "$CHOICE" == "open" ]; then
                hyprctl dispatch exec "dolphin --select '$LATEST_VID'"
            fi
        else
            CHOICE=$(notify-send -A "open=📂 Open Videos Folder" "⏺️ Recording Stopped" "Video saved to Videos")
            if [ "$CHOICE" == "open" ]; then
                hyprctl dispatch exec "dolphin '$VID_DIR'"
            fi
        fi
    ) &
    exit 0
fi

# 2. Get active workspace and border size
BORDER_SIZE=$(hyprctl getoption general:border_size -j | jq '.int')
ACTIVE_WS=$(hyprctl activeworkspace -j | jq '.id')

# 3. Get coordinates of visible windows ONLY on the active workspace
WINDOWS=$(hyprctl clients -j | jq -r \
    --argjson b "$BORDER_SIZE" \
    --argjson ws "$ACTIVE_WS" \
    '.[] | select(.mapped == true and .workspace.id == $ws) | "\(.at[0] + $b),\(.at[1] + $b) \(.size[0] - ($b*2))x\(.size[1] - ($b*2))"')

# 4. Get monitor coordinates
MONITORS=$(hyprctl monitors -j | jq -r '.[] | "\(.x),\(.y) \(.width)x\(.height)"')

# 5. Launch slurp
TARGET=$(printf "%s\n%s" "$WINDOWS" "$MONITORS" | slurp -b "#00000099" -c "#3498db" -w 2)

if [ -z "$TARGET" ]; then
    exit 0
fi

# 6. EXECUTE CAPTURE
if [ "$ACTION" == "screenshot" ]; then
    mkdir -p "$IMG_DIR"
    FILE="$IMG_DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"
    
    sleep 0.2 
    
    grim -g "$TARGET" "$FILE"
    wl-copy < "$FILE"
    
    (
        CHOICE=$(notify-send -i "$FILE" -A "open=📂 Show in Dolphin" "📸 Screenshot Saved" "Saved to ~/Images and copied to clipboard.")
        if [ "$CHOICE" == "open" ]; then
            hyprctl dispatch exec "dolphin --select '$FILE'"
        fi
    ) &

elif [ "$ACTION" == "record" ]; then
    mkdir -p "$VID_DIR"
    FILE="$VID_DIR/record_$(date +%Y%m%d_%H%M%S).mp4"
    
    notify-send "⏺️ Recording Started" "Press your recording shortcut again to stop."
    
    # Use --no-hw to bypass the GPU crash and force software encoding
    wl-screenrec --no-hw -g "$TARGET" -f "$FILE"
fi