# shellcheck shell=bash
# terminux -- terminux display / dpi / touch: Termux:X11 output and input.
# SPDX-License-Identifier: Apache-2.0

# termux-x11-preference blocks until the Termux:X11 app is in the
# foreground, so every call goes through tx_run_detached.
_tx_x11_pref() { tx_run_detached termux-x11-preference "$@"; }

cmd_display() {
    case "${1:-}" in
        native) _tx_x11_pref displayResolutionMode:native ;;
        scaled) _tx_x11_pref displayResolutionMode:scaled displayScale:150 ;;
        fold)   _tx_x11_pref displayResolutionMode:native fullscreen:true hideCutout:true ;;
        *)
            tx_fail "usage: terminux display native|scaled|fold"
            tx_hint "native: sharp, pair with a high DPI   scaled: 150%, blurry   fold: native + fullscreen + hide the camera cutout"
            return 2 ;;
    esac
    tx_ok "Sent to Termux:X11 (it applies once the app is open)."
}

cmd_dpi() {
    local value="${1:-}" current
    if [ -z "$value" ]; then
        current=$(tx_kv_get "$TERMINUX_GPU_CFG" LINUX_DPI 2>/dev/null)
        if [ -n "$current" ] && grep -qE '^export LINUX_DPI=' "$TERMINUX_GPU_CFG" 2>/dev/null; then
            echo "Desktop DPI: $current"
        else
            echo "Desktop DPI: 96 (X's default; set one with: terminux dpi 180)"
        fi
        return 0
    fi
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 72 ] && [ "$value" -le 320 ] \
        || { tx_fail "DPI must be a number from 72 to 320"; return 2; }
    tx_kv_set "$TERMINUX_GPU_CFG" LINUX_DPI "$value" "export "
    tx_ok "DPI set to $value. Restart the desktop to apply it: terminux restart"
}

cmd_touch() {
    local state="$TERMINUX_STATE_DIR/touch-mode" mode="${1:-toggle}"
    if [ "$mode" = toggle ]; then
        if [ "$(cat "$state" 2>/dev/null)" = touch ]; then mode=trackpad; else mode=touch; fi
    fi
    mkdir -p "$TERMINUX_STATE_DIR"
    case "$mode" in
        trackpad)
            _tx_x11_pref touchMode:Trackpad
            echo trackpad > "$state"
            tx_ok "Trackpad mode: your finger moves a pointer; tap to click." ;;
        touch)
            _tx_x11_pref "touchMode:Simulated touchscreen"
            echo touch > "$state"
            tx_ok "Touch mode: tap where you want to click; long-press for right-click." ;;
        *) tx_fail "usage: terminux touch [trackpad|touch]"; return 2 ;;
    esac
}
