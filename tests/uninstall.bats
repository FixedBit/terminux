#!/usr/bin/env bats
# lib/uninstall.sh: terminux uninstall.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub proot-distro 'echo "proot-distro $*" >> "$CALLS"'
    stub pkill 'exit 0'
    tx_load shell
    echo "alias ll='ls -l'" > "$HOME/.bashrc"
    tx_rc_block "$HOME/.bashrc"
    tx_rc_block "$HOME/.zshrc"
    ln -sf "$REPO_ROOT/bin/terminux" "$PREFIX/bin/terminux"
    touch "$HOME/.hushlogin"
    mkdir -p "$HOME/.config/terminux" "$HOME/.local/state/terminux/netbird"
}

@test "uninstall asks first and does nothing on no" {
    TERMINUX_TTY=1 run bash "$TX" uninstall <<<"n"
    grep -q ">>> terminux >>>" "$HOME/.bashrc"
}

@test "uninstall --yes removes the CLI, the shell hooks and the banner switch" {
    bash "$TX" uninstall --yes
    [ ! -e "$PREFIX/bin/terminux" ] && [ ! -L "$PREFIX/bin/terminux" ]
    run grep -c "terminux" "$HOME/.bashrc"
    [ "$output" = 0 ]
    grep -q "alias ll" "$HOME/.bashrc"
    [ ! -e "$HOME/.hushlogin" ]
}

@test "uninstall keeps environments and the desktop unless asked" {
    bash "$TX" uninstall --yes
    run grep -c "proot-distro remove" "$CALLS"
    [ "$output" = 0 ]
}

@test "uninstall --all removes environments too" {
    mkdir -p "$PREFIX/var/lib/proot-distro/containers/work/rootfs"
    bash "$TX" uninstall --yes --all
    grep -q "proot-distro remove work" "$CALLS"
    [ ! -d "$HOME/.local/state/terminux" ]
}
