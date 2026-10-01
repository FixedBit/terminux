#!/usr/bin/env bats
# lib/netbird.sh: rootless NetBird. The setup key must never reach argv,
# the process list, logs or disk after enrollment.

load helpers

setup() {
    tx_sandbox
    unset NB_SETUP_KEY NB_SETUP_KEY_FILE NB_MANAGEMENT_URL NB_HOSTNAME
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    export NBH="$HOME/.local/state/terminux/netbird"
    export TERMUX_VERSION=0.118   # pretend to be in Termux
    stub getprop '[ "$1" = ro.product.model ] && echo "SM-F956B"; exit 0'
    stub pgrep 'exit 1'
    # GitHub API + release download
    stub curl 'case "$*" in
        *api.github.com*) echo "  \"tag_name\": \"v0.80.0\"," ;;
        *) while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
           d=$(mktemp -d); printf "#!/bin/sh\necho netbird \"\$@\"\n" > "$d/netbird"; chmod +x "$d/netbird"
           tar -czf "$out" -C "$d" netbird ;;
        esac'
    # proot: log argv; on "up", copy the key file it was pointed at and
    # remember that we're enrolled, so "status" reports Connected after.
    stub proot 'printf "proot" >> "$CALLS"; for a in "$@"; do printf "|%s" "$a" >> "$CALLS"; done; echo >> "$CALLS"
        prev=""; for a in "$@"; do
            if [ "$prev" = --setup-key-file ]; then cp "'"$NBH"'/lib/$(basename "$a")" "'"$BATS_TEST_TMPDIR"'/key-seen"; fi
            prev="$a"; done
        case "$*" in *" up "*|*" up") : > "'"$BATS_TEST_TMPDIR"'/enrolled";; esac
        case "$*" in *" status"*) [ -e "'"$BATS_TEST_TMPDIR"'/enrolled" ] && echo "Management: Connected"; echo "NetBird IP: 100.64.1.2/16";; esac
        case "$*" in *"service run"*) mkdir -p "'"$NBH"'/run"; : > "'"$NBH"'/run/netbird.sock";; esac
        exit 0'
    stub mkfifo 'exit 1'
}

join() { bash "$TX" netbird join "$@"; }

@test "join downloads the static arm64 client for the latest release" {
    NB_SETUP_KEY=k1 join
    [ -x "$NBH/bin/netbird" ]
}

@test "join hands the key over in a file, never on the command line" {
    NB_SETUP_KEY=sekrit-key-123 join
    [ "$(cat "$BATS_TEST_TMPDIR/key-seen")" = sekrit-key-123 ]
    run grep -c sekrit-key-123 "$CALLS"
    [ "$output" = 0 ]
}

@test "the key file is gone after joining" {
    NB_SETUP_KEY=sekrit-key-123 join
    run grep -rl sekrit-key-123 "$HOME"
    [ -z "$output" ]
}

@test "join runs in netstack mode with local forwarding" {
    NB_SETUP_KEY=k join
    grep -q "NB_USE_NETSTACK_MODE=true" "$CALLS"
    grep -q "NB_ENABLE_NETSTACK_LOCAL_FORWARDING=true" "$CALLS"
}

@test "join passes the management URL only when one is given" {
    NB_SETUP_KEY=k join
    run grep -c -- "--management-url" "$CALLS"
    [ "$output" = 0 ]
    : > "$CALLS"; rm -f "$BATS_TEST_TMPDIR/enrolled"
    NB_SETUP_KEY=k NB_MANAGEMENT_URL=https://nb.example.com join
    grep -q -- "--management-url|https://nb.example.com" "$CALLS"
}

@test "the peer name defaults to termux-<model>" {
    NB_SETUP_KEY=k join
    grep -q -- "--hostname|termux-SM-F956B" "$CALLS"
}

@test "the key can come from private.env" {
    mkdir -p "$HOME/.config/terminux"
    printf 'NB_SETUP_KEY=from-private\n' > "$HOME/.config/terminux/private.env"
    join
    [ "$(cat "$BATS_TEST_TMPDIR/key-seen")" = from-private ]
}

@test "the key is prompted for when nothing else provides it" {
    printf 'typed-key\n' | TERMINUX_TTY=0 bash "$TX" netbird join
    [ "$(cat "$BATS_TEST_TMPDIR/key-seen")" = typed-key ]
}

@test "join with no key at all fails clearly" {
    run bash "$TX" netbird join </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"setup key"* ]]
}

@test "boot writes a Termux:Boot script that starts NetBird" {
    NB_SETUP_KEY=k join
    bash "$TX" netbird boot
    [ -x "$HOME/.termux/boot/terminux-netbird" ]
    grep -q "terminux netbird start" "$HOME/.termux/boot/terminux-netbird"
}

@test "status before joining says how to join" {
    run bash "$TX" netbird status
    [[ "$output" == *"terminux netbird join"* ]]
}

@test "downloads the NetBird build for this CPU" {
    stub curl 'echo "curl $*" >> "$CALLS"; case "$*" in
        *api.github.com*) echo "  \"tag_name\": \"v0.80.0\"," ;;
        *) while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
           d=$(mktemp -d); printf "#!/bin/sh\n" > "$d/netbird"; tar -czf "$out" -C "$d" netbird ;;
        esac'
    for pair in aarch64:arm64 x86_64:amd64 armv7l:armv6; do
        stub uname "[ \"\$1\" = -m ] && echo ${pair%%:*}"
        rm -rf "$NBH"; : > "$CALLS"
        NB_SETUP_KEY=k bash "$TX" netbird join >/dev/null 2>&1 || true
        grep -q "netbird_0.80.0_linux_${pair#*:}.tar.gz" "$CALLS" || { echo "wrong build for ${pair%%:*}"; cat "$CALLS"; return 1; }
    done
}

@test "a daemon that started but never joined isn't reported as enrolled" {
    mkdir -p "$NBH/lib"; echo '{}' > "$NBH/lib/config.json"
    run bash "$TX" status
    [[ "$output" == *"NetBird"*"not set up"* ]]
}

@test "after a successful join the phone counts as enrolled" {
    NB_SETUP_KEY=k join
    stub pgrep 'exit 1'
    run bash "$TX" status
    [[ "$output" == *"NetBird"*"enrolled"* ]]
}
