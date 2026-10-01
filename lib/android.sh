# shellcheck shell=bash
# terminux -- the Android apps terminux needs next to Termux itself.
# SPDX-License-Identifier: Apache-2.0

TX_X11_APK_URL="https://github.com/termux/termux-x11/releases/download/nightly/termux-x11-universal-debug.apk"

# 0 installed, 1 missing, 2 can't tell (pm unavailable or restricted).
tx_android_has_app() {
    local out
    out=$(pm list packages "$1" 2>/dev/null) || return 2
    grep -qx "package:$1" <<< "$out"
}

# Download an APK and hand it to Android's package installer.
_tx_android_install_apk() {
    local name="$1" url="$2" dir="$TERMINUX_STATE_DIR/apk"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/$name.apk" "$url" || { tx_fail "Couldn't download $name"; return 1; }
    termux-open --content-type application/vnd.android.package-archive "$dir/$name.apk"
}

_tx_android_wait() {
    [ -t 0 ] || [ "${TERMINUX_TTY:-0}" = 1 ] || return 0
    read -rp "  When Android has finished installing it, press Enter to carry on. " _ || true
}

tx_android_ensure_apps() {
    local s
    tx_android_has_app com.termux.x11 && s=0 || s=$?
    if [ "$s" = 2 ]; then
        tx_warn "Can't check which apps are installed. Make sure you have the Termux:X11 app (github.com/termux/termux-x11/releases) and Termux:API."
        return 0
    fi
    if [ "$s" = 1 ]; then
        tx_step "Installing the Termux:X11 app (it shows the desktop)"
        tx_hint "Android will ask to allow installs from Termux; allow it, then tap Install."
        _tx_android_install_apk termux-x11 "$TX_X11_APK_URL" && _tx_android_wait
    else
        tx_ok "Termux:X11 app is installed"
    fi

    if tx_android_has_app com.termux.api; then
        tx_ok "Termux:API app is installed"
        return 0
    fi
    # Termux:API shares Termux's user ID, so it must be signed by the same
    # people as the Termux you have: F-Droid with F-Droid, GitHub with GitHub.
    tx_step "Installing the Termux:API app (clipboard, notifications, wake lock)"
    case "${TERMUX_APK_RELEASE:-F_DROID}" in
        GITHUB)
            local url
            url=$(curl -fsSL https://api.github.com/repos/termux/termux-api/releases/latest \
                  | grep -o '"browser_download_url": *"[^"]*termux-api-app_[^"]*github[^"]*\.apk"' \
                  | head -n 1 | sed 's/.*"\(https[^"]*\)"$/\1/')
            [ -n "$url" ] || { tx_fail "Couldn't find the Termux:API download"; return 1; }
            _tx_android_install_apk termux-api "$url" && _tx_android_wait ;;
        GOOGLE_PLAY_STORE)
            termux-open-url "https://play.google.com/store/apps/details?id=com.termux.api"
            _tx_android_wait ;;
        *)
            tx_hint "Opening F-Droid's page for Termux:API; tap Install there."
            termux-open-url "https://f-droid.org/packages/com.termux.api/"
            _tx_android_wait ;;
    esac
}
