# shellcheck shell=bash
# terminux -- quick, cheap status checks shared by the banner, menu and status.
# SPDX-License-Identifier: Apache-2.0

TX_PD_DIR="${TX_PD_DIR:-$PREFIX/var/lib/proot-distro}"
TX_NB_HOME="${TX_NB_HOME:-$TERMINUX_STATE_DIR/netbird}"

tx_desktop_running() { pgrep -f "termux.x11" >/dev/null 2>&1; }

# Debian's rootfs: proot-distro v4 keeps it in containers/debian/rootfs,
# older versions in installed-rootfs/debian.
tx_debian_rootfs() {
    local d
    for d in "$TX_PD_DIR/containers/debian/rootfs" "$TX_PD_DIR/installed-rootfs/debian"; do
        [ -d "$d" ] && { echo "$d"; return 0; }
    done
    return 1
}

tx_debian_installed() { tx_debian_rootfs >/dev/null; }

tx_debian_user() { tx_config_get user 2>/dev/null || echo user; }

# not set up | enrolled, stopped | running
tx_netbird_state() {
    # The client writes its config as soon as the daemon starts, so only a
    # successful join (which leaves this marker) counts as enrolled.
    if [ ! -e "$TX_NB_HOME/enrolled" ]; then
        echo "not set up"
    elif pgrep -f "$TX_NB_HOME/bin/netbird.* service run" >/dev/null 2>&1; then
        echo "running"
    else
        echo "enrolled, stopped"
    fi
}
