# shellcheck shell=bash
# terminux -- package upgrades that explain themselves when they fail.
#
# tx_pkg_diagnose reads apt/dpkg output and names the cause; tx_pkg_explain
# says what it means and how to fix it; tx_pkg_upgrade upgrades Termux,
# repairs the causes that are safe to repair automatically, and otherwise
# stops with a report instead of "see the log".
# SPDX-License-Identifier: Apache-2.0

TX_LOG_DIR="${TX_LOG_DIR:-$TERMINUX_STATE_DIR/logs}"

# Print "cause=<id>" and then the lines that show what went wrong.
tx_pkg_diagnose() {
    local log="$1" cause=unknown
    if grep -qE "Could not resolve|Temporary failure resolving|Network is unreachable|Connection timed out|Failed to connect" "$log"; then
        cause=network
    elif grep -qE "Hash Sum mismatch|File has unexpected size|Release file .* is not valid yet|NOSPLIT|Clearsigned file isn't valid" "$log"; then
        cause=mirror
    elif grep -qE "Could not get lock|Unable to acquire the dpkg frontend lock" "$log"; then
        cause=lock
    elif grep -qE "No space left on device" "$log"; then
        cause=storage
    elif grep -qE "CANNOT LINK EXECUTABLE|cannot locate symbol|library \".*\" not found" "$log"; then
        cause=corelib
    elif grep -qE "dpkg was interrupted" "$log"; then
        cause=interrupted
    elif grep -qE "trying to overwrite" "$log"; then
        cause=overwrite
    elif grep -qE "Unable to locate package|has no installation candidate" "$log"; then
        cause=missing
    elif grep -qE "Unmet dependencies|unmet dependencies|--fix-broken" "$log"; then
        cause=broken
    fi
    echo "cause=$cause"

    case "$cause" in
        overwrite)
            # "trying to overwrite '<file>', which is also in package <pkg> <ver>"
            grep -E "trying to overwrite" "$log" | head -n 3 | sed -E \
                "s/.*trying to overwrite '([^']+)', which is also in package ([^ ]+).*/conflict: \1 (already owned by \2)/"
            grep -oE "archives/[^_]+_" "$log" | head -n 3 | sed -E 's|archives/(.*)_|new package: \1|' ;;
        missing)
            grep -oE "Unable to locate package [^ ]+" "$log" | head -n 5 | sed 's/Unable to locate package /missing: /' ;;
        *)
            grep -E "^(E:|dpkg: error|CANNOT LINK|Err:)|trying to overwrite|No space left|unmet dependencies" "$log" \
                | head -n 6 ;;
    esac
}

tx_pkg_explain() {
    case "$1" in
        overwrite) cat <<'EOF'
Why: two packages both include the same file, so dpkg refuses to install one
     over the other. This usually means another setup script installed its own
     version of a package (often a graphics driver) that Termux now ships too.
Fix: terminux fix packages   (lets the newer package take over the file)
EOF
        ;;
        interrupted) cat <<'EOF'
Why: an earlier install was stopped half way (Termux closed, or Android killed it).
Fix: terminux fix packages   (finishes it with dpkg --configure -a)
EOF
        ;;
        broken) cat <<'EOF'
Why: some installed packages need versions of others that aren't installed yet,
     usually after an install or upgrade stopped part way through.
Fix: terminux fix packages   (runs apt --fix-broken install)
EOF
        ;;
        network) cat <<'EOF'
Why: Termux couldn't reach its package server. Nothing is wrong with your packages.
Fix: check your connection (Wi-Fi, VPN, data saver), then run the install again.
     If it keeps happening, pick another mirror: termux-change-repo
EOF
        ;;
        mirror) cat <<'EOF'
Why: the package mirror served a file that doesn't match its index, usually
     because the mirror is part way through updating.
Fix: termux-change-repo   (choose a different mirror), then run the install again.
EOF
        ;;
        corelib) cat <<'EOF'
Why: a core library was upgraded while programs using the old one were still
     running, so they can't start until Termux restarts.
Fix: close Termux completely (swipe it away in recent apps), reopen it, run
     pkg upgrade, then run the install again.
EOF
        ;;
        missing) cat <<'EOF'
