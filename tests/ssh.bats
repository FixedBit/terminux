#!/usr/bin/env bats
# terminux ssh on|off: start sshd whenever Termux opens.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    stub sshd 'echo sshd >> "$CALLS"'
    stub pgrep 'exit 1'
    stub pkill 'echo "pkill $*" >> "$CALLS"'
}

@test "ssh on installs openssh, starts sshd and remembers it" {
    run bash "$TX" ssh on
    [ "$status" -eq 0 ]
    grep -q "pkg install -y openssh" "$CALLS"
    grep -qx sshd "$CALLS"
    [ "$(grep -x 'ssh=yes' "$HOME/.config/terminux/config")" = ssh=yes ]
    [[ "$output" == *"8022"* ]]
}

@test "ssh off stops sshd and forgets it" {
    bash "$TX" ssh on
    bash "$TX" ssh off
    grep -q "pkill -x sshd" "$CALLS"
    grep -qx 'ssh=no' "$HOME/.config/terminux/config"
}
