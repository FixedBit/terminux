# shellcheck shell=bash
# terminux -- terminux uninstall.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/env.sh
. "$TX_LIB/env.sh"

# Remove the terminux block from a shell rc file, keeping everything else.
_tx_rc_unblock() {
    local rc="$1" tmp
    [ -f "$rc" ] || return 0
    tmp=$(mktemp)
    awk '
        $0 == "# >>> terminux >>>" { skip = 1; next }
        $0 == "# <<< terminux <<<" { skip = 0; next }
        !skip' "$rc" > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
}

cmd_uninstall() {
    local yes=0 all=0 arg
    for arg in "$@"; do
        case "$arg" in
            --yes|-y) yes=1 ;;
            --all) all=1 ;;
            *) tx_fail "usage: terminux uninstall [--yes] [--all]"; return 2 ;;
        esac
    done
    echo "This removes the terminux command, its shell hooks and the banner."
    if [ "$all" = 1 ]; then
        echo "With --all it also deletes every environment and NetBird's identity."
    else
        echo "Your desktop, apps and environments stay (add --all to remove environments too)."
    fi
    if [ "$yes" != 1 ]; then
        local answer
        read -rp "Go ahead? [y/N] " answer || return 0
        [[ "$answer" =~ ^[yY] ]] || { echo "Nothing changed."; return 0; }
    fi

    pkill -f "$TERMINUX_STATE_DIR/netbird/bin/netbird" 2>/dev/null
    _tx_rc_unblock "$HOME/.bashrc"
    _tx_rc_unblock "$HOME/.zshrc"
    rm -f "$HOME/.hushlogin" "$HOME/.termux/boot/terminux-netbird"
    rm -f "$PREFIX/bin/terminux" "$PREFIX/bin/code-ms" "$PREFIX/bin/cursor-agent"

    if [ "$all" = 1 ]; then
        local n
        while read -r n; do
            [ -n "$n" ] && proot-distro remove "$n"
        done < <(tx_env_names)
        rm -rf "$TERMINUX_STATE_DIR" "$TERMINUX_CONFIG_DIR"
    fi
    tx_ok "terminux is uninstalled. Its files are still in $TERMINUX_HOME if you want them; delete that folder to finish."
}
