# shellcheck shell=bash
# terminux -- terminux doctor: find known problems and say how to fix them.
# The check-list approach is adapted from ternux's doctor; see NOTICE.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/detect.sh
. "$TX_LIB/detect.sh"
# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

TX_DOC_FAILS=0
TX_DOC_WARNS=0

_doc_ok()   { tx_ok "$1"; }
_doc_warn() { tx_warn "$1"; tx_hint "fix: $2"; TX_DOC_WARNS=$((TX_DOC_WARNS + 1)); }
_doc_fail() { tx_fail "$1"; tx_hint "fix: $2"; TX_DOC_FAILS=$((TX_DOC_FAILS + 1)); }

cmd_doctor() {
    TX_DOC_FAILS=0 TX_DOC_WARNS=0
    local launcher="$HOME/start-linux.sh"
    [ -f "$launcher" ] || launcher="$HOME/start-x11.sh"

    if tx_is_termux; then _doc_ok "Running in Termux"
    else _doc_fail "Not running in Termux" "terminux only works inside the Termux app on Android"; fi

    local arch; arch=$(uname -m)
    if [ "$arch" = aarch64 ]; then _doc_ok "64-bit ARM ($arch)"
    else _doc_warn "CPU architecture is $arch" "most packages and the NetBird client assume aarch64"; fi

    local free; free=$(tx_detect_storage_gb)
    if [ -n "$free" ] && [ "$free" -lt 3 ] 2>/dev/null; then
        _doc_warn "Only ${free} GB of storage free" "a desktop needs about 3 GB, each environment 0.5-2 GB more"
    fi

    if [ -f "$launcher" ]; then
        _doc_ok "Desktop installed ($(basename "$launcher"))"
        if grep -qF '\nexec' "$launcher"; then
            _doc_fail "The desktop launcher runs 'nexec' instead of starting KDE" "terminux fix"
        fi
    else
        _doc_warn "No desktop installed" "bash $TERMINUX_HOME/install.sh"
    fi

    if grep -qE '^export KWIN_COMPOSE=O2ES' "$TERMINUX_GPU_CFG" 2>/dev/null; then
        _doc_fail "KWIN_COMPOSE=O2ES makes KWin exit, so windows lose their title bars" "terminux fix"
    fi

    if [ -e "$PREFIX/tmp/.X0-lock" ] && ! tx_desktop_running; then
        _doc_warn "A stale X lock ($PREFIX/tmp/.X0-lock) will give a black screen" "terminux fix"
    fi

    case "$(tx_detect_phantom_killer)" in
        enabled) _doc_warn "Android's phantom process killer is on; it kills the desktop with signal 9" "terminux fix phantom" ;;
        disabled) _doc_ok "Android's phantom process killer is off" ;;
    esac

    case "$(tx_detect_vulkan_driver)" in
        turnip)   _doc_ok "GPU acceleration: Turnip" ;;
        software) _doc_warn "Turnip doesn't support this GPU yet; the desktop uses software rendering" "nothing to do now; a Mesa update may add support (pkg upgrade)" ;;
    esac

    if tx_has code-oss && ! grep -qs '"password-store"' "$HOME/.vscode-oss/argv.json"; then
        _doc_warn "VS Code can't save sign-ins without \"password-store\": \"basic\"" "terminux fix"
    fi

    if [ -d "$HOME/.local/share/cursor-agent" ] || [ -e "$HOME/.local/bin/agent" ]; then
        _doc_warn "A Cursor CLI installed straight into Termux can't run (it needs glibc)" "terminux app cursor"
    fi

    echo
    if [ "$TX_DOC_FAILS" -eq 0 ] && [ "$TX_DOC_WARNS" -eq 0 ]; then
        tx_ok "No problems found."
    else
        echo "$TX_DOC_FAILS problem(s), $TX_DOC_WARNS warning(s)."
    fi
    [ "$TX_DOC_FAILS" -eq 0 ]
}