Why: a package wasn't found, so the repository that has it isn't enabled
     (x11-repo or tur-repo), or the package list is out of date.
Fix: pkg install x11-repo tur-repo && pkg update, then run the install again.
EOF
        ;;
        lock) cat <<'EOF'
Why: another install is already running, in another Termux session or a
     background update.
Fix: wait for it to finish (or close the other session), then run the install again.
EOF
        ;;
        storage) cat <<'EOF'
Why: the phone ran out of storage space.
Fix: free some space (a desktop needs about 4 GB), then run: terminux fix packages
EOF
        ;;
        *) cat <<'EOF'
Why: something went wrong that terminux doesn't recognise yet.
Fix: run terminux report and open an issue with the file it makes:
     https://github.com/FixedBit/terminux/issues
EOF
        ;;
    esac
}

# Show a failure the way a person needs to see it.
tx_pkg_report_failure() {
    local what="$1" diag="$2" log="$3" cause
    cause=$(head -n 1 <<< "$diag"); cause="${cause#cause=}"
    echo
    tx_fail "$what failed."
    echo "  What went wrong:"
    tail -n +2 <<< "$diag" | sed 's/^/    /'
    echo
    tx_pkg_explain "$cause" | sed 's/^/  /'
    echo
    echo "  Full log:        $log"
    echo "  Share for help:  terminux report   (device info and logs, with keys removed)"
}

# Run an apt step, logging everything. Leaves its output in $TX_PKG_LAST.
_tx_apt() {
    TX_PKG_LAST=$(mktemp)
    "$@" > "$TX_PKG_LAST" 2>&1
    local rc=$?
    cat "$TX_PKG_LAST" >> "$TX_PKG_LOG"
    return "$rc"
}

TX_APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

_tx_pkg_try_upgrade() {
    _tx_apt apt-get update && _tx_apt apt-get "${TX_APT_OPTS[@]}" full-upgrade
}

# Upgrade Termux's packages, repairing what's safe to repair.
tx_pkg_upgrade() {
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p "$TX_LOG_DIR"
    TX_PKG_LOG="$TX_LOG_DIR/pkg-upgrade-$(date +%Y%m%d-%H%M%S).log"
    : > "$TX_PKG_LOG"

    # An install that was cut off last time has to be finished first.
    _tx_apt dpkg --configure -a

    _tx_pkg_try_upgrade && { rm -f "$TX_PKG_LAST"; return 0; }

    local diag cause
    diag=$(tx_pkg_diagnose "$TX_PKG_LAST")
    cause=$(head -n 1 <<< "$diag"); cause="${cause#cause=}"
    case "$cause" in
        overwrite)
            tx_warn "Two packages both claim the same file:"
            tail -n +2 <<< "$diag" | sed 's/^/       /'
            tx_info "Letting the newer package take the file over, then trying again."
            _tx_apt apt-get -y -o Dpkg::Options::=--force-overwrite install -f ;;
        interrupted)
            tx_info "Finishing an install that was interrupted, then trying again."
            _tx_apt dpkg --configure -a ;;
        broken)
            tx_info "Fixing broken dependencies, then trying again."
            _tx_apt apt-get -y install -f ;;
        *)
            tx_pkg_report_failure "Updating Termux's packages" "$diag" "$TX_PKG_LOG"
            return 1 ;;
    esac

    _tx_pkg_try_upgrade && { tx_ok "That fixed it."; return 0; }
    diag=$(tx_pkg_diagnose "$TX_PKG_LAST")
    tx_pkg_report_failure "Updating Termux's packages" "$diag" "$TX_PKG_LOG"
    return 1
}

# terminux fix packages: the repair sequence, on demand.
tx_pkg_fix() {
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p "$TX_LOG_DIR"
    TX_PKG_LOG="$TX_LOG_DIR/pkg-fix-$(date +%Y%m%d-%H%M%S).log"
    : > "$TX_PKG_LOG"
    tx_info "Finishing interrupted installs"
    _tx_apt dpkg --configure -a
    tx_info "Resolving file conflicts and broken dependencies"
    _tx_apt apt-get -y -o Dpkg::Options::=--force-overwrite install -f
    tx_info "Upgrading"
    tx_pkg_upgrade
}
