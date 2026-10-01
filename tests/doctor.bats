#!/usr/bin/env bats
# lib/doctor.sh: terminux doctor finds known problems and names the fix.

load helpers

setup() {
    tx_sandbox
    export TERMUX_VERSION=0.118
    stub uname '[ "$1" = -m ] && echo aarch64 || echo Linux'
    stub pgrep 'exit 1'
    stub getprop 'case "$1" in ro.build.version.sdk) echo 34;; ro.product.model) echo SM-F956B;; esac'
    stub settings 'echo 0'
    stub vulkaninfo 'echo "deviceName = Turnip Adreno (TM) 750"'
    mkdir -p "$HOME/.config"
    printf '#!/bin/bash\nexec startxfce4\n' > "$HOME/start-linux.sh"
    printf 'export KWIN_COMPOSE=N\n' > "$HOME/.config/linux-gpu.sh"
}

@test "a healthy install passes" {
    run bash "$TX" doctor
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"No problems found"* ]]
}

@test "outside Termux it says so" {
    unset TERMUX_VERSION
    run env -u TERMUX_VERSION PREFIX="$PREFIX" bash "$TX" doctor
    [[ "$output" == *"Termux"* ]]
}

@test "no desktop installed points at the installer" {
    rm "$HOME/start-linux.sh"
    run bash "$TX" doctor
    [[ "$output" == *"install.sh"* ]]
}

@test "the broken KDE launcher line is found" {
    # The literal backslash-n that upstream's launcher contained.
    printf '%s\n' '#!/bin/bash' '(sleep 5) &\nexec startplasma-x11' > "$HOME/start-linux.sh"
    run bash "$TX" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"nexec"* && "$output" == *"terminux fix"* ]]
}

@test "KWIN_COMPOSE=O2ES (no title bars) is found" {
    printf 'export KWIN_COMPOSE=O2ES\n' > "$HOME/.config/linux-gpu.sh"
    run bash "$TX" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"KWIN_COMPOSE"* && "$output" == *"terminux fix"* ]]
}

@test "a stale X lock with no X server running is found" {
    touch "$PREFIX/tmp/.X0-lock"
    run bash "$TX" doctor
    [[ "$output" == *"X0-lock"* && "$output" == *"terminux fix"* ]]
}

@test "the phantom process killer being on is found" {
    stub settings 'echo 1'
    run bash "$TX" doctor
    [[ "$output" == *"terminux fix phantom"* ]]
}

@test "a GPU Turnip can't drive is reported" {
    stub vulkaninfo 'echo "deviceName = llvmpipe (LLVM 17)"'
    run bash "$TX" doctor
    [[ "$output" == *"software rendering"* ]]
}

@test "VS Code without password-store=basic is found" {
    stub code-oss 'exit 0'
    run bash "$TX" doctor
    [[ "$output" == *"password-store"* ]]
}

@test "a broken native Cursor install is found" {
    mkdir -p "$HOME/.local/share/cursor-agent"
    run bash "$TX" doctor
    [[ "$output" == *"Cursor"* && "$output" == *"terminux app cursor"* ]]
}
