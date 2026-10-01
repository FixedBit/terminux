#!/usr/bin/env bats
# lib/desktop.sh: start / stop / restart / status.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    printf '#!/bin/bash\necho "start-linux $*" >> "%s"\n' "$CALLS" > "$HOME/start-linux.sh"
    printf '#!/bin/bash\necho "stop-linux" >> "%s"\n' "$CALLS" > "$HOME/stop-linux.sh"
    stub pgrep 'exit 1'
    stub am 'echo "am $*" >> "$CALLS"'
    stub sleep 'exit 0'
}

wait_for() { for _ in $(seq 1 25); do grep -q "$1" "$CALLS" && return 0; command sleep 0.1 2>/dev/null || /bin/sleep 0.1; done; return 1; }

@test "start runs the desktop launcher in the background and returns" {
    run bash "$TX" start
    [ "$status" -eq 0 ]
    wait_for "start-linux"
    [[ "$output" == *"Termux:X11"* ]]
}

@test "start opens the Termux:X11 app" {
    bash "$TX" start
    wait_for "am start"
    grep -q "am start .*com.termux.x11" "$CALLS"
}

@test "start refuses politely when the desktop isn't installed" {
    rm "$HOME/start-linux.sh"
    run bash "$TX" start
    [ "$status" -ne 0 ]
    [[ "$output" == *"install"* ]]
}

@test "start does nothing when the desktop is already running" {
    stub pgrep 'exit 0'
    run bash "$TX" start
    [ "$status" -eq 0 ]
    [[ "$output" == *"already running"* ]]
    run grep -c start-linux "$CALLS"
    [ "$output" = 0 ]
}

@test "start falls back to other launchers people have (start-x11.sh)" {
    rm "$HOME/start-linux.sh"
    printf '#!/bin/bash\necho "start-x11" >> "%s"\n' "$CALLS" > "$HOME/start-x11.sh"
    bash "$TX" start
    wait_for "start-x11"
}

@test "stop runs the stop script" {
    run bash "$TX" stop
    [ "$status" -eq 0 ]
    grep -qx stop-linux "$CALLS"
}

@test "status says what's running" {
    run bash "$TX" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Desktop"*"stopped"* ]]
    [[ "$output" == *"NetBird"* ]]
}
