# shellcheck shell=bash
# terminux -- the menu you get from plain `terminux` in a terminal.
# SPDX-License-Identifier: Apache-2.0

# label|command   (command is run as `terminux <command>`)
TX_MENU=(
    "Start the desktop|start"
    "Stop the desktop|stop"
    "Open a Debian shell|debian"
    "Status|status"
    "Display: fit the screen (native, fullscreen)|display fold"
    "Toggle touch / trackpad mode|touch"
    "NetBird status|netbird status"
    "Check for problems (doctor)|doctor"
    "Update terminux|update"
    "All commands (help)|help"
)

_tx_menu_print() {
    local i=1 item
    echo
    printf '  %sterminux%s %s\n\n' "$TX_W" "$TX_C0" "$TERMINUX_VERSION"
    for item in "${TX_MENU[@]}"; do
        printf '  %s%2d%s  %s\n' "$TX_B" "$i" "$TX_C0" "${item%%|*}"
        i=$((i + 1))
    done
    printf '\n  %s q%s  Quit\n\n' "$TX_B" "$TX_C0"
}

cmd_menu() {
    local choice cmd
    while true; do
        _tx_menu_print
        read -rp "  Choose: " choice || return 0
        case "$choice" in
            q|Q|quit|exit) return 0 ;;
            ''|*[!0-9]*) tx_warn "'$choice' isn't on the menu."; continue ;;
        esac
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#TX_MENU[@]}" ]; then
            tx_warn "'$choice' isn't on the menu."
            continue
        fi
        cmd="${TX_MENU[$((choice - 1))]#*|}"
        echo
        # shellcheck disable=SC2086 # cmd holds a command and its arguments
        bash "$TX_LIB/../bin/terminux" $cmd
    done
}
