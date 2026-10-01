# shellcheck shell=bash
# =============================================================================
#  terminux -- core library: paths, output helpers, small utilities.
#  Every other module sources this first.
#
#  Output helpers and the module layout are adapted from ternux
#  (https://github.com/soobujmiah/ternux, Apache-2.0, (c) 2026 Sobuj Miah);
#  modified for terminux. See NOTICE.
# =============================================================================

[ -n "${_TX_CORE_LOADED:-}" ] && return 0
_TX_CORE_LOADED=1

TERMINUX_VERSION="0.1.0"
TERMINUX_REPO_URL="https://github.com/FixedBit/terminux"

# --- Paths --------------------------------------------------------------------
# Everything is overridable so tests can run against a sandboxed $HOME.
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
# The git checkout terminux runs from; `terminux update` pulls here.
TERMINUX_HOME="${TERMINUX_HOME:-$HOME/.local/share/terminux}"
# Non-secret settings (KEY=VALUE). Never sourced, only parsed.
TERMINUX_CONFIG_DIR="${TERMINUX_CONFIG_DIR:-$HOME/.config/terminux}"
TERMINUX_CONFIG="$TERMINUX_CONFIG_DIR/config"
# Runtime state: NetBird identity, logs.
TERMINUX_STATE_DIR="${TERMINUX_STATE_DIR:-$HOME/.local/state/terminux}"
# Written by setup/termux-linux-setup.sh; the launchers source it.
TERMINUX_GPU_CFG="${TERMINUX_GPU_CFG:-$HOME/.config/linux-gpu.sh}"

# --- Output ---------------------------------------------------------------------
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    TX_C0="" TX_G="" TX_Y="" TX_R="" TX_B="" TX_W="" TX_D=""
else
    TX_C0=$'\033[0m' TX_G=$'\033[1;32m' TX_Y=$'\033[1;33m' TX_R=$'\033[1;31m'
    TX_B=$'\033[1;34m' TX_W=$'\033[1;37m' TX_D=$'\033[2m'
fi

tx_info() { printf '%s[ .. ]%s %s\n' "$TX_B" "$TX_C0" "$*"; }
tx_ok()   { printf '%s[ ok ]%s %s\n' "$TX_G" "$TX_C0" "$*"; }
tx_warn() { printf '%s[warn]%s %s\n' "$TX_Y" "$TX_C0" "$*" >&2; }
tx_fail() { printf '%s[fail]%s %s\n' "$TX_R" "$TX_C0" "$*" >&2; }
tx_die()  { tx_fail "$1"; exit "${2:-1}"; }
tx_step() { printf '\n%s==>%s %s%s%s\n' "$TX_B" "$TX_C0" "$TX_W" "$*" "$TX_C0"; }
tx_hint() { printf '       %s%s%s\n' "$TX_D" "$*" "$TX_C0"; }

# --- Environment ------------------------------------------------------------------
tx_has() { command -v "$1" >/dev/null 2>&1; }

tx_is_termux() { [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]; }

tx_require_termux() {
    tx_is_termux || tx_die "This command only works inside Termux on Android."
}

tx_getprop() { getprop "$1" 2>/dev/null || true; }

# Run a command that may hang (termux-x11-preference blocks while the
# Termux-X11 activity is closed) without blocking the caller.
tx_run_detached() {
    if tx_has timeout; then
        ( timeout 5 "$@" >/dev/null 2>&1 & )
    else
        ( "$@" >/dev/null 2>&1 & )
    fi
}

# --- Settings files ----------------------------------------------------------------
# Read KEY from a KEY=VALUE file without sourcing it. Prints the value.
tx_kv_get() {
    local file="$1" key="$2" line
    [ -f "$file" ] || return 1
    line=$(grep -E "^(export +)?${key}=" "$file" | tail -n 1) || return 1
    line="${line#export }"
    line="${line#"${key}"=}"
    line="${line%%#*}"
    line="${line%"${line##*[![:space:]]}"}"
    line="${line#\"}"; line="${line%\"}"
    line="${line#\'}"; line="${line%\'}"
    printf '%s\n' "$line"
}

# Set KEY=VALUE in a file, replacing an existing (or commented-out) entry.
tx_kv_set() {
    local file="$1" key="$2" value="$3" prefix="${4:-}"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^#? *(export +)?${key}=" "$file"; then
        sed -i -E "s|^#? *(export +)?${key}=.*|${prefix}${key}=${value}|" "$file"
    else
        printf '%s%s=%s\n' "$prefix" "$key" "$value" >> "$file"
    fi
}

tx_config_get() { tx_kv_get "$TERMINUX_CONFIG" "$1"; }
tx_config_set() { tx_kv_set "$TERMINUX_CONFIG" "$1" "$2"; }
