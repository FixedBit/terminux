# shellcheck shell=bash
# terminux -- a desktop running inside a distro (Debian or Ubuntu, under
# proot-distro), shown on Termux:X11 with sound through Termux's PulseAudio.
# The native Termux desktop is setup/termux-linux-setup.sh instead.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

TX_DISTRO_COMMON_PKGS="sudo locales ca-certificates curl git dbus-x11 x11-xserver-utils pulseaudio-utils fonts-noto-core"

# Desktop packages and the command that starts its session.
tx_distro_de_packages() {
    case "$1" in
        xfce) echo "xfce4 xfce4-terminal" ;;
        lxqt) echo "lxqt-core qterminal" ;;
        mate) echo "mate-desktop-environment-core mate-terminal" ;;
        kde)  echo "kde-plasma-desktop konsole" ;;
    esac
}
tx_distro_de_session() {
    case "$1" in
        xfce) echo "startxfce4" ;;
        lxqt) echo "startlxqt" ;;
        mate) echo "mate-session" ;;
        kde)  echo "startplasma-x11" ;;
    esac
}

# App id (options.json "apps") -> apt packages. vscode is handled separately.
tx_distro_app_packages() {
    local base="$1" app="$2"
    case "$app" in
        firefox)     [ "$base" = debian ] && echo "firefox-esr" ;;
        chromium)    [ "$base" = debian ] && echo "chromium" ;;
        vlc)         echo "vlc" ;;
        gimp)        echo "gimp" ;;
        libreoffice) echo "libreoffice" ;;
        python)      echo "python3 python3-pip python3-venv" ;;
        nodejs)      echo "nodejs npm" ;;
        build)       echo "build-essential cmake pkg-config" ;;
    esac
    return 0
}

_tx_distro_rootfs() {
    local d
    for d in "$TX_PD_DIR/containers/$1/rootfs" "$TX_PD_DIR/installed-rootfs/$1"; do
        [ -d "$d" ] && { echo "$d"; return 0; }
    done
    return 1
}

# Runs once the desktop session is up: DPI, theme, touch-friendly borders.
_tx_distro_session_script() {
    local theme="$1" dpi="$2" tweaks=",$3," gtk_name=Adwaita-dark
    [ "$theme" = light ] && gtk_name=Adwaita
    echo '#!/bin/sh'
    echo '# Written by terminux: applied each time the desktop starts.'
    [ -n "$dpi" ] && [ "$dpi" != auto ] && echo "echo 'Xft.dpi: $dpi' | xrdb -merge"
    echo 'command -v xfconf-query >/dev/null 2>&1 || exit 0'
    [ -n "$dpi" ] && [ "$dpi" != auto ] && echo "xfconf-query -c xsettings -p /Xft/DPI -n -t int -s $dpi"
    echo "xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s $gtk_name"
    [[ "$tweaks" == *,touch,* ]] && echo "xfconf-query -c xfwm4 -p /general/theme -n -t string -s Default-xhdpi"
    return 0
}

_tx_distro_write_launchers() {
    local base="$1" de="$2" user="$3" theme="$4" tweaks=",$5,"
    local session gtk=Adwaita:dark
    session=$(tx_distro_de_session "$de")
    [ "$theme" = light ] && gtk=Adwaita
    local wakelock=0 oneui=0 kwin=""
    [[ "$tweaks" == *,wakelock,* ]] && wakelock=1
    [[ "$tweaks" == *,oneui-audio,* ]] && oneui=1
    [ "$de" = kde ] && kwin="KWIN_COMPOSE=N"

    cat > "$HOME/start-linux.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# Written by terminux: the $de desktop inside $base, on Termux:X11.
# Start it with: terminux start
[ $wakelock = 1 ] && command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

# A killed X server leaves its lock behind; clear it before starting again.
pkill -9 -f "termux.x11" 2>/dev/null
rm -f "$PREFIX/tmp/.X0-lock"; rm -rf "$PREFIX/tmp/.X11-unix"

# Sound: PulseAudio in Termux, reached from the distro over TCP. One UI needs
# libskcodec preloaded (termux-packages #19623).
pulseaudio --kill 2>/dev/null
LIB=/system/lib64/libskcodec.so
if [ $oneui = 1 ] && [ -f "\$LIB" ]; then
    LD_PRELOAD="\$LIB" pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1"
else
    pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1"
fi

termux-x11 :0 -ac &
sleep 3

exec proot-distro login $base --user $user --shared-tmp -- env DISPLAY=:0 PULSE_SERVER=127.0.0.1 XDG_RUNTIME_DIR=/tmp GTK_THEME=$gtk $kwin dbus-launch --exit-with-session $session
EOF
    cat > "$HOME/stop-linux.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# Written by terminux: stops the $de desktop inside $base.
pkill -f "proot-distro login $base" 2>/dev/null
pkill -9 -f "termux.x11" 2>/dev/null
pulseaudio --kill 2>/dev/null
rm -f "$PREFIX/tmp/.X0-lock"; rm -rf "$PREFIX/tmp/.X11-unix"
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
echo "[ok] Desktop stopped."
EOF
    chmod +x "$HOME/start-linux.sh" "$HOME/stop-linux.sh"
}

