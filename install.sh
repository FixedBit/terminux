#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  terminux installer.
#
#    curl -fsSL https://raw.githubusercontent.com/FixedBit/terminux/main/install.sh | bash -s -- [options]
#
#  Piped from curl, it first clones terminux and re-runs itself from the
#  checkout with the terminal attached. Build the options at
#  https://fixedbit.github.io/terminux/ or run: bash install.sh --help
#
#  SPDX-License-Identifier: Apache-2.0
# =============================================================================
set -u

TERMINUX_HOME="${TERMINUX_HOME:-$HOME/.local/share/terminux}"
TERMINUX_GIT="${TERMINUX_GIT:-https://github.com/FixedBit/terminux.git}"
TERMINUX_REF="${TERMINUX_REF:-main}"

# --- Stage 1: bootstrap when not running from a checkout ---------------------
_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P)"
if [ ! -f "${_here:-}/lib/options.sh" ]; then
    echo "[ .. ] Fetching terminux ($TERMINUX_REF) into $TERMINUX_HOME"
    command -v git >/dev/null 2>&1 || pkg install -y git || exit 1
    if [ -d "$TERMINUX_HOME/.git" ]; then
        git -C "$TERMINUX_HOME" fetch --quiet origin "$TERMINUX_REF" \
            && git -C "$TERMINUX_HOME" checkout --quiet "$TERMINUX_REF" \
            && git -C "$TERMINUX_HOME" pull --quiet --ff-only || exit 1
    else
        mkdir -p "$(dirname "$TERMINUX_HOME")"
        git clone --quiet --branch "$TERMINUX_REF" "$TERMINUX_GIT" "$TERMINUX_HOME" || exit 1
    fi
    # stdin is this script when piped from curl; give prompts the terminal.
    if [ -r /dev/tty ]; then
        exec bash "$TERMINUX_HOME/install.sh" "$@" < /dev/tty
    fi
    exec bash "$TERMINUX_HOME/install.sh" "$@"
fi

# --- Stage 2: running from the checkout --------------------------------------
TX_LIB="$_here/lib"
# shellcheck source=lib/core.sh
. "$TX_LIB/core.sh"
# shellcheck source=lib/options.sh
. "$TX_LIB/options.sh"

usage() {
    cat <<EOF
Usage: bash install.sh [options]

Options (build them visually at https://fixedbit.github.io/terminux/):
$(tx_opt_help)

  --yes          install with these options without asking (the web wizard adds this)
  --private SRC  load private values (NetBird key, ...) from a file or https link
  --dry-run      print the plan and exit
  -h, --help     this help

Docs: $TERMINUX_REPO_URL
EOF
}

DRY_RUN=0
ASSUME_YES=0
tx_opt_defaults
while [ $# -gt 0 ]; do
    arg="$1"; shift
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --dry-run) DRY_RUN=1; continue ;;
        --yes|-y) ASSUME_YES=1; continue ;;
        --private=*) TX_PRIVATE_SRC="${arg#*=}"; continue ;;
        --private) TX_PRIVATE_SRC="${1:-}"; shift; continue ;;
        --*=*) key="${arg%%=*}"; key="${key#--}"; value="${arg#*=}" ;;
        --no-*)
            key="${arg#--no-}"
            if [ -n "${TX_OPT_SPEC[$key]:-}" ] && tx_opt_is_bool "$key"; then
                value=no
            else
                tx_fail "unknown option: $arg"; exit 2
            fi ;;
        --*)
            key="${arg#--}"
            if [ -n "${TX_OPT_SPEC[$key]:-}" ] && tx_opt_is_bool "$key"; then
                value=""
            else
                value="${1:-}"; shift
            fi ;;
        *) tx_fail "unexpected argument: $arg"; exit 2 ;;
    esac
    tx_opt_set "$key" "$value" || exit 2
done

# No options and someone at the keyboard: walk them through it. Commands
# from the web wizard always carry options (at least --yes), so they don't.
if [ ${#TX_SET[@]} -eq 0 ] && [ "$ASSUME_YES" = 0 ] \
    && { [ -t 0 ] || [ "${TERMINUX_TTY:-0}" = 1 ]; }; then
    # shellcheck source=lib/tui.sh
    . "$TX_LIB/tui.sh"
    tx_tui_run || exit 0
fi

tx_opt_apply_rules || exit 2

if [ "$DRY_RUN" = 1 ]; then
    tx_opt_print_plan
    exit 0
fi

# shellcheck source=lib/install.sh
. "$TX_LIB/install.sh"
tx_install_run
