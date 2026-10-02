#!/bin/bash
# Every Termux package terminux installs exists in this architecture's repos.
. /repo/tests/container/lib.sh
prepare
names=$(
    { grep -oE 'safe_install_pkg "[a-z0-9][^"$]*"' /repo/setup/termux-linux-setup.sh | cut -d'"' -f2
      sed -n '/^app_packages()/,/^}/p' /repo/setup/termux-linux-setup.sh | grep -oE 'echo "[^"]+"' | cut -d'"' -f2
      grep -vE '^(#|$)' /repo/catalog.tsv | awk -F'\t' '$4 == "pkg" { print $5 }'
      grep -oE 'pkg install -y [a-z0-9 .+_-]+' /repo/lib/*.sh | sed 's/.*pkg install -y //'
    } | tr ' ' '\n' | sed '/^$/d' | sort -u)
for p in $names; do
    c=$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ { print $2 }')
    if [ -n "$c" ] && [ "$c" != "(none)" ]; then pass "package $p ($c)"; else fail "package $p does not exist"; fi
done
done_checks
