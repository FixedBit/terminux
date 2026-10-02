#!/usr/bin/env bats
# Option rules ("when" in options.json): install.sh refuses combinations the
# wizard would never make, and quietly drops defaults that don't apply.

load helpers

INSTALL="$REPO_ROOT/install.sh"
setup() { tx_sandbox; }
plan() { bash "$INSTALL" --dry-run "$@"; }

@test "Wine only exists for the Termux desktop" {
    run plan --base debian --wine
    [ "$status" -eq 2 ]
    [[ "$output" == *"--wine"* && "$output" == *"termux"* ]]
}

@test "graphical apps need a desktop" {
    run plan --de none --apps firefox
    [ "$status" -eq 2 ]
    [[ "$output" == *"firefox"* ]]
}

@test "Ubuntu doesn't offer Firefox, and its default app list just leaves it out" {
    run plan --base ubuntu --apps firefox
    [ "$status" -eq 2 ]
    run plan --base ubuntu
    [ "$status" -eq 0 ]
    grep -qx "apps=vscode,vlc,python" <<<"$output"
}

@test "terminal only: no theme, DPI, Wine or GUI apps in the plan" {
    run plan --de none
    [ "$status" -eq 0 ]
    grep -qx "theme=" <<<"$output"
    grep -qx "dpi=" <<<"$output"
    grep -qx "apps=python" <<<"$output"
}

@test "the touch tweak is only for XFCE" {
    run plan --de lxqt --tweaks touch
    [ "$status" -eq 2 ]
    run plan --de lxqt
    run grep -c "touch" <<<"$(grep '^tweaks=' <<<"$output")"
    [ "$output" = 0 ]
}

@test "a username is only asked for when something needs an account" {
    run plan
    grep -qx "user=" <<<"$output"
    run plan --base debian
    grep -qx "user=user" <<<"$output"
    run plan --with cursor
    grep -qx "user=user" <<<"$output"
    run plan --user jason
    [ "$status" -eq 2 ]
    run plan --base ubuntu --user jason
    grep -qx "user=jason" <<<"$output"
}

@test "zsh extras need zsh" {
    run plan --shell bash --zsh ohmyzsh
    [ "$status" -eq 2 ]
    run plan --shell bash
    grep -qx "zsh=" <<<"$output"
}

@test "on Debian, the extra Debian environment isn't offered (you're already in one)" {
    run plan --base debian --with debian
    [ "$status" -eq 2 ]
}

@test "error messages say what the option needs, in words" {
    run plan --base debian --wine
    [[ "$output" == *"only applies when"* ]]
}
