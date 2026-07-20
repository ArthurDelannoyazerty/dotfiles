#!/usr/bin/env bash

set -u -o pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpaper}"
INTERVAL_SECONDS="${WALLPAPER_INTERVAL:-1800}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

CURRENT_LINK="$CACHE_DIR/current_wallpaper"
LOOP_LOCK="$RUNTIME_DIR/hypr-wallpaper-slideshow.lock"
ROTATE_LOCK="$RUNTIME_DIR/hypr-wallpaper-rotate.lock"

usage() {
    cat <<'USAGE'
Usage: slideshow.sh [--with-loop] [--help]

Without arguments:
  Change the wallpaper once, regenerate the Matugen palette, then exit.

--with-loop
  Run as the single slideshow daemon and change the wallpaper every
  WALLPAPER_INTERVAL seconds (default: 1800).

Environment variables:
  WALLPAPER_DIR       Wallpaper directory.
  WALLPAPER_INTERVAL  Loop interval in seconds.
USAGE
}

notify() {
    local title="$1"
    local body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body" >/dev/null 2>&1 || true
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$1" >&2
        return 1
    fi
}

check_dependencies() {
    local missing=0
    local command_name

    for command_name in find flock readlink pgrep awww awww-daemon matugen; do
        require_command "$command_name" || missing=1
    done

    return "$missing"
}

start_awww_daemon() {
    local attempt

    if pgrep -x awww-daemon >/dev/null 2>&1; then
        return 0
    fi

    awww-daemon >/dev/null 2>&1 &

    # Wait briefly for the daemon socket instead of relying on one fixed sleep.
    for attempt in {1..30}; do
        if awww query >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done

    printf 'awww-daemon did not become ready.\n' >&2
    return 1
}

pick_wallpaper() {
    local current=""
    local candidate
    local -a wallpapers=()
    local -a alternatives=()

    if [ ! -d "$WALLPAPER_DIR" ]; then
        printf 'Wallpaper directory does not exist: %s\n' "$WALLPAPER_DIR" >&2
        return 1
    fi

    while IFS= read -r -d '' candidate; do
        wallpapers+=("$candidate")
    done < <(
        find "$WALLPAPER_DIR" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -print0
    )

    if ((${#wallpapers[@]} == 0)); then
        printf 'No supported images found in %s\n' "$WALLPAPER_DIR" >&2
        return 1
    fi

    current="$(readlink -f -- "$CURRENT_LINK" 2>/dev/null || true)"

    # Avoid immediately selecting the current wallpaper when alternatives exist.
    if ((${#wallpapers[@]} > 1)) && [ -n "$current" ]; then
        for candidate in "${wallpapers[@]}"; do
            if [ "$(readlink -f -- "$candidate" 2>/dev/null || printf '%s' "$candidate")" != "$current" ]; then
                alternatives+=("$candidate")
            fi
        done

        if ((${#alternatives[@]} > 0)); then
            wallpapers=("${alternatives[@]}")
        fi
    fi

    printf '%s\n' "${wallpapers[RANDOM % ${#wallpapers[@]}]}"
}

generate_palette() {
    local image="$1"
    local resolved

    # Matugen currently fails on extensionless paths, including an extensionless
    # symlink such as ~/.cache/current_wallpaper. Resolve the symlink and pass the
    # original image filename, whose extension is preserved.
    resolved="$(readlink -f -- "$image" 2>/dev/null || true)"

    if [ -z "$resolved" ] || [ ! -f "$resolved" ]; then
        printf 'Cannot resolve Matugen source image: %s\n' "$image" >&2
        return 1
    fi

    case "${resolved,,}" in
        *.jpg | *.jpeg | *.png | *.webp)
            ;;
        *)
            printf 'Unsupported or extensionless Matugen source: %s\n' "$resolved" >&2
            return 1
            ;;
    esac

    if ! matugen image "$resolved" --source-color-index 0; then
        printf 'Matugen failed for: %s\n' "$resolved" >&2
        return 1
    fi
}

reload_ui() {
    pkill -SIGUSR2 waybar >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
}

rotate_wallpaper() (
    local wallpaper
    local resolved
    local extension

    # Serialize one-shot and periodic rotations so they cannot update Matugen and
    # the cache symlink at the same time.
    exec 8>"$ROTATE_LOCK"
    flock -x 8

    wallpaper="$(pick_wallpaper)" || return 1
    resolved="$(readlink -f -- "$wallpaper" 2>/dev/null || true)"

    if [ -z "$resolved" ] || [ ! -f "$resolved" ]; then
        printf 'Selected wallpaper is not a readable file: %s\n' "$wallpaper" >&2
        notify 'Wallpaper error' 'The selected wallpaper could not be read.'
        return 1
    fi

    start_awww_daemon || {
        notify 'Wallpaper error' 'awww-daemon could not be started.'
        return 1
    }

    if ! awww img "$resolved" \
        --transition-type grow \
        --transition-pos top-right \
        --transition-duration 2.5 \
        --transition-fps 60; then
        printf 'Failed to set wallpaper: %s\n' "$resolved" >&2
        notify 'Wallpaper error' 'awww failed to set the wallpaper.'
        return 1
    fi

    mkdir -p "$CACHE_DIR"
    ln -sfn -- "$resolved" "$CURRENT_LINK"
    printf '%s\n' "$resolved" > "$CACHE_DIR/current_wallpaper.path"

    # Also expose an extension-preserving cache link for manual Matugen calls.
    extension="${resolved##*.}"
    extension="${extension,,}"
    find "$CACHE_DIR" -maxdepth 1 -type l -name 'current_wallpaper.*' -delete 2>/dev/null || true
    ln -sfn -- "$resolved" "$CACHE_DIR/current_wallpaper.$extension"

    if generate_palette "$resolved"; then
        reload_ui
        printf 'Wallpaper and palette updated: %s\n' "$resolved"
    else
        # Keep the previous generated palette rather than leaving the desktop in
        # a partially updated state.
        notify 'Wallpaper changed' 'Matugen failed; the previous color palette was kept.'
        return 1
    fi
)

run_loop() {
    local sleep_pid=""
    local stop_requested=0

    exec 9>"$LOOP_LOCK"
    if ! flock -n 9; then
        printf 'The slideshow loop is already running.\n'
        return 0
    fi

    trap 'stop_requested=1; [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null || true' INT TERM

    while ((stop_requested == 0)); do
        rotate_wallpaper || true

        sleep "$INTERVAL_SECONDS" &
        sleep_pid=$!
        wait "$sleep_pid" 2>/dev/null || true
        sleep_pid=""
    done
}

main() {
    local mode="once"

    case "${1:-}" in
        '')
            ;;
        --with-loop)
            mode="loop"
            ;;
        -h | --help)
            usage
            return 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            return 2
            ;;
    esac

    if ! [[ "$INTERVAL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
        printf 'WALLPAPER_INTERVAL must be a positive integer, got: %s\n' "$INTERVAL_SECONDS" >&2
        return 2
    fi

    check_dependencies || return 127

    if [ "$mode" = 'loop' ]; then
        run_loop
    else
        rotate_wallpaper
    fi
}

main "$@"