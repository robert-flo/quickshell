#!/usr/bin/env bash
# Apply or clear mpvpaper live wallpapers for Clavis on niri.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/clavis/mpvpaper"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/clavis/mpvpaper"
HOOK="${CLAVIS_MPVPAPER_HOOK:-$HOME/.config/clavis/mpvpaper/mpv-hook.lua}"

clear_mpvpaper() {
    pkill -x mpvpaper 2>/dev/null || true
    local attempt=0
    while pgrep -x mpvpaper >/dev/null 2>&1 && (( attempt < 40 )); do
        sleep 0.05
        attempt=$((attempt + 1))
    done
}

thumb_for() {
    local video="$1"
    local hash
    hash=$(printf '%s' "$video" | md5sum | awk '{print $1}')
    echo "$CACHE_DIR/${hash}.jpg"
}

usage() {
    echo "usage: $0 apply <video-path> | clear" >&2
    exit 1
}

cmd="${1:-}"
case "$cmd" in
    clear)
        clear_mpvpaper
        ;;
    apply)
        video="${2:-}"
        [[ -n "$video" && -f "$video" ]] || {
            echo "ERROR: video file not found: ${video:-<empty>}" >&2
            exit 1
        }
        command -v mpvpaper >/dev/null 2>&1 || {
            echo "ERROR: mpvpaper is not installed (recommend mpvpaper-git >= 1.9)" >&2
            exit 2
        }
        clear_mpvpaper
        mkdir -p "$CACHE_DIR" "$STATE_DIR"
        thumb=$(thumb_for "$video")
        if [[ ! -f "$thumb" ]]; then
            tmp="$(mktemp "${thumb%.jpg}.XXXXXX.jpg")"
            if ! ffmpeg -y -loglevel error -i "$video" -ss 00:00:01 -vframes 1 "$tmp" 2>/dev/null; then
                rm -f "$tmp"
                echo "ERROR: ffmpeg failed to extract a preview frame" >&2
                exit 3
            fi
            mv "$tmp" "$thumb"
        fi
        printf '%s\n' "$video" >"$STATE_DIR/current-video"
        mpv_opts="config=no load-scripts=no loop-file=inf panscan=1.0 no-audio hwdec=auto"
        if [[ -f "$HOOK" ]]; then
            mpv_opts+=" script=${HOOK}"
        fi
        nohup mpvpaper --auto-pause -o "$mpv_opts" '*' "$video" >/dev/null 2>&1 &
        printf 'THUMB_PATH=%s\n' "$thumb"
        ;;
    *)
        usage
        ;;
esac
