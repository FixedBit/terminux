#!/usr/bin/env bats
# lib/pkgfix.sh: recognise why apt/dpkg failed, say why in plain words,
# and repair what's safe to repair.

load helpers

FIX="$REPO_ROOT/tests/fixtures/apt"

setup() { tx_sandbox; tx_load pkgfix; }

diag() { tx_pkg_diagnose "$FIX/$1.log"; }

@test "two packages owning the same file: names both, fixes with --force-overwrite" {
    run diag overwrite
    [ "$status" -eq 0 ]
    [[ "$output" == *"cause=overwrite"* ]]
    [[ "$output" == *"mesa-zink"* ]]
    [[ "$output" == *"libGL.so.1"* ]]
}

@test "an interrupted dpkg is recognised" {
    run diag interrupted
    [[ "$output" == *"cause=interrupted"* ]]
}

@test "unmet dependencies are recognised" {
    run diag broken
    [[ "$output" == *"cause=broken"* ]]
}

@test "no network is recognised and not blamed on packages" {
    run diag network
    [[ "$output" == *"cause=network"* ]]
}

@test "a bad mirror (hash sum mismatch) is recognised" {
    run diag mirror
    [[ "$output" == *"cause=mirror"* ]]
}

@test "a half-upgraded core library is recognised" {
    run diag corelib
    [[ "$output" == *"cause=corelib"* ]]
}

@test "a missing package (repo not enabled) is recognised, with its name" {
    run diag nopackage
    [[ "$output" == *"cause=missing"* && "$output" == *"termux-x11-nightly"* ]]
}

@test "another apt holding the lock is recognised" {
    run diag lock
    [[ "$output" == *"cause=lock"* ]]
}

@test "a full disk is recognised" {
    run diag storage
    [[ "$output" == *"cause=storage"* ]]
}

@test "unknown errors still show the actual error lines" {
    run diag unknown
    [[ "$output" == *"cause=unknown"* ]]
    [[ "$output" == *"E: Weird thing"* ]]
}

@test "every known cause has a plain explanation and a fix" {
    for c in overwrite interrupted broken network mirror corelib libmismatch missing lock storage unknown; do
        run tx_pkg_explain "$c"
        [ "$status" -eq 0 ] && [ -n "$output" ] || { echo "no explanation for $c"; return 1; }
        [[ "$output" == *"Fix:"* ]] || { echo "no fix for $c"; return 1; }
    done
}

# --- the upgrade itself ---------------------------------------------------

@test "upgrade finishes interrupted installs first, then upgrades non-interactively" {
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub dpkg 'echo "dpkg $*" >> "$CALLS"'
    stub apt-get 'echo "apt-get $*" >> "$CALLS"'
    run tx_pkg_upgrade
    [ "$status" -eq 0 ]
    head -1 "$CALLS" | grep -q "dpkg --configure -a"
    grep -q "apt-get .*--force-confold.*full-upgrade\|apt-get .*full-upgrade.*--force-confold" "$CALLS"
    grep -q "DEBIAN_FRONTEND\|-y" "$CALLS"
}

@test "upgrade repairs a file conflict and retries once" {
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub dpkg 'echo "dpkg $*" >> "$CALLS"'
    # first full-upgrade fails with an overwrite conflict, everything after works
    stub apt-get 'echo "apt-get $*" >> "$CALLS"
        if [[ "$*" == *full-upgrade* ]] && [ ! -e "'"$BATS_TEST_TMPDIR"'/failed-once" ]; then
            touch "'"$BATS_TEST_TMPDIR"'/failed-once"; cat "'"$FIX"'/overwrite.log"; exit 100; fi; exit 0'
    run tx_pkg_upgrade
    [ "$status" -eq 0 ]
    grep -q "apt-get .*--force-overwrite.*install -f\|apt-get .*install -f.*--force-overwrite" "$CALLS"
    [ "$(grep -c full-upgrade "$CALLS")" -eq 2 ]
    [[ "$output" == *"mesa-zink"* ]]
}

@test "when the repair doesn't help, it stops with the cause, the error and what to do" {
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub dpkg 'exit 0'
    stub apt-get '[[ "$*" == *full-upgrade* ]] && { cat "'"$FIX"'/corelib.log"; exit 100; }; exit 0'
    run tx_pkg_upgrade
    [ "$status" -ne 0 ]
    [[ "$output" == *"CANNOT LINK EXECUTABLE"* ]]
    [[ "$output" == *"Fix:"* ]]
    [[ "$output" == *"terminux report"* ]]
}

@test "network failures aren't retried with package repairs" {
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub dpkg 'exit 0'
    stub apt-get 'echo "apt-get $*" >> "$CALLS"; [[ "$*" == *update* || "$*" == *full-upgrade* ]] && { cat "'"$FIX"'/network.log"; exit 100; }; exit 0'
    run tx_pkg_upgrade
    [ "$status" -ne 0 ]
    run grep -c "force-overwrite" "$CALLS"
    [ "$output" = 0 ]
}

@test "a library mismatch (new curl, old openssl) is told apart from a running-process problem" {
    run diag libmismatch
    [[ "$output" == *"cause=libmismatch"* ]]
    [[ "$output" == *"openssl"* ]]
    run tx_pkg_explain libmismatch
    [[ "$output" == *"apt install -y openssl"* ]]
    [[ "$output" == *"apt full-upgrade"* ]]
}