# tx_prootdesk_install <base> <de> <apps> <theme> <dpi> <tweaks> <user> <shell> <zsh extras>
tx_prootdesk_install() {
    local base="$1" de="$2" apps="$3" theme="$4" dpi="$5" tweaks="$6" user="$7" shell="${8:-bash}" zsh="${9:-}"
    local login_shell=/bin/bash pkgs="$TX_DISTRO_COMMON_PKGS" app
    [ "$shell" = zsh ] && { login_shell=/usr/bin/zsh; pkgs+=" zsh"; }

    if [ "$de" != none ]; then
        pkg install -y x11-repo >/dev/null 2>&1
        pkg install -y termux-x11-nightly pulseaudio proot-distro || return 1
        pkgs+=" $(tx_distro_de_packages "$de")"
    else
        pkg install -y proot-distro || return 1
    fi
    local -a list
    IFS=',' read -ra list <<< "$apps"
    for app in "${list[@]}"; do
        [ -n "$app" ] && [ "$app" != vscode ] && pkgs+=" $(tx_distro_app_packages "$base" "$app")"
    done

    if ! _tx_distro_rootfs "$base" >/dev/null; then
        tx_step "Installing ${base^} (a few hundred MB)"
        proot-distro install "$base" || { tx_fail "proot-distro couldn't install $base"; return 1; }
    fi

    tx_step "Installing the ${de/none/terminal-only} setup inside ${base^} (the long part)"
    local vscode=""
    if [[ ",$apps," == *,vscode,* ]]; then
        # Microsoft's .deb, for whichever CPU this is.
        vscode='
        case "$(dpkg --print-architecture)" in arm64) a=arm64 ;; amd64) a=x64 ;; armhf) a=armhf ;; *) a="" ;; esac
        if [ -n "$a" ]; then
            curl -fsSL -o /tmp/code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-$a"
            apt-get install -y /tmp/code.deb && rm -f /tmp/code.deb
        fi'
    fi
    proot-distro login "$base" --shared-tmp -- bash -c "
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        apt-get install -y $pkgs
        sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 2>/dev/null && locale-gen >/dev/null || true
        id -u $user >/dev/null 2>&1 || useradd -m -s $login_shell -G sudo $user
        chsh -s $login_shell $user
        for g in audio video; do getent group \$g >/dev/null && usermod -aG \$g $user; done
        echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user
        chmod 0440 /etc/sudoers.d/$user
        $vscode
    " || { tx_fail "Setting up ${base^} failed; see the messages above."; return 1; }

    # The same zsh setup as in Termux, run as you inside the distro.
    if [ "$shell" = zsh ]; then
        proot-distro login "$base" --user "$user" --shared-tmp \
            --bind "$TERMINUX_HOME:/opt/terminux" -- bash -c "
                TX_LIB=/opt/terminux/lib
                . /opt/terminux/lib/core.sh
                . /opt/terminux/lib/shell.sh
                TX_SHELL_GUEST=1 tx_shell_setup zsh $zsh
            " || tx_warn "zsh setup inside ${base^} didn't finish"
    fi

    local rootfs; rootfs=$(_tx_distro_rootfs "$base")
    mkdir -p "$rootfs/etc/profile.d"
    printf '# Written by terminux.\nexport DISPLAY=:0\nexport PULSE_SERVER=127.0.0.1\nexport LANG=en_US.UTF-8\n' \
        > "$rootfs/etc/profile.d/terminux.sh"

    if [ "$de" != none ]; then
        mkdir -p "$rootfs/usr/local/bin" "$rootfs/home/$user/.config/autostart"
        _tx_distro_session_script "$theme" "$dpi" "$tweaks" > "$rootfs/usr/local/bin/terminux-session"
        chmod +x "$rootfs/usr/local/bin/terminux-session"
        printf '[Desktop Entry]\nType=Application\nName=terminux session\nExec=/usr/local/bin/terminux-session\nNoDisplay=true\n' \
            > "$rootfs/home/$user/.config/autostart/terminux.desktop"
        [[ ",$apps," == *,vscode,* ]] && {
            # shellcheck source=lib/apps.sh
            . "$TX_LIB/apps.sh"
            tx_vscode_argv "$rootfs/home/$user/.vscode/argv.json"
        }
        _tx_distro_write_launchers "$base" "$de" "$user" "$theme" "$tweaks"
    fi

    tx_config_set base "$base"
    tx_config_set user "$user"
    if [ "$de" = none ]; then
        tx_ok "${base^} is ready. Open it with: terminux env enter $base"
    else
        tx_ok "${base^} with $de is ready. Start it with: terminux start"
    fi
}
