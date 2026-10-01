# shellcheck shell=bash
# terminux -- NetBird mesh without root (netstack mode).
# See docs/NETBIRD.md and docs/adr/0004-netbird-netstack.md.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"
# shellcheck source=lib/private.sh
. "$TX_LIB/private.sh"

TX_NB_BIN="$TX_NB_HOME/bin/netbird"

# The NetBird client hard-codes /var/lib/netbird, /etc/netbird, /var/run and
# /var/log/netbird, which Termux can't write, and Go's resolver needs
# /etc/resolv.conf, which Android doesn't have. proot maps all of them onto
# terminux's state directory; -0 satisfies the client's root check.
_tx_nb_argv() {
    TX_NB_ARGV=(
        -0
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
        -b "$TX_NB_HOME/lib:/var/lib/netbird"
        -b "$TX_NB_HOME/etc:/etc/netbird"
        -b "$TX_NB_HOME/run:/var/run"
        -b "$TX_NB_HOME/log:/var/log/netbird"
        env SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
            NB_USE_NETSTACK_MODE=true
            NB_ENABLE_NETSTACK_LOCAL_FORWARDING=true
        "$TX_NB_BIN" --daemon-addr unix:///var/run/netbird.sock
    )
}

_tx_nb() { _tx_nb_argv; proot "${TX_NB_ARGV[@]}" "$@"; }

_tx_nb_daemon_running() { pgrep -f "$TX_NB_BIN.* service run" >/dev/null 2>&1; }

tx_nb_install() {
    tx_has proot && tx_has curl || pkg install -y proot curl ca-certificates || return 1
    mkdir -p "$TX_NB_HOME"/{bin,lib,etc,run,log}
    local ver="${NB_VERSION:-}"
    if [ -z "$ver" ]; then
        ver=$(curl -fsSL https://api.github.com/repos/netbirdio/netbird/releases/latest \
              | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)
        [ -n "$ver" ] || { tx_fail "couldn't look up the latest NetBird release (set NB_VERSION)"; return 1; }
    fi
    if [ -x "$TX_NB_BIN" ] && [ "$(cat "$TX_NB_HOME/bin/version" 2>/dev/null)" = "$ver" ]; then
        return 0
    fi
    tx_info "Downloading NetBird $ver"
    local tmp; tmp=$(mktemp -d)
    # The linux arm64 release is a static Go binary, so it runs on Android.
    if curl -fsSL -o "$tmp/nb.tgz" \
        "https://github.com/netbirdio/netbird/releases/download/v${ver}/netbird_${ver}_linux_arm64.tar.gz" \
        && tar -xzf "$tmp/nb.tgz" -C "$tmp" netbird; then
        install -m 755 "$tmp/netbird" "$TX_NB_BIN"
        echo "$ver" > "$TX_NB_HOME/bin/version"
    else
        rm -rf "$tmp"; tx_fail "NetBird download failed"; return 1
    fi
    rm -rf "$tmp"
}

tx_nb_start() {
    [ -x "$TX_NB_BIN" ] || { tx_fail "NetBird isn't installed. Run: terminux netbird join"; return 1; }
    _tx_nb_daemon_running && return 0
    rm -f "$TX_NB_HOME/run/netbird.sock"
    _tx_nb_argv
    nohup proot "${TX_NB_ARGV[@]}" service run >> "$TX_NB_HOME/log/daemon.out" 2>&1 < /dev/null &
    local _
    for _ in $(seq 1 40); do
        [ -e "$TX_NB_HOME/run/netbird.sock" ] && return 0
        sleep 0.25
    done
    tx_fail "The NetBird daemon didn't start; see $TX_NB_HOME/log/daemon.out"
    return 1
}

# Setup key, first match wins: NB_SETUP_KEY, NB_SETUP_KEY_FILE,
# ~/.config/terminux/private.env, then a prompt.
_tx_nb_read_key() {
    local key=""
    tx_private_load_default
    if [ -n "${NB_SETUP_KEY:-}" ]; then
        key="$NB_SETUP_KEY"
    elif [ -n "${NB_SETUP_KEY_FILE:-}" ] && [ -f "$NB_SETUP_KEY_FILE" ]; then
        key=$(tr -d ' \r\n' < "$NB_SETUP_KEY_FILE")
    elif [ -t 0 ]; then
        read -rsp "NetBird setup key (hidden): " key; echo >&2
    else
        read -r key || true
    fi
    printf '%s' "$key"
}

_tx_nb_hostname() {
    local model
    model=$(tx_getprop ro.product.model | tr -c 'A-Za-z0-9\n-' '-')
    model="${model%-}"
    echo "termux-${model:-phone}"
}

tx_nb_join() {
    tx_nb_install || return 1
    tx_nb_start || return 1
    if _tx_nb status 2>/dev/null | grep -q "Management: Connected"; then
        tx_ok "Already on the mesh."
        return 0
    fi
    local key; key=$(_tx_nb_read_key)
    unset NB_SETUP_KEY
    [ -n "$key" ] || { tx_fail "No NetBird setup key given. See docs/NETBIRD.md for the ways to pass one."; return 1; }

    # The key goes to netbird as a file only we can read, inside the bound
    # state directory, so it never shows up in ps; it's deleted right after.
    local name=".setup-key.$$" rc
    ( umask 077; printf '%s' "$key" > "$TX_NB_HOME/lib/$name" )
    key=""
    local -a args=(up --setup-key-file "/var/lib/netbird/$name" --hostname "${NB_HOSTNAME:-$(_tx_nb_hostname)}")
    [ -n "${NB_MANAGEMENT_URL:-}" ] && args+=(--management-url "$NB_MANAGEMENT_URL")
    _tx_nb "${args[@]}"; rc=$?
    rm -f "$TX_NB_HOME/lib/$name"
    [ "$rc" -eq 0 ] || { tx_fail "netbird up failed; see: terminux netbird logs"; return 1; }
    _tx_nb status
    tx_ok "This phone is on your NetBird mesh. The setup key isn't needed again."
}

cmd_netbird() {
    local sub="${1:-status}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        join)   tx_nb_join ;;
        start)  tx_nb_start && _tx_nb up >/dev/null 2>&1; _tx_nb status ;;
        stop)
            _tx_nb down >/dev/null 2>&1
            pkill -f "$TX_NB_BIN.* service run" 2>/dev/null
            rm -f "$TX_NB_HOME/run/netbird.sock"
            tx_ok "NetBird stopped." ;;
        down)   _tx_nb down ;;
        status)
            if [ "$(tx_netbird_state)" = "not set up" ] && [ ! -x "$TX_NB_BIN" ]; then
                echo "NetBird isn't set up. Join a mesh with: terminux netbird join"
                return 0
            fi
            _tx_nb status "$@" ;;
        logs)   tail -n 50 "$TX_NB_HOME/log/client.log" "$TX_NB_HOME/log/daemon.out" 2>/dev/null ;;
        boot)
            mkdir -p "$HOME/.termux/boot"
            cat > "$HOME/.termux/boot/terminux-netbird" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Started by the Termux:Boot app at boot. Written by terminux.
termux-wake-lock
terminux netbird start
EOF
            chmod +x "$HOME/.termux/boot/terminux-netbird"
            tx_ok "NetBird will start at boot (install the Termux:Boot app and open it once)." ;;
        *) tx_fail "usage: terminux netbird [join|start|stop|status|down|logs|boot]"; return 2 ;;
    esac
}
