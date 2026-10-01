#!/usr/bin/env bats
# lib/debian.sh: the Debian (proot-distro) environment.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    export ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    # proot-distro: log every call on one line, args joined by | (scripts
    # passed with bash -c are flattened), and make the rootfs on install.
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"
        [ "$1" = install ] && mkdir -p "'"$PREFIX"'/var/lib/proot-distro/installed-rootfs/$2/etc"; exit 0'
    tx_load debian
}

@test "install creates Debian when it's missing" {
    tx_debian_install jason bash ""
    grep -q "^proot-distro|install|debian" "$CALLS"
}

@test "install reuses an existing Debian" {
    mkdir -p "$ROOTFS/etc"
    tx_debian_install jason bash ""
    run grep -c "^proot-distro|install" "$CALLS"
    [ "$output" = 0 ]
}

@test "install creates the user with passwordless sudo" {
    tx_debian_install jason bash ""
    grep -q "useradd -m -s /bin/bash .*jason" "$CALLS"
    grep -q "jason ALL=(ALL) NOPASSWD: ALL" "$CALLS"
}

@test "install points Linux apps at the Termux:X11 display and PulseAudio" {
    tx_debian_install jason bash ""
    grep -qx "export DISPLAY=:0" "$ROOTFS/etc/profile.d/terminux.sh"
    grep -qx "export PULSE_SERVER=127.0.0.1" "$ROOTFS/etc/profile.d/terminux.sh"
}

@test "install remembers the user for later commands" {
    tx_debian_install jason bash ""
    [ "$(tx_config_get user)" = jason ]
}

@test "zsh users get zsh in Debian too, set up as that user" {
    tx_debian_install jason zsh ohmyzsh,powerlevel10k
    grep -q "apt-get install -y .*zsh" "$CALLS"
    grep -q "useradd -m -s /usr/bin/zsh .*jason" "$CALLS"
    grep -q "^proot-distro|login|debian|--user|jason|.*tx_shell_setup zsh ohmyzsh,powerlevel10k" "$CALLS"
}

@test "install refuses a bad username" {
    run tx_debian_install "Bad User" bash ""
    [ "$status" -ne 0 ]
    run grep -c proot-distro "$CALLS"
    [ "$output" = 0 ]
}

@test "terminux debian opens a shell as the saved user, sharing /tmp for X" {
    mkdir -p "$ROOTFS"; mkdir -p "$HOME/.config/terminux"; echo user=jason > "$HOME/.config/terminux/config"
    run bash "$TX" debian
    [ "$status" -eq 0 ]
    grep -qx "proot-distro|login|debian|--user|jason|--shared-tmp" "$CALLS"
}

@test "terminux debian -- cmd runs one command" {
    mkdir -p "$ROOTFS"; mkdir -p "$HOME/.config/terminux"; echo user=jason > "$HOME/.config/terminux/config"
    bash "$TX" debian -- htop -d 5
    grep -qx "proot-distro|login|debian|--user|jason|--shared-tmp|--|htop|-d|5" "$CALLS"
}

@test "terminux debian explains how to install it when it's missing" {
    run bash "$TX" debian
    [ "$status" -ne 0 ]
    [[ "$output" == *"terminux app debian"* ]]
}
