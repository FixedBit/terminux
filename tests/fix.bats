#!/usr/bin/env bats
# lib/fix.sh: terminux fix repairs an existing install in place.

load helpers

setup() {
    tx_sandbox
    export TERMUX_VERSION=0.118
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pgrep 'exit 1'
    mkdir -p "$HOME/.config"
}

@test "fixes the KDE launcher's nexec line" {
    printf '%s\n' '#!/bin/bash' '(sleep 5) &\nexec startplasma-x11' > "$HOME/start-linux.sh"
    bash "$TX" fix
    grep -qx "exec startplasma-x11" "$HOME/start-linux.sh"
    run grep -cF '\nexec' "$HOME/start-linux.sh"
    [ "$output" = 0 ]
    bash -n "$HOME/start-linux.sh"
}

@test "switches KWIN_COMPOSE from O2ES to N" {
    echo "export KWIN_COMPOSE=O2ES" > "$HOME/.config/linux-gpu.sh"
    bash "$TX" fix
    grep -qx "export KWIN_COMPOSE=N" "$HOME/.config/linux-gpu.sh"
}

@test "removes a stale X lock when no X server is running" {
    touch "$PREFIX/tmp/.X0-lock"; mkdir -p "$PREFIX/tmp/.X11-unix"
    bash "$TX" fix
    [ ! -e "$PREFIX/tmp/.X0-lock" ]
    [ ! -e "$PREFIX/tmp/.X11-unix" ]
}

@test "leaves the X lock alone while the desktop runs" {
    stub pgrep 'exit 0'
    touch "$PREFIX/tmp/.X0-lock"
    bash "$TX" fix
    [ -e "$PREFIX/tmp/.X0-lock" ]
}

@test "older launchers without lock cleanup or wake lock get them, once" {
    printf '%s\n' '#!/bin/bash' 'termux-x11 :0 &' 'exec startxfce4' > "$HOME/start-x11.sh"
    bash "$TX" fix
    bash "$TX" fix
    [ "$(grep -c '# terminux fix' "$HOME/start-x11.sh")" -eq 1 ]
    grep -q "X0-lock" "$HOME/start-x11.sh"
    grep -q "termux-wake-lock" "$HOME/start-x11.sh"
    [ "$(head -1 "$HOME/start-x11.sh")" = "#!/bin/bash" ]
    [ -f "$HOME/start-x11.sh.bak" ]
    bash -n "$HOME/start-x11.sh"
}

@test "adds password-store=basic to VS Code's argv.json" {
    stub code-oss 'exit 0'
    bash "$TX" fix
    grep -q '"password-store": "basic"' "$HOME/.vscode-oss/argv.json"
}

@test "fix phantom uses root when there is root" {
    stub getprop '[ "$1" = ro.build.version.sdk ] && echo 34'
    stub su 'echo "su $*" >> "$CALLS"'
    run bash "$TX" fix phantom
    [ "$status" -eq 0 ]
    grep -q "su -c .*settings_enable_monitor_phantom_procs false" "$CALLS"
}

@test "fix phantom falls back to Shizuku (rish)" {
    stub getprop '[ "$1" = ro.build.version.sdk ] && echo 34'
    stub rish 'echo "rish $*" >> "$CALLS"'
    run bash "$TX" fix phantom
    grep -q "rish -c .*max_phantom_processes" "$CALLS"
}

@test "fix phantom explains the manual way when it can't do it itself" {
    stub getprop '[ "$1" = ro.build.version.sdk ] && echo 34'
    run bash "$TX" fix phantom
    [[ "$output" == *"Disable child process restrictions"* ]]
    [[ "$output" == *"adb shell"* ]]
}

@test "fix phantom has nothing to do before Android 12" {
    stub getprop '[ "$1" = ro.build.version.sdk ] && echo 30'
    run bash "$TX" fix phantom
    [ "$status" -eq 0 ]
    [[ "$output" == *"Android 12"* ]]
}

@test "fix packages runs the package repair sequence" {
    stub dpkg 'echo "dpkg $*" >> "$CALLS"'
    stub apt-get 'echo "apt-get $*" >> "$CALLS"'
    run bash "$TX" fix packages
    [ "$status" -eq 0 ]
    grep -q "dpkg --configure -a" "$CALLS"
    grep -q "apt-get .*--force-overwrite.*install -f" "$CALLS"
    grep -q "apt-get .*full-upgrade" "$CALLS"
}
