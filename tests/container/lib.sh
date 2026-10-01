# Shared helpers for container checks. These run INSIDE a termux-docker
# container with the repo mounted read-only at /repo.
set -u
export DEBIAN_FRONTEND=noninteractive TERMUX_VERSION=container
PASS=0 FAIL=0
pass() { echo "PASS  $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }
check() { local what="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi; }
done_checks() { echo "== $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
prepare() {
    pkg update -y >/dev/null 2>&1
    pkg install -y x11-repo tur-repo >/dev/null 2>&1
    apt-get update >/dev/null 2>&1
    [ $# -gt 0 ] && pkg install -y "$@" >/dev/null 2>&1
    return 0
}
