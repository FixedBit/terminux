#!/usr/bin/env bats
# lib/menu.sh: `terminux` with no arguments on a terminal opens a menu.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pgrep 'exit 1'
}

@test "no arguments on a terminal shows the menu; q quits" {
    TERMINUX_TTY=1 run bash "$TX" <<<"q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Start the desktop"* ]]
    [[ "$output" == *"Debian"* ]]
}

@test "no arguments without a terminal prints help instead" {
    run bash "$TX" </dev/null
    [[ "$output" == *"Usage: terminux"* ]]
}

@test "a menu choice runs the matching command" {
    printf '#!/bin/bash\necho "start-linux" >> "%s"\n' "$CALLS" > "$HOME/start-linux.sh"
    stub am 'exit 0'
    stub sleep 'exit 0'
    TERMINUX_TTY=1 run bash "$TX" <<<$'1\nq'
    [ "$status" -eq 0 ]
    for _ in $(seq 1 25); do grep -q start-linux "$CALLS" && break; /bin/sleep 0.1; done
    grep -q start-linux "$CALLS"
}

@test "an invalid choice says so and shows the menu again" {
    TERMINUX_TTY=1 run bash "$TX" <<<$'zz\nq'
    [[ "$output" == *"zz"* ]]
    [ "$(grep -c 'Start the desktop' <<<"$output")" -ge 2 ]
}
