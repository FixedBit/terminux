#!/usr/bin/env bats
# lib/tui.sh: the terminal wizard install.sh runs when given no options.

load helpers

INSTALL="$REPO_ROOT/install.sh"
setup() { tx_sandbox; }

# Run the installer interactively (dry run) with the given answers, then
# Enter for every remaining question.
wizard() {
    local answers="$1"; shift
    { printf '%b' "$answers"; yes '' | head -n 80; } \
        | TERMINUX_TTY=1 bash "$INSTALL" --dry-run "$@"
}

@test "with no options in a terminal, it walks through the steps" {
    run wizard ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step 1 of 6"* && "$output" == *"Linux"* ]]
    [[ "$output" == *"Step 6 of 6"* ]]
}

@test "pressing Enter everywhere gives the defaults" {
    run wizard ""
    grep -qx "base=termux" <<<"$output"
    grep -qx "de=xfce" <<<"$output"
    grep -qx "apps=vscode,firefox,vlc,python" <<<"$output"
}

@test "picking Debian then KDE: the plan has both, and it asks for a username" {
    run wizard "2\n4\n"
    grep -qx "base=debian" <<<"$output"
    grep -qx "de=kde" <<<"$output"
    [[ "$output" == *"Linux username"* ]]
    grep -qx "user=user" <<<"$output"
}

@test "steps only show what applies: terminal only skips theme and graphical apps" {
    run wizard "1\n5\n"
    grep -qx "de=none" <<<"$output"
    [[ "$output" != *"Theme"* ]]
    [[ "$output" != *"] Firefox"* ]]
}

@test "Termux doesn't ask for a username" {
    run wizard ""
    [[ "$output" != *"Linux username"* ]]
}

@test "b goes back a step to change an answer" {
    # Step 1: Termux; step 2: back; step 1: Debian; then defaults.
    run wizard "1\nb\n2\n"
    grep -qx "base=debian" <<<"$output"
}

@test "list steps toggle items by number" {
    # Linux and desktop by default; theme default; apps: toggle 2 (Firefox) off.
    run wizard "\n\n\n\n2\n\n"
    grep -qx "apps=vscode,vlc,python" <<<"$output"
}

@test "a bad username is asked again" {
    # Debian, then Enter for desktop, theme, apps, packages, tweaks, DPI.
    run wizard "2\n\n\n\n\n\n\nBad User\nsam\n"
    grep -qx "user=sam" <<<"$output"
    [[ "$output" == *"Lowercase"* || "$output" == *"isn't a valid"* ]]
}

@test "the review shows the choices and the command to repeat them" {
    run wizard "2\n4\n"
    [[ "$output" == *"Review"* ]]
    [[ "$output" == *"install.sh --base debian --de kde"*"--yes"* ]]
}

@test "saying no at the review installs nothing" {
    # The 15 questions of the default Termux path, then "n" at the review.
    run bash -c "{ yes '' | head -n 15; echo n; } | TERMINUX_TTY=1 TERMUX_VERSION=x bash '$INSTALL'"
    [[ "$output" == *"Nothing was installed"* ]]
}

@test "options on the command line skip the wizard" {
    run bash -c "yes '' | head -n 5 | TERMINUX_TTY=1 bash '$INSTALL' --dry-run --de kde"
    [[ "$output" != *"Step 1 of 6"* ]]
}

@test "--yes alone takes the defaults without asking" {
    run bash -c "TERMINUX_TTY=1 bash '$INSTALL' --dry-run --yes </dev/null"
    [[ "$output" != *"Step 1 of 6"* ]]
    grep -qx "de=xfce" <<<"$output"
}

@test "without a terminal it doesn't ask either" {
    run bash -c "bash '$INSTALL' --dry-run </dev/null"
    [[ "$output" != *"Step 1 of 6"* ]]
}
