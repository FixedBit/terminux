# shellcheck shell=bash
# terminux -- quick, cheap status checks shared by the banner, menu and status.
# SPDX-License-Identifier: Apache-2.0

TX_DEBIAN_ROOTFS="${TX_DEBIAN_ROOTFS:-$PREFIX/var/lib/proot-distro/installed-rootfs/debian}"
TX_NB_HOME="${TX_NB_HOME:-$TERMINUX_STATE_DIR/netbird}"

tx_desktop_running() { pgrep -f "termux.x11" >/dev/null 2>&1; }

tx_debian_installed() { [ -d "$TX_DEBIAN_ROOTFS" ]; }

tx_debian_user() { tx_config_get user 2>/dev/null || echo user; }

# not set up | enrolled, stopped | running
tx_netbird_state() {
    if [ ! -e "$TX_NB_HOME/lib/config.json" ] && [ ! -d "$TX_NB_HOME/lib/profiles" ]; then
        echo "not set up"
    elif pgrep -f "$TX_NB_HOME/bin/netbird.* service run" >/dev/null 2>&1; then
        echo "running"
    else
        echo "enrolled, stopped"
    fi
}
