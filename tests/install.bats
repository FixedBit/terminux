#!/usr/bin/env bats
# install.sh: flag parsing, validation and the private-values handoff.

load helpers

INSTALL="$REPO_ROOT/install.sh"

setup() { tx_sandbox; }

@test "--dry-run prints the plan and installs nothing" {
    stub pkg 'echo "pkg $*" >> "$BATS_TEST_TMPDIR/pkg.log"'
    run bash "$INSTALL" --dry-run --de kde
    [ "$status" -eq 0 ]
    grep -qx "de=kde" <<<"$output"
    [ ! -e "$BATS_TEST_TMPDIR/pkg.log" ]
}

@test "an unknown flag is an error that names it" {
    run bash "$INSTALL" --dry-run --frobnicate
    [ "$status" -eq 2 ]
    [[ "$output" == *"--frobnicate"* ]]
}

@test "a value outside the allowed choices is rejected" {
    run bash "$INSTALL" --dry-run --de gnome
    [ "$status" -eq 2 ]
    [[ "$output" == *"--de"* && "$output" == *"gnome"* ]]
}

@test "multi options are validated item by item" {
    run bash "$INSTALL" --dry-run --apps vscode,doom
    [ "$status" -eq 2 ]
    [[ "$output" == *"doom"* ]]
}

@test "--dpi must be a number in range" {
    run bash "$INSTALL" --dry-run --dpi big
    [ "$status" -eq 2 ]
    run bash "$INSTALL" --dry-run --dpi 9999
    [ "$status" -eq 2 ]
    run bash "$INSTALL" --dry-run --dpi 180
    [ "$status" -eq 0 ]
    grep -qx "dpi=180" <<<"$output"
}

@test "--packages refuses anything that isn't a package name" {
    run bash "$INSTALL" --dry-run --packages 'htop,$(reboot)'
    [ "$status" -eq 2 ]
    run bash "$INSTALL" --dry-run --packages 'htop;rm'
    [ "$status" -eq 2 ]
    run bash "$INSTALL" --dry-run --packages htop,neovim
    [ "$status" -eq 0 ]
    grep -qx "packages=htop,neovim" <<<"$output"
}

@test "flags accept --flag=value as well as --flag value" {
    run bash "$INSTALL" --dry-run --de=lxqt --theme=light
    [ "$status" -eq 0 ]
    grep -qx "de=lxqt" <<<"$output"
    grep -qx "theme=light" <<<"$output"
}

@test "--help lists every flag in options.json" {
    run bash "$INSTALL" --help
    [ "$status" -eq 0 ]
    for flag in $(node -e 'for (const o of require(process.argv[1]).options) console.log(o.flag)' "$REPO_ROOT/options.json"); do
        [[ "$output" == *"$flag"* ]] || { echo "help lacks $flag"; return 1; }
    done
}

@test "a multi option set to 'none' plans an empty list" {
    run bash "$INSTALL" --dry-run --tweaks none
    [ "$status" -eq 0 ]
    grep -qx "tweaks=" <<<"$output"
}

@test "--user must be a valid Linux username" {
    for bad in "Jason" "root user" "1abc" "a;b" "root"; do
        run bash "$INSTALL" --dry-run --user "$bad"
        [ "$status" -eq 2 ] || { echo "accepted bad user: $bad"; return 1; }
    done
    run bash "$INSTALL" --dry-run --user jason
    [ "$status" -eq 0 ]
    grep -qx "user=jason" <<<"$output"
}

@test "on-by-default switches are turned off with --no-<flag>" {
    run bash "$INSTALL" --dry-run --no-banner
    [ "$status" -eq 0 ]
    grep -qx "banner=no" <<<"$output"
}

@test "vscode-ms and cursor bring in the Debian environment" {
    run bash "$INSTALL" --dry-run --with cursor
    [ "$status" -eq 0 ]
    grep -qE "^with=(.*,)?debian(,.*)?$" <<<"$output"
}

@test "--add takes any catalog id" {
    run bash "$INSTALL" --dry-run --add claude-code,neovim
    [ "$status" -eq 0 ]
    grep -qx "add=claude-code,neovim" <<<"$output"
    run bash "$INSTALL" --dry-run --add not-a-thing
    [ "$status" -eq 2 ]
}

@test "--envs takes environment profiles" {
    run bash "$INSTALL" --dry-run --envs dev,minimal
    [ "$status" -eq 0 ]
    grep -qx "envs=dev,minimal" <<<"$output"
    run bash "$INSTALL" --dry-run --envs nope
    [ "$status" -eq 2 ]
}
