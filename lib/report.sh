# shellcheck shell=bash
# terminux -- terminux report: everything needed to debug a problem, in one
# file, with private values removed so it's safe to share.
# SPDX-License-Identifier: Apache-2.0

# Remove anything that looks secret: values of private keys, NetBird setup
# keys (UUIDs), tokens, and whatever is in private.env.
_tx_redact() {
    local sed_args=(
        -e 's/\(NB_[A-Z_]*=\).*/\1REDACTED/'
        -e 's/[0-9A-Fa-f]\{8\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{4\}-[0-9A-Fa-f]\{12\}/REDACTED/g'
        -e 's/\(gh[pousr]_\)[A-Za-z0-9]\{20,\}/\1REDACTED/g'
        -e 's/\(sk-[a-z]*-\{0,1\}\)[A-Za-z0-9_-]\{16,\}/\1REDACTED/g'
        -e 's/\([Tt]oken[=:] *\)[^ ]*/\1REDACTED/g'
        -e 's/\([Pp]assword[=:] *\)[^ ]*/\1REDACTED/g'
    )
    # Values from private.env, wherever they appear.
    local f="$TERMINUX_CONFIG_DIR/private.env" line v
    if [ -f "$f" ]; then
        while IFS= read -r line; do
            v="${line#*=}"; v="${v%$'\r'}"; v="${v#\"}"; v="${v%\"}"
            [ ${#v} -ge 6 ] || continue
            v=$(printf '%s' "$v" | sed 's/[][\.*^$/]/\\&/g')
            sed_args+=(-e "s/$v/REDACTED/g")
        done < <(grep -E '^[A-Z_]+=' "$f")
    fi
    sed "${sed_args[@]}"
}

_tx_report_section() { printf '\n===== %s =====\n' "$1"; }

cmd_report() {
    local out f
    out="$HOME/terminux-report-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "terminux report, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "Private values (keys, tokens, private.env) have been replaced with REDACTED."

        _tx_report_section "device"
        bash "$TX_LIB/../bin/terminux" info 2>&1
        echo "Termux: ${TERMUX_VERSION:-unknown} from ${TERMUX_APK_RELEASE:-unknown}"

        _tx_report_section "doctor"
        NO_COLOR=1 bash "$TX_LIB/../bin/terminux" doctor 2>&1

        _tx_report_section "terminux config"
        cat "$TERMINUX_CONFIG" 2>/dev/null || echo "(none)"
        echo "version: $TERMINUX_VERSION ($(git -C "$TERMINUX_HOME" log -1 --format='%h %cs' 2>/dev/null || echo 'not a git checkout'))"

        _tx_report_section "package repositories"
        cat "$PREFIX/etc/apt/sources.list" "$PREFIX"/etc/apt/sources.list.d/*.list 2>/dev/null

        _tx_report_section "dpkg --audit (half-installed packages)"
        dpkg --audit 2>&1 | head -n 40

        _tx_report_section "key packages"
        apt-cache policy termux-x11-nightly mesa mesa-zink vulkan-loader-android proot-distro 2>&1 \
            | grep -E '^[a-z]|Installed|Candidate' | head -n 40

        _tx_report_section "desktop installer log (last 150 lines)"
        tail -n 150 "$HOME/termux-setup.log" 2>/dev/null || echo "(none)"

        for f in $(ls -t "$TERMINUX_STATE_DIR"/logs/*.log 2>/dev/null | head -n 3); do
            _tx_report_section "$(basename "$f") (last 100 lines)"
            tail -n 100 "$f"
        done

        _tx_report_section "desktop log (last 60 lines)"
        tail -n 60 "$TERMINUX_STATE_DIR/desktop.log" 2>/dev/null || echo "(none)"
    } 2>&1 | _tx_redact > "$out"

    tx_ok "Report saved: $out"
    tx_hint "Attach it to an issue at https://github.com/FixedBit/terminux/issues"
    if tx_has termux-share; then
        tx_hint "Or share it from the phone: termux-share \"$out\""
    fi
}
