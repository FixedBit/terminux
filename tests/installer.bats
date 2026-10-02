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
        TERMUX_PREFIX="$PREFIX" DE_CHOICE="$de" DEVICE_MODEL="$model" DEVICE_DENSITY="${DENSITY:-}"
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

# --- Device tweaks (install.sh --tweaks) -------------------------------------
# These run the generated launcher with Android's commands stubbed out, and
# check what it actually did rather than what the script text says.

ANDROID_CMDS="termux-wake-lock pkill termux-x11 pulseaudio pactl dbus-daemon
    dbus-uuidgen dbus-update-activation-environment startxfce4 xrdb
    xfconf-query kwriteconfig6 vulkaninfo sleep"

# Stub every Android/desktop command to append "<name> <args>" to calls.log.
# startxfce4 also records the GPU environment the desktop would get.
stub_android() {
    local c
    for c in $ANDROID_CMDS; do
        stub "$c" "echo \"$c \$*\" >> \"$BATS_TEST_TMPDIR/calls.log\""
    done
    stub startxfce4 'echo "startxfce4 GALLIUM=${GALLIUM_DRIVER:-} GTK_THEME=${GTK_THEME:-}" >> "$BATS_TEST_TMPDIR/calls.log"'
    stub vulkaninfo "echo \"${VULKAN_SUMMARY:-deviceName = Turnip Adreno (TM) 750}\""
}

# render + run the XFCE launcher; waits briefly for its background jobs.
launch() {
    # Keep stubs a test already set up (e.g. a custom pulseaudio).
    [ -x "$BATS_TEST_TMPDIR/stubs/termux-x11" ] || stub_android
    render 1 "${MODEL:-SM-S918B}"
    PATH="$BATS_TEST_TMPDIR/stubs:/usr/bin:/bin" bash "$HOME/start-linux.sh" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        grep -q xfconf-query "$BATS_TEST_TMPDIR/calls.log" 2>/dev/null && break
        sleep 0.2
    done
    touch "$BATS_TEST_TMPDIR/calls.log"
}

called() { grep -q "^$1" "$BATS_TEST_TMPDIR/calls.log"; }
not_called() { run grep -c "^$1" "$BATS_TEST_TMPDIR/calls.log"; [ "$output" = 0 ]; }

@test "tweaks default to on: wake lock is held" {
    launch
    called termux-wake-lock
}

@test "without the wakelock tweak the launcher doesn't take one" {
    TERMINUX_TWEAKS=gpu-check launch
    not_called termux-wake-lock
}

@test "gpu-check falls back to software rendering when Turnip isn't there" {
    VULKAN_SUMMARY="deviceName = llvmpipe" launch
    called "startxfce4 GALLIUM= "
}

@test "gpu-check keeps Zink when Turnip is there" {
    launch
    called "startxfce4 GALLIUM=zink"
}

@test "without gpu-check the launcher trusts the GPU config" {
    VULKAN_SUMMARY="deviceName = llvmpipe" TERMINUX_TWEAKS=wakelock launch
    called "startxfce4 GALLIUM=zink"
}

@test "oneui-audio preloads libskcodec for PulseAudio when the library exists" {
    # Must be a real shared library or the stub itself won't start; glibc's
    # libc is harmless to preload. Git Bash on Windows has none.
    lib=$(ldconfig -p 2>/dev/null | awk '/libc\.so\.6 / { print $NF; exit }')
    [ -n "$lib" ] || skip "needs a glibc host to preload a real library"
    stub_android
    stub pulseaudio "echo \"pulseaudio LD_PRELOAD=\${LD_PRELOAD:-} \$*\" >> \"$BATS_TEST_TMPDIR/calls.log\""
    TERMINUX_ONEUI_AUDIO_LIB="$lib" launch
    called "pulseaudio LD_PRELOAD=$lib --start"
}

@test "oneui-audio does nothing on phones without libskcodec" {
    stub_android
    stub pulseaudio "echo \"pulseaudio LD_PRELOAD=\${LD_PRELOAD:-} \$*\" >> \"$BATS_TEST_TMPDIR/calls.log\""
    TERMINUX_ONEUI_AUDIO_LIB=/nonexistent/libskcodec.so launch
    called "pulseaudio LD_PRELOAD= --start"
}

@test "touch tweak gives XFCE grabbable window borders even without a DPI" {
    launch
    called "xfconf-query -c xfwm4 -p /general/theme -n -t string -s Default-xhdpi"
}

@test "without the touch tweak XFCE keeps its default borders" {
    TERMINUX_TWEAKS=wakelock launch
    not_called "xfconf-query -c xfwm4"
}

@test "hidpi tweak off: no automatic DPI even on a Fold" {
    TERMINUX_TWEAKS=wakelock render 1 SM-F956B
    run grep -cE '^export LINUX_DPI=' "$HOME/.config/linux-gpu.sh"
    [ "$output" = 0 ]
}

@test "an explicit DPI wins over the automatic one" {
    TERMINUX_DPI=150 render 1 SM-F956B
    grep -qE '^export LINUX_DPI=150' "$HOME/.config/linux-gpu.sh"
}

@test "dark theme reaches GTK apps and XFCE" {
    TERMINUX_THEME=dark launch
    called "startxfce4 .*GTK_THEME=Adwaita:dark" || grep -q "GTK_THEME=Adwaita:dark" "$BATS_TEST_TMPDIR/calls.log"
    called "xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s Adwaita-dark"
}

@test "light theme uses plain Adwaita" {
    TERMINUX_THEME=light launch
    grep -q "GTK_THEME=Adwaita$" "$BATS_TEST_TMPDIR/calls.log"
    called "xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s Adwaita$"
}

@test "hidpi works beyond the Fold: DPI follows Android's screen density" {
    DENSITY=480 render 1 SM-S918B
    grep -qE '^export LINUX_DPI=192' "$HOME/.config/linux-gpu.sh"
}

@test "hidpi leaves ordinary-density screens alone" {
    DENSITY=320 render 1 SM-A146B
    run grep -cE '^export LINUX_DPI=' "$HOME/.config/linux-gpu.sh"
    [ "$output" = 0 ]
}

@test "step_update leaves upgrading to terminux when it already did it" {
    stub pkg 'echo "pkg $*" >> "$BATS_TEST_TMPDIR/pkg.log"'
    stub apt-get 'exit 0'
    run bash -c ". '$SETUP'; update_progress() { :; }; spinner() { wait \"\$1\"; }; LOG_FILE=/dev/null TERMINUX_UPGRADED=1 step_update"
    [ "$status" -eq 0 ]
    run grep -c "upgrade" "$BATS_TEST_TMPDIR/pkg.log"
    [ "$output" = 0 ] || [ ! -s "$BATS_TEST_TMPDIR/pkg.log" ]
}
