#!/usr/bin/env bats
# lib/prootdesk.sh: a desktop running inside Debian or Ubuntu (proot), shown
# on Termux:X11.

load helpers

setup() {
    tx_sandbox
    export TERMUX_VERSION=0.118
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    export PD="$PREFIX/var/lib/proot-distro"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"
        if [ "$1" = install ]; then shift; n=""; i=""
            while [ $# -gt 0 ]; do case "$1" in --name|-n) n="$2"; shift 2;; *) i="$1"; shift;; esac; done
            mkdir -p "'"$PREFIX"'/var/lib/proot-distro/containers/${n:-$i}/rootfs/etc"; fi; exit 0'
    tx_load prootdesk
}

desk() { tx_prootdesk_install "$@"; }   # base de apps theme dpi tweaks user shell zsh

@test "installs the distro, the desktop and Termux's display and sound" {
    desk debian xfce "" dark auto "" sam bash ""
    grep -q "pkg install -y .*termux-x11-nightly" "$CALLS"
    grep -q "pkg install -y .*pulseaudio" "$CALLS"
    grep -q "^proot-distro|install|debian" "$CALLS"
    grep -q "apt-get install -y .*xfce4 .*xfce4-terminal" "$CALLS"
    grep -q "apt-get install -y .*dbus-x11" "$CALLS"
}

@test "creates your account with passwordless sudo" {
    desk debian xfce "" dark auto "" sam bash ""
    grep -q "useradd -m -s /bin/bash .*sam" "$CALLS"
    grep -q "sam ALL=(ALL) NOPASSWD: ALL" "$CALLS"
}

@test "apps use the distro's package names" {
    desk debian xfce "firefox,vlc,python,build" dark auto "" sam bash ""
    for p in firefox-esr vlc python3 python3-pip build-essential; do
        grep -q "apt-get install -y .*\b$p\b" "$CALLS" || { echo "missing $p"; return 1; }
    done
}

@test "VS Code on a distro is Microsoft's own build for this CPU" {
    desk ubuntu xfce "vscode" dark auto "" sam bash ""
    grep -q "code.visualstudio.com.*linux-deb-" "$CALLS"
    grep -q "dpkg --print-architecture" "$CALLS"
}

@test "each desktop installs and starts its own session" {
    for pair in "xfce:xfce4:startxfce4" "lxqt:lxqt-core:startlxqt" "mate:mate-desktop-environment-core:mate-session" "kde:kde-plasma-desktop:startplasma-x11"; do
        IFS=: read -r de pkg cmd <<<"$pair"
        : > "$CALLS"; rm -f "$HOME/start-linux.sh"
        desk debian "$de" "" dark auto "" sam bash ""
        grep -q "apt-get install -y .*$pkg" "$CALLS" || { echo "$de: no $pkg"; return 1; }
        grep -q "$cmd" "$HOME/start-linux.sh" || { echo "$de: launcher doesn't run $cmd"; return 1; }
    done
}

@test "the launcher and stop script are valid bash" {
    desk debian kde "" dark auto "" sam bash ""
    bash -n "$HOME/start-linux.sh"
    bash -n "$HOME/stop-linux.sh"
}

@test "the launcher starts Termux:X11 and sound in Termux, then the desktop in the distro as you" {
    desk debian xfce "" dark auto "wakelock" sam bash ""
    for c in termux-x11 pulseaudio termux-wake-lock pkill sleep; do
        stub "$c" "echo \"$c \$*\" >> \"\$CALLS\""
    done
    : > "$CALLS"
    PATH="$BATS_TEST_TMPDIR/stubs:/usr/bin:/bin" bash "$HOME/start-linux.sh" >/dev/null 2>&1 || true
    grep -q "^termux-x11 :0" "$CALLS"
    grep -q "^pulseaudio --start.*module-native-protocol-tcp" "$CALLS"
    grep -q "^termux-wake-lock" "$CALLS"
    grep -q "^proot-distro|login|debian|--user|sam|--shared-tmp|--|.*DISPLAY=:0.*startxfce4" "$CALLS"
}

@test "KDE in a distro runs without compositing" {
    desk debian kde "" dark auto "" sam bash ""
    grep -q "KWIN_COMPOSE=N" "$HOME/start-linux.sh"
}

@test "theme and DPI are applied when the desktop starts" {
    desk debian xfce "" light 170 "touch" sam bash ""
    f="$PD/containers/debian/rootfs/usr/local/bin/terminux-session"
    [ -x "$f" ]
    grep -q "Xft.dpi: 170" "$f"
    grep -q "Adwaita" "$f"
    grep -q "Default-xhdpi" "$f"
    grep -q "terminux-session" "$PD/containers/debian/rootfs/home/sam/.config/autostart/terminux.desktop"
}

@test "terminal only: the distro and account, no desktop or launcher" {
    desk ubuntu none "python" dark auto "" sam bash ""
    grep -q "^proot-distro|install|ubuntu" "$CALLS"
    run grep -c "xfce4\|termux-x11-nightly" "$CALLS"
    [ "$output" = 0 ]
    [ ! -e "$HOME/start-linux.sh" ]
}

@test "remembers which distro the desktop is in" {
    desk ubuntu mate "" dark auto "" sam bash ""
    grep -qx "base=ubuntu" "$HOME/.config/terminux/config"
}

@test "zsh users get their zsh extras inside the distro too, as themselves" {
    desk debian xfce "" dark auto "" sam zsh "ohmyzsh,powerlevel10k"
    grep -q "useradd -m -s /usr/bin/zsh .*sam" "$CALLS"
    grep -q "^proot-distro|login|debian|--user|sam|.*tx_shell_setup zsh ohmyzsh,powerlevel10k" "$CALLS"
}
