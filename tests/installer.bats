#!/usr/bin/env bats
# Characterization tests for the inherited desktop installer
# (setup/termux-linux-setup.sh). They render the launchers it generates in a
# sandboxed $HOME and check what a phone would actually run.

load helpers

SETUP="$REPO_ROOT/setup/termux-linux-setup.sh"

# Render launchers for desktop <1-4> on device model <model>.
render() {
    local de="$1" model="${2:-SM-S918B}"
    (
        cd "$HOME" || exit 1
        # shellcheck source=/dev/null
        . "${SETUP_UNDER_TEST:-$SETUP}"
        TERMUX_PREFIX="$PREFIX" DE_CHOICE="$de" DEVICE_MODEL="$model"
        GPU_DRIVER=freedreno TOTAL_STEPS=10 CURRENT_STEP=0
        update_progress() { :; }
        # Its exit status is whatever its last test returned; judge the files.
        step_launchers >/dev/null || true
    )
}

setup() { tx_sandbox; }

@test "installer can be sourced without running the install" {
    run bash -c ". '$SETUP'; declare -F step_launchers"
    [ "$status" -eq 0 ]
}

@test "generated launchers are valid bash for every desktop" {
    for de in 1 2 3 4; do
        rm -f "$HOME/start-linux.sh" "$HOME/stop-linux.sh"
        render "$de"
        bash -n "$HOME/start-linux.sh" || { echo "start-linux.sh broken for DE $de"; return 1; }
        bash -n "$HOME/stop-linux.sh"  || { echo "stop-linux.sh broken for DE $de"; return 1; }
    done
}

@test "KDE launcher execs startplasma-x11 on its own line (upstream ran 'nexec')" {
    render 4
    run grep -cF '\nexec' "$HOME/start-linux.sh"
    [ "$output" = 0 ]
    grep -qE '^exec startplasma-x11' "$HOME/start-linux.sh"
}

@test "KDE disables KWin compositing by default" {
    render 4
    grep -qx 'export KWIN_COMPOSE=N' "$HOME/.config/linux-gpu.sh"
}

@test "KWIN_GL=1 opts KDE in to OpenGL compositing" {
    KWIN_GL=1 render 4
    grep -qx 'export KWIN_COMPOSE=O' "$HOME/.config/linux-gpu.sh"
}

@test "launcher and stop script clear a stale X lock and socket" {
    render 1
    for f in start-linux.sh stop-linux.sh; do
        grep -q "tmp/.X0-lock" "$HOME/$f" || { echo "$f keeps the X lock"; return 1; }
        grep -q "tmp/.X11-unix" "$HOME/$f" || { echo "$f keeps the X socket"; return 1; }
    done
}

@test "launcher takes a wake lock and the stop script releases it" {
    render 1
    grep -q termux-wake-lock "$HOME/start-linux.sh"
    grep -q termux-wake-unlock "$HOME/stop-linux.sh"
}

@test "Galaxy Fold models get LINUX_DPI=180" {
    render 1 SM-F956B
    grep -qE '^export LINUX_DPI=180' "$HOME/.config/linux-gpu.sh"
}

@test "other phones get only a commented DPI hint" {
    render 1 SM-S918B
    run grep -cE '^export LINUX_DPI=' "$HOME/.config/linux-gpu.sh"
    [ "$output" = 0 ]
    grep -qE '^# export LINUX_DPI=' "$HOME/.config/linux-gpu.sh"
}

# Run step_shortcuts with only the given commands on PATH.
shortcuts_with() {
    local cmd
    for cmd in "$@"; do stub "$cmd" 'exit 0'; done
    (
        cd "$HOME" || exit 1
        # shellcheck source=/dev/null
        . "$SETUP"
        TERMUX_PREFIX="$PREFIX" DE_CHOICE=1 INSTALL_WINE=no
        update_progress() { :; }
        PATH="$BATS_TEST_TMPDIR/stubs:/usr/bin:/bin"
        step_shortcuts >/dev/null || true
    )
}

@test "desktop shortcuts are created only for installed apps" {
    shortcuts_with firefox
    [ -f "$HOME/Desktop/Firefox.desktop" ]
    [ ! -f "$HOME/Desktop/VLC.desktop" ]
    [ ! -f "$HOME/Desktop/VSCode.desktop" ]
    [ -f "$HOME/Desktop/Terminal.desktop" ]
}

@test "TERMINUX_APPS chooses what step_apps installs, on top of the base tools" {
    stub pkg 'exit 0'
    run bash -c "
        . '$SETUP'
        safe_install_pkg() { echo \"\$1\"; }
        update_progress() { :; }
        TERMINUX_APPS=vscode,build step_apps"
    [ "$status" -eq 0 ]
    for p in git curl openssh code-oss clang cmake; do
        grep -qx "$p" <<<"$output" || { echo "missing $p"; return 1; }
    done
    run grep -cxE 'firefox|vlc' <<<"$output"
    [ "$output" = 0 ]
}
