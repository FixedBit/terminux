# shellcheck shell=bash
# terminux -- the banner shown when Termux opens, and the login hook.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

_tx_banner_print() {
    local desktop debian nb
    if tx_desktop_running; then desktop="${TX_G}running${TX_C0}"; else desktop="stopped"; fi
    if tx_debian_installed; then debian="installed (user ${TX_W}$(tx_debian_user)${TX_C0})"
    else debian="${TX_D}not installed${TX_C0}"; fi
    nb="$(tx_netbird_state)"
    [ "$nb" = running ] && nb="${TX_G}running${TX_C0}"

    cat <<EOF
${TX_B}  _                      _
 | |_ ___ _ __ _ __ ___ (_)_ __  _   ___  __
 | __/ _ \\ '__| '_ \` _ \\| | '_ \\| | | \\ \\/ /
 | ||  __/ |  | | | | | | | | | | |_| |>  <
  \\__\\___|_|  |_| |_| |_|_|_| |_|\\__,_/_/\\_\\ ${TX_C0}${TX_D}v$TERMINUX_VERSION${TX_C0}

  Desktop  $desktop
  Debian   $debian
  NetBird  $nb

  ${TX_W}terminux${TX_C0}          menu with everything below
  ${TX_W}terminux start${TX_C0}    start the Linux desktop, then open the Termux:X11 app
  ${TX_W}terminux stop${TX_C0}     stop it
  ${TX_W}terminux debian${TX_C0}   a shell in Debian, for regular Linux software
  ${TX_W}terminux doctor${TX_C0}   check for problems
  ${TX_W}terminux help${TX_C0}     all commands
  ${TX_D}(terminux banner off hides this)${TX_C0}

EOF
}

cmd_banner() {
    case "${1:-}" in
        off)
            tx_config_set banner no
            rm -f "$HOME/.hushlogin"
            tx_ok "Banner off. Termux shows its own welcome text again." ;;
        on)
            tx_config_set banner yes
            touch "$HOME/.hushlogin"
            tx_ok "Banner on." ;;
        "") _tx_banner_print ;;
        *)  tx_die "usage: terminux banner [on|off]" 2 ;;
    esac
}

# Runs from the shell rc file every time a Termux session opens.
cmd_login() {
    if [ "$(tx_config_get ssh 2>/dev/null)" = yes ] && ! pgrep -x sshd >/dev/null 2>&1; then
        sshd >/dev/null 2>&1 || true
    fi
    [ "$(tx_config_get banner 2>/dev/null)" = no ] && return 0
    if [ -t 1 ] || [ "${TERMINUX_TTY:-0}" = 1 ]; then
        _tx_banner_print
    fi
    return 0
}
