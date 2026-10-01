# shellcheck shell=bash
# terminux -- carry out an install plan (TX_PLAN from lib/options.sh).
# SPDX-License-Identifier: Apache-2.0

for _m in status android shell banner debian apps catalog env netbird private fix ssh; do
    # shellcheck source=/dev/null
    . "$TX_LIB/$_m.sh"
done
unset _m

TX_DESKTOP_INSTALLER="${TERMINUX_DESKTOP_INSTALLER:-$TX_LIB/../setup/termux-linux-setup.sh}"
TX_INSTALL_FAILED=()

# Run an optional step; remember it if it fails and keep going.
_tx_try() {
    local what="$1"; shift
    "$@" || { TX_INSTALL_FAILED+=("$what"); tx_warn "$what didn't finish; carrying on."; }
}

_tx_install_base() {
    tx_step "Updating Termux and installing the basics"
    pkg update -y >/dev/null 2>&1 || true
    pkg install -y x11-repo tur-repo >/dev/null 2>&1 || true
    pkg install -y git curl termux-api termux-x11-nightly proot-distro \
        || { tx_fail "Couldn't install the basic packages; check your connection and try again."; return 1; }
}

_tx_install_save_config() {
    local k
    for k in de theme user shell zsh banner ssh tweaks; do
        tx_config_set "$k" "${TX_PLAN[$k]}"
    done
}

_tx_install_link_cli() {
    mkdir -p "$PREFIX/bin"
    ln -sf "$TERMINUX_HOME/bin/terminux" "$PREFIX/bin/terminux"
}

_tx_install_desktop() {
    local de
    case "${TX_PLAN[de]}" in xfce) de=1 ;; lxqt) de=2 ;; mate) de=3 ;; kde) de=4 ;; esac
    tx_step "Installing the ${TX_PLAN[de]} desktop (this is the long part)"
    local -a env=(
        TERMINUX_DE="$de"
        TERMINUX_WINE="$([ "${TX_PLAN[wine]}" = yes ] && echo y || echo n)"
        TERMINUX_APPS="${TX_PLAN[apps]}"
        TERMINUX_TWEAKS="${TX_PLAN[tweaks]}"
        TERMINUX_THEME="${TX_PLAN[theme]}"
    )
    [ "${TX_PLAN[dpi]}" != auto ] && env+=(TERMINUX_DPI="${TX_PLAN[dpi]}")
    env "${env[@]}" bash "$TX_DESKTOP_INSTALLER"
}

_tx_install_packages() {
    [ -n "${TX_PLAN[packages]}" ] || return 0
    tx_step "Installing extra packages"
    # shellcheck disable=SC2046 # one argument per package; names are validated
    pkg install -y $(tr ',' ' ' <<< "${TX_PLAN[packages]}")
}

_tx_install_shell() {
    tx_step "Setting up your shell (${TX_PLAN[shell]})"
    tx_shell_setup "${TX_PLAN[shell]}" "${TX_PLAN[zsh]}"
    if [ "${TX_PLAN[banner]}" = yes ]; then touch "$HOME/.hushlogin"; else rm -f "$HOME/.hushlogin"; fi
}

_tx_list() { tr ',' '\n' <<< "$1" | sed '/^$/d'; }

tx_install_run() {
    tx_is_termux || tx_die "This installer runs inside Termux on an Android phone. Get Termux from F-Droid: https://f-droid.org/packages/com.termux/"

    [ -n "${TX_PRIVATE_SRC:-}" ] && { tx_private_load "$TX_PRIVATE_SRC" || exit 1; }
    tx_private_load_default

    command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
    _tx_install_base || exit 1
    tx_android_ensure_apps
    _tx_install_save_config
    _tx_install_link_cli

    _tx_install_desktop || tx_die "The desktop install failed; see the messages above and ~/termux-setup.log"
    _tx_try "extra packages" _tx_install_packages
    [[ ",${TX_PLAN[apps]}," == *,vscode,* ]] && tx_vscode_argv "$HOME/.vscode-oss/argv.json"
    _tx_try "shell setup" _tx_install_shell
    [ "${TX_PLAN[ssh]}" = yes ] && _tx_try "SSH server" cmd_ssh on

    local item
    while read -r item; do
        case "$item" in
            debian)    _tx_try "Debian environment" tx_debian_install "${TX_PLAN[user]}" "${TX_PLAN[shell]}" "${TX_PLAN[zsh]}" ;;
            vscode-ms) _tx_try "Microsoft VS Code" cmd_app vscode-ms ;;
            cursor)    _tx_try "Cursor CLI" cmd_app cursor ;;
            netbird)   _tx_try "NetBird" tx_nb_join ;;
        esac
    done < <(_tx_list "${TX_PLAN[with]}")

    while read -r item; do
        _tx_try "$item" tx_cat_install "$item"
    done < <(_tx_list "${TX_PLAN[add]}")

    while read -r item; do
        tx_env_exists "$item" && continue
        _tx_try "environment $item" _tx_env_cmd_create "$item" --from "$item"
    done < <(_tx_list "${TX_PLAN[envs]}")

    [[ ",${TX_PLAN[tweaks]}," == *,phantom,* ]] && tx_fix_phantom

    command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
    echo
    if [ ${#TX_INSTALL_FAILED[@]} -gt 0 ]; then
        tx_warn "Installed, but these parts failed: ${TX_INSTALL_FAILED[*]}"
        tx_hint "Run 'terminux doctor', or retry one with 'terminux add <id>' / 'terminux app <name>'."
    else
        tx_ok "All done."
    fi
    cat <<EOF

  Next:
    1. Close and reopen Termux (or run: exec \$SHELL) for your new shell and the banner.
    2. Start the desktop:  ${TX_W}terminux start${TX_C0}
    3. Everything else:    ${TX_W}terminux${TX_C0}  (a menu)   or   ${TX_W}terminux help${TX_C0}

EOF
    [ ${#TX_INSTALL_FAILED[@]} -eq 0 ]
}
