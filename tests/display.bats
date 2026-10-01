#!/usr/bin/env bats
# lib/display.sh: terminux display / dpi / touch.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub termux-x11-preference 'echo "pref $*" >> "$CALLS"'
}

wait_for() { for _ in $(seq 1 30); do grep -q -- "$1" "$CALLS" && return 0; sleep 0.1; done; return 1; }

@test "display fold: native resolution, fullscreen, no cutout" {
    run bash "$TX" display fold
    [ "$status" -eq 0 ]
    wait_for "pref displayResolutionMode:native fullscreen:true hideCutout:true"
}

@test "display scaled: lower resolution at 150%" {
    bash "$TX" display scaled
    wait_for "pref displayResolutionMode:scaled displayScale:150"
}

@test "display doesn't hang when Termux:X11 isn't open" {
    stub termux-x11-preference 'sleep 30'
    stub timeout 'shift; "$@" & sleep 0.1; kill $! 2>/dev/null'
    SECONDS=0
    bash "$TX" display native
    [ "$SECONDS" -lt 5 ]
}

@test "display with an unknown mode lists the modes" {
    run bash "$TX" display hyper
    [ "$status" -eq 2 ]
    [[ "$output" == *"native"*"scaled"*"fold"* ]]
}

@test "dpi shows the current value" {
    mkdir -p "$HOME/.config"
    echo "export LINUX_DPI=180   # Galaxy Fold" > "$HOME/.config/linux-gpu.sh"
    run bash "$TX" dpi
    [[ "$output" == *"180"* ]]
}

@test "dpi with nothing set says it's the default" {
    run bash "$TX" dpi
    [[ "$output" == *"96"* ]]
}

@test "dpi <n> sets it, replacing the commented hint" {
    mkdir -p "$HOME/.config"
    echo "# export LINUX_DPI=160   # uncomment for HiDPI scaling" > "$HOME/.config/linux-gpu.sh"
    run bash "$TX" dpi 150
    [ "$status" -eq 0 ]
    grep -qx "export LINUX_DPI=150" "$HOME/.config/linux-gpu.sh"
    [ "$(grep -c LINUX_DPI "$HOME/.config/linux-gpu.sh")" -eq 1 ]
    [[ "$output" == *"restart"* ]]
}

@test "dpi rejects nonsense" {
    run bash "$TX" dpi huge
    [ "$status" -eq 2 ]
    run bash "$TX" dpi 5000
    [ "$status" -eq 2 ]
}

@test "touch trackpad / touch set the mode, plain touch toggles" {
    bash "$TX" touch touch
    wait_for 'pref touchMode:Simulated touchscreen'
    : > "$CALLS"
    bash "$TX" touch
    wait_for "pref touchMode:Trackpad"
    : > "$CALLS"
    bash "$TX" touch
    wait_for 'pref touchMode:Simulated touchscreen'
}
