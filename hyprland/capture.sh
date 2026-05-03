#!/usr/bin/env bash

ACTION=$1
IMG_DIR="$HOME/Pictures" # Changed from Images to standard Pictures
VID_DIR="$HOME/Videos"

# 1. STOP RECORDING LOGIC
if [ "$ACTION" == "record" ] && pgrep -x "wf-recorder" > /dev/null; then
    pkill -INT -x wf-recorder
    
    # Wait for file to close
    sleep 1 
    
    LATEST_VID=$(ls -t "$VID_DIR"/record_*.mp4 2>/dev/null | head -n 1)
    
    if [ -n "$LATEST_VID" ]; then
        notify-send -i video-x-generic -A "open=📂 Show" "⏺️ Recording Stopped" "Video saved to Videos" | xargs -I {} [ {} = "open" ] && dolphin --select "$LATEST_VID"
    fi
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

MONITORS=$(hyprctl monitors -j | jq -r '.[] | "\(.x),\(.y) \(.width)x\(.height)"')

# 4. Launch slurp
TARGET=$(printf "%s\n%s" "$WINDOWS" "$MONITORS" | slurp -b "#00000099" -c "#3498db" -w 2)

if [ -z "$TARGET" ]; then
    exit 0
fi

# 5. EXECUTE CAPTURE
if [ "$ACTION" == "screenshot" ]; then
    mkdir -p "$IMG_DIR"
    FILE="$IMG_DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"
    sleep 0.1 
    grim -g "$TARGET" "$FILE"
    wl-copy < "$FILE"
    notify-send -i "$FILE" -A "open=📂 Show" "📸 Screenshot Saved" "Copied to clipboard" | xargs -I {} [ {} = "open" ] && dolphin --select "$FILE"

elif [ "$ACTION" == "record" ]; then
    mkdir -p "$VID_DIR"
    FILE="$VID_DIR/record_$(date +%Y%m%d_%H%M%S).mp4"
    
    notify-send "⏺️ Recording Started" "Press shortcut again to stop."
    
    # wf-recorder options:
    # -g: geometry from slurp
    # -f: output file
    # -p: use specific pixel format (yuv420p is most compatible for playback)
    # -c: libx264 (Software encoding - extremely stable)
    wf-recorder -g "$TARGET" -f "$FILE" -p pixel_format=yuv420p -c libx264
fi