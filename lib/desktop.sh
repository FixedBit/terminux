# shellcheck shell=bash
# terminux -- start / stop / restart / status for the desktop.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

# The installer writes ~/start-linux.sh; other setups people may already
# have on the phone use start-x11.sh.
_tx_launcher() {
    local f
    for f in "$HOME/start-linux.sh" "$HOME/start-x11.sh"; do
        [ -f "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

cmd_start() {
    local launcher log="$TERMINUX_STATE_DIR/desktop.log"
    launcher=$(_tx_launcher) \
        || tx_die "No desktop is installed yet. Run the installer first: bash $TERMINUX_HOME/install.sh"
    if tx_desktop_running; then
        tx_ok "The desktop is already running. Open the Termux:X11 app."
        return 0
    fi

    # NetBird comes up with the desktop once the phone is enrolled.
    if [ "$(tx_netbird_state)" = "enrolled, stopped" ]; then
        bash "$TX_LIB/../bin/terminux" netbird start >/dev/null 2>&1 &
    fi

    mkdir -p "$TERMINUX_STATE_DIR"
    tx_info "Starting the desktop (log: $log)"
    # Its own session, so closing this terminal doesn't take the desktop with it.
    if tx_has setsid; then
        setsid nohup bash "$launcher" >> "$log" 2>&1 < /dev/null &
    else
        nohup bash "$launcher" >> "$log" 2>&1 < /dev/null &
    fi

    # Bring the Termux:X11 app to the front once the X server is up.
    ( sleep 3; am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 ) &
    tx_ok "Opening Termux:X11 -- the desktop appears there in a few seconds."
}

cmd_stop() {
    if [ -f "$HOME/stop-linux.sh" ]; then
        bash "$HOME/stop-linux.sh"
    else
        pkill -f "termux.x11" 2>/dev/null
        tx_ok "Desktop stopped."
    fi
}

cmd_restart() {
    cmd_stop
    sleep 1
    cmd_start
}

cmd_status() {
    local row='  %-9s %s\n'
    if tx_desktop_running; then printf "$row" "Desktop" "running"
    else printf "$row" "Desktop" "stopped"; fi
    if tx_debian_installed; then printf "$row" "Debian" "installed (user $(tx_debian_user))"
    else printf "$row" "Debian" "not installed"; fi
    printf "$row" "NetBird" "$(tx_netbird_state)"
    if pgrep -x sshd >/dev/null 2>&1; then printf "$row" "SSH" "listening on port 8022"
    else printf "$row" "SSH" "off"; fi
}
