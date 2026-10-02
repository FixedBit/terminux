#!/usr/bin/env bats
# lib/report.sh: terminux report gathers what's needed to debug, minus secrets.

load helpers

setup() {
    tx_sandbox
    export TERMUX_VERSION=0.118
    stub getprop 'case "$1" in ro.product.model) echo SM-F956B;; ro.build.version.release) echo 16;; ro.build.version.sdk) echo 36;; esac'
    stub pgrep 'exit 1'
    stub uname '[ "$1" = -m ] && echo aarch64 || echo Linux'
    stub dpkg 'echo "dpkg $*"'
    stub apt-cache 'echo "apt-cache $*"'
    mkdir -p "$HOME/.config/terminux" "$HOME/.local/state/terminux/logs" "$PREFIX/etc/apt"
    printf 'user=jason\nshell=zsh\n' > "$HOME/.config/terminux/config"
    echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
    printf 'E: something broke\n' > "$HOME/.local/state/terminux/logs/pkg-upgrade-20261001-120000.log"
    printf 'step 3 failed\n' > "$HOME/termux-setup.log"
}

@test "report writes one file and says where it is" {
    run bash "$TX" report
    [ "$status" -eq 0 ]
    f=$(ls "$HOME"/terminux-report-*.txt)
    [ -f "$f" ]
    [[ "$output" == *"$f"* ]] || [[ "$output" == *"terminux-report-"* ]]
}

@test "report includes device info, doctor, config, repos and recent logs" {
    bash "$TX" report >/dev/null
    f=$(ls "$HOME"/terminux-report-*.txt)
    for want in "SM-F956B" "doctor" "user=jason" "termux-main" "E: something broke" "step 3 failed" "dpkg --audit"; do
        grep -q -- "$want" "$f" || { echo "report lacks: $want"; return 1; }
    done
}

@test "report never contains private values" {
    printf 'NB_SETUP_KEY=11111111-2222-3333-4444-555555555555\nNB_MANAGEMENT_URL=https://netbird.example.com\n' > "$HOME/.config/terminux/private.env"
    echo "join with key 11111111-2222-3333-4444-555555555555 token=ghp_abcdefghijklmnopqrstuvwxyz0123456789" >> "$HOME/termux-setup.log"
    bash "$TX" report >/dev/null
    f=$(ls "$HOME"/terminux-report-*.txt)
    run grep -cE "11111111-2222|ghp_abcdef|netbird.example.com" "$f"
    [ "$output" = 0 ]
    grep -q "REDACTED" "$f"
}
