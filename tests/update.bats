#!/usr/bin/env bats
# lib/update.sh: terminux update pulls the checkout, using real git repos.

load helpers

setup() {
    tx_sandbox
    command -v git >/dev/null || skip "git not installed"
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    ORIGIN="$BATS_TEST_TMPDIR/origin"
    git init -q -b main "$ORIGIN"
    echo one > "$ORIGIN/file"; git -C "$ORIGIN" add file; git -C "$ORIGIN" commit -qm "first"
    export TERMINUX_HOME="$BATS_TEST_TMPDIR/checkout"
    git clone -q "$ORIGIN" "$TERMINUX_HOME"
}

new_upstream_commit() {
    echo "$1" >> "$ORIGIN/file"; git -C "$ORIGIN" commit -qam "$1"
}

@test "update pulls new commits and lists them" {
    new_upstream_commit "Add a shiny thing"
    run bash "$TX" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Add a shiny thing"* ]]
    grep -q "Add a shiny thing" "$TERMINUX_HOME/file"
}

@test "update when already current says so" {
    run bash "$TX" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]]
}

@test "update --check reports without pulling" {
    new_upstream_commit "Pending change"
    run bash "$TX" update --check
    [[ "$output" == *"1 update"* ]]
    run grep -c "Pending change" "$TERMINUX_HOME/file"
    [ "$output" = 0 ]
}

@test "update won't clobber local edits" {
    new_upstream_commit "Upstream"
    echo "mine" >> "$TERMINUX_HOME/file"
    run bash "$TX" update
    [ "$status" -ne 0 ]
    [[ "$output" == *"local changes"* ]]
    grep -q mine "$TERMINUX_HOME/file"
}

@test "update outside a git checkout explains how to reinstall" {
    export TERMINUX_HOME="$BATS_TEST_TMPDIR/not-a-repo"; mkdir -p "$TERMINUX_HOME"
    run bash "$TX" update
    [ "$status" -ne 0 ]
    [[ "$output" == *"install.sh"* ]]
}
