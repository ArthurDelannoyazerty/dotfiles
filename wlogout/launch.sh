#!/usr/bin/env bash
set -euo pipefail


CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
MENU="${1:-main}"
LOCK_REQUEST="${2:-}"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/wlogout-${UID}.lock"

case "$LOCK_REQUEST" in
    "")
        # Normal shortcut invocation: exit immediately if a menu exists.
        FLOCK_ARGS=(
            --nonblock
            --close
            --conflict-exit-code 0
        )
        ;;
    --wait)
        # Internal menu transition: wait for the previous menu to close.
        FLOCK_ARGS=(
            --wait 2
            --close
            --conflict-exit-code 0
        )
        ;;
    *)
        printf 'Unknown lock option: %s\n' "$LOCK_REQUEST" >&2
        exit 2
        ;;
esac



case "$MENU" in
    main)
        LAYOUT="$CONFIG_DIR/layout"
        ;;
    other)
        LAYOUT="$CONFIG_DIR/layout-other"
        ;;
    *)
        printf 'Unknown wlogout menu: %s\n' "$MENU" >&2
        exit 2
        ;;
esac

for command_name in wlogout hyprctl jq flock; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 127
    fi
done

if [[ ! -r "$LAYOUT" ]]; then
    printf 'Layout not readable: %s\n' "$LAYOUT" >&2
    exit 1
fi

if [[ ! -r "$CONFIG_DIR/style.css" ]]; then
    printf 'Stylesheet not readable: %s\n' "$CONFIG_DIR/style.css" >&2
    exit 1
fi

MONITORS_JSON="$(hyprctl -j monitors)"

MONITOR_JSON="$(
    jq -ce '
        map(select(.focused == true))[0]
        // .[0]
        // error("Hyprland reported no monitors")
    ' <<<"$MONITORS_JSON"
)"

# Wlogout expects a zero-based monitor number rather than a Hyprland monitor ID.
MONITOR_INDEX="$(
    jq -r '
        to_entries
        | map(select(.value.focused == true))[0].key
        // 0
    ' <<<"$MONITORS_JSON"
)"

MONITOR_WIDTH="$(
    jq -r '
        (.scale // 1) as $scale
        | ((.width / $scale) | floor)
    ' <<<"$MONITOR_JSON"
)"

MONITOR_HEIGHT="$(
    jq -r '
        (.scale // 1) as $scale
        | ((.height / $scale) | floor)
    ' <<<"$MONITOR_JSON"
)"

PANEL_WIDTH=680
PANEL_HEIGHT=170
EDGE_GAP=24

MAX_WIDTH=$((MONITOR_WIDTH - EDGE_GAP * 2))
MAX_HEIGHT=$((MONITOR_HEIGHT - EDGE_GAP * 2))

if (( PANEL_WIDTH > MAX_WIDTH )); then
    PANEL_WIDTH=$MAX_WIDTH
fi

if (( PANEL_HEIGHT > MAX_HEIGHT )); then
    PANEL_HEIGHT=$MAX_HEIGHT
fi

MARGIN_LEFT=$(((MONITOR_WIDTH - PANEL_WIDTH) / 2))
MARGIN_RIGHT=$((MONITOR_WIDTH - PANEL_WIDTH - MARGIN_LEFT))
MARGIN_TOP=$(((MONITOR_HEIGHT - PANEL_HEIGHT) / 2))
MARGIN_BOTTOM=$((MONITOR_HEIGHT - PANEL_HEIGHT - MARGIN_TOP))

exec flock "${FLOCK_ARGS[@]}" "$LOCK_FILE" \
    wlogout \
    --protocol layer-shell \
    --no-span \
    --primary-monitor "$MONITOR_INDEX" \
    --layout "$LAYOUT" \
    --css "$CONFIG_DIR/style.css" \
    --buttons-per-row 4 \
    --column-spacing 0 \
    --row-spacing 0 \
    --margin-left "$MARGIN_LEFT" \
    --margin-right "$MARGIN_RIGHT" \
    --margin-top "$MARGIN_TOP" \
    --margin-bottom "$MARGIN_BOTTOM"