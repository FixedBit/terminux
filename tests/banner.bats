#!/usr/bin/env bats
# lib/banner.sh: `terminux banner` and the `terminux login` hook.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pgrep 'exit 1'          # nothing running
    stub sshd 'echo sshd >> "$CALLS"'
}

@test "banner shows the main commands" {
    run bash "$TX" banner
    [ "$status" -eq 0 ]
    for c in "terminux start" "terminux debian" "terminux help"; do
        [[ "$output" == *"$c"* ]] || { echo "banner lacks: $c"; return 1; }
    done
}

@test "banner reports the desktop as stopped or running" {
    run bash "$TX" banner
    [[ "$output" == *"Desktop"*"stopped"* ]]
    stub pgrep 'exit 0'
    run bash "$TX" banner
    [[ "$output" == *"Desktop"*"running"* ]]
}

@test "banner says when Debian isn't installed, and names the user when it is" {
    run bash "$TX" banner
    [[ "$output" == *"Debian"*"not installed"* ]]
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    mkdir -p "$HOME/.config/terminux"; echo "user=jason" > "$HOME/.config/terminux/config"
    run bash "$TX" banner
    [[ "$output" == *"Debian"*"jason"* ]]
}

@test "login prints the banner on a terminal" {
    TERMINUX_TTY=1 run bash "$TX" login
    [[ "$output" == *"terminux start"* ]]
}

@test "login stays quiet when output isn't a terminal" {
    run bash "$TX" login
    [ -z "$output" ]
}

@test "banner off silences login and brings back Termux's own welcome" {
    touch "$HOME/.hushlogin"
    bash "$TX" banner off
    [ ! -e "$HOME/.hushlogin" ]
    TERMINUX_TTY=1 run bash "$TX" login
    [ -z "$output" ]
    bash "$TX" banner on
    [ -e "$HOME/.hushlogin" ]
    TERMINUX_TTY=1 run bash "$TX" login
    [ -n "$output" ]
}

@test "login starts sshd when ssh is enabled and it isn't running" {
    mkdir -p "$HOME/.config/terminux"; echo "ssh=yes" > "$HOME/.config/terminux/config"
    bash "$TX" login
    grep -qx sshd "$CALLS"
}

@test "login leaves sshd alone when ssh is off" {
    bash "$TX" login
    run grep -c sshd "$CALLS"
    [ "$output" = 0 ]
}
