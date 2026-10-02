# shellcheck shell=bash
# terminux -- terminux fix: repair an existing install in place.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/detect.sh
. "$TX_LIB/detect.sh"
# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"
# shellcheck source=lib/apps.sh
. "$TX_LIB/apps.sh"
# shellcheck source=lib/pkgfix.sh
. "$TX_LIB/pkgfix.sh"

TX_FIX_MARK="# terminux fix"

# Launchers from upstream linux-android (start-linux.sh) and other setup
# scripts people have run (start-x11.sh, start-vnc.sh).
_tx_fix_launchers() {
    local f
    for f in "$HOME/start-linux.sh" "$HOME/start-x11.sh" "$HOME/start-vnc.sh"; do
        [ -f "$f" ] || continue

        # Upstream's KDE launcher had a literal \n, so it ran "nexec".
        if grep -qF '\nexec ' "$f"; then
            sed -i 's/\\nexec /\nexec /' "$f"
            tx_ok "Fixed the 'nexec' line in $(basename "$f")"
        fi

        # Old launchers don't clear a dead X server's lock (black screen,
        # "X server already running") or hold a wake lock (desktop freezes
        # when Samsung suspends Termux). Add both right after the shebang.
        if ! grep -q "X0-lock" "$f" || ! grep -q "termux-wake-lock" "$f"; then
            grep -q "$TX_FIX_MARK" "$f" && continue
            cp "$f" "$f.bak"
            sed -i "1a\\
$TX_FIX_MARK: clear a dead X server, keep Android from suspending Termux\\
pkill -9 -f termux.x11 2>/dev/null\\
rm -f $PREFIX/tmp/.X0-lock; rm -rf $PREFIX/tmp/.X11-unix\\
command -v termux-wake-lock >/dev/null 2>\\&1 \\&\\& termux-wake-lock" "$f"
            tx_ok "Added X lock cleanup and a wake lock to $(basename "$f") (backup: $(basename "$f").bak)"
        fi
    done
}

_tx_fix_kwin() {
    if grep -qE '^export KWIN_COMPOSE=O2ES' "$TERMINUX_GPU_CFG" 2>/dev/null; then
        sed -i 's/^export KWIN_COMPOSE=O2ES/export KWIN_COMPOSE=N/' "$TERMINUX_GPU_CFG"
        tx_ok "KWIN_COMPOSE set to N (KDE gets its title bars back after a restart)"
    fi
}

_tx_fix_xlock() {
    tx_desktop_running && return 0
    if [ -e "$PREFIX/tmp/.X0-lock" ] || [ -e "$PREFIX/tmp/.X11-unix" ]; then
        rm -f "$PREFIX/tmp/.X0-lock"
        rm -rf "$PREFIX/tmp/.X11-unix"
        tx_ok "Removed a stale X lock"
    fi
}

_tx_fix_vscode() {
    tx_has code-oss || return 0
    grep -qs '"password-store"' "$HOME/.vscode-oss/argv.json" && return 0
    tx_vscode_argv "$HOME/.vscode-oss/argv.json"
    tx_ok "VS Code will now keep your sign-ins (password-store: basic)"
}

# Android 12+ kills "phantom" child processes, taking the desktop with it.
tx_fix_phantom() {
    if [ "$(tx_detect_sdk)" -lt 31 ] 2>/dev/null; then
        tx_ok "Nothing to do: the phantom process killer only exists on Android 12 and later."
        return 0
    fi
    local cmd="/system/bin/device_config put activity_manager max_phantom_processes 2147483647; /system/bin/settings put global settings_enable_monitor_phantom_procs false"
    if tx_has su && su -c "$cmd" >/dev/null 2>&1; then
        tx_ok "Phantom process killer turned off (with root)."
        return 0
    fi
    if tx_has rish && rish -c "$cmd" >/dev/null 2>&1; then
        tx_ok "Phantom process killer turned off (with Shizuku)."
        return 0
    fi
    cat <<EOF
terminux can't change this setting itself (no root or Shizuku). Do it once:

  Android 14 and later:
    Settings > Developer options > Disable child process restrictions > on

  Android 12 and 13, from a computer with adb (or the LADB app):
    adb shell "$cmd"

Also set Termux and Termux:X11 to Unrestricted battery use
(Settings > Apps > Termux > Battery).
EOF
}

cmd_fix() {
    case "${1:-launchers}" in
        launchers)
            _tx_fix_launchers; _tx_fix_kwin; _tx_fix_xlock; _tx_fix_vscode
            tx_ok "Done. Restart the desktop to pick up the changes: terminux restart" ;;
        phantom) tx_fix_phantom ;;
        packages) tx_pkg_fix ;;
        all)
            _tx_fix_launchers; _tx_fix_kwin; _tx_fix_xlock; _tx_fix_vscode
            tx_fix_phantom ;;
        *) tx_fail "usage: terminux fix [launchers|phantom|packages|all]"; return 2 ;;
    esac
}
