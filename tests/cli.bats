#!/usr/bin/env bats
# The CLI front door: dispatch, help, version, errors.

load helpers

setup() { tx_sandbox; }

@test "no arguments outside a terminal prints help" {
    run bash "$TX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: terminux"* ]]
}

@test "--help and help are the same" {
    run bash "$TX" --help
    a="$output"
    run bash "$TX" help
    [ "$output" = "$a" ]
}

@test "version prints the version from core.sh" {
    run bash "$TX" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^terminux\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "unknown command exits 2 and points at help" {
    run bash "$TX" frobnicate
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown command: frobnicate"* ]]
    [[ "$output" == *"terminux help"* ]]
}

@test "works when invoked through a symlink, as installed" {
    ln -s "$TX" "$PREFIX/bin/terminux"
    [ -L "$PREFIX/bin/terminux" ] || skip "no real symlinks here (Git Bash on Windows)"
    run bash "$PREFIX/bin/terminux" --version
    [ "$status" -eq 0 ]
}

@test "every command in help has a module that defines it" {
    # version and help are handled in bin/terminux itself.
    for c in $(bash "$TX" help | awk '/^  [a-z]/ && $1 != "version" { print $1 }' | sort -u); do
        mod=$(sed -n "s/^ *\([a-z|]*\)) *echo \([a-z]*\) ;;/\1 \2/p" "$TX" \
              | awk -v c="$c" '{ n = split($1, a, "|"); for (i = 1; i <= n; i++) if (a[i] == c) print $2 }')
        [ -n "$mod" ] || { echo "no module mapped for: $c"; return 1; }
        grep -q "^cmd_${c}()" "$REPO_ROOT/lib/$mod.sh" || { echo "cmd_$c missing in lib/$mod.sh"; return 1; }
    done
}
