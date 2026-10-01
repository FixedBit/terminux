# shellcheck shell=bash
# terminux -- the Debian environment (proot-distro), for glibc-only software.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

TX_USER_RE='^[a-z_][a-z0-9_-]{0,31}$'

# Run a script as root inside Debian.
_tx_debian_root() {
    proot-distro login debian --shared-tmp -- bash -c "$1"
}

# tx_debian_install <user> <zsh|bash> <zsh extras>
tx_debian_install() {
    local user="$1" shell="${2:-bash}" extras="${3:-}" login_shell=/bin/bash
    [[ "$user" =~ $TX_USER_RE ]] || { tx_fail "'$user' isn't a valid Linux username"; return 2; }
    [ "$shell" = zsh ] && login_shell=/usr/bin/zsh

    tx_has proot-distro || pkg install -y proot-distro || return 1
    if tx_debian_installed; then
        tx_info "Debian is already installed; updating it"
    else
        tx_step "Installing Debian (about 1 GB)"
        proot-distro install debian || { tx_fail "proot-distro couldn't install Debian"; return 1; }
    fi

    local pkgs="sudo locales ca-certificates curl git dbus-x11 pulseaudio-utils"
    [ "$shell" = zsh ] && pkgs+=" zsh"
    tx_step "Setting up Debian and your account ($user)"
    _tx_debian_root "
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        apt-get install -y $pkgs
        sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen >/dev/null
        id -u $user >/dev/null 2>&1 || useradd -m -s $login_shell -G sudo $user
        chsh -s $login_shell $user
        for g in audio video; do getent group \$g >/dev/null && usermod -aG \$g $user; done
        echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user
        chmod 0440 /etc/sudoers.d/$user
    " || { tx_fail "Setting up Debian failed; see the output above"; return 1; }

    # Linux apps started from Debian show up on the Termux:X11 display and
    # play sound through Termux's PulseAudio (the desktop launcher loads its
    # TCP module).
    local rootfs; rootfs=$(tx_debian_rootfs) || { tx_fail "Can't find Debian's files after installing it"; return 1; }
    mkdir -p "$rootfs/etc/profile.d"
    cat > "$rootfs/etc/profile.d/terminux.sh" <<'EOF'
# Written by terminux.
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export LANG=en_US.UTF-8
EOF

    if [ "$shell" = zsh ]; then
        proot-distro login debian --user "$user" --shared-tmp \
            --bind "$TERMINUX_HOME:/opt/terminux" -- bash -c "
                TX_LIB=/opt/terminux/lib
                . /opt/terminux/lib/core.sh
                . /opt/terminux/lib/shell.sh
                TX_SHELL_GUEST=1 tx_shell_setup zsh $extras
            " || tx_warn "zsh setup inside Debian didn't finish"
    fi

    tx_config_set user "$user"
    tx_ok "Debian is ready. Open it with: terminux debian"
}

cmd_debian() {
    tx_debian_installed \
        || tx_die "Debian isn't installed. Add it with: terminux app debian"
    local -a args=(login debian --user "$(tx_debian_user)" --shared-tmp)
    if [ "${1:-}" = -- ]; then
        shift
        args+=(-- "$@")
    elif [ $# -gt 0 ]; then
        args+=(-- "$@")
    fi
    proot-distro "${args[@]}"
}
