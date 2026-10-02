#!/usr/bin/env bash
# Runs terminux's checks inside real Termux (termux/termux-docker).
#
#   tools/container-test.sh [check...]     default: all
#
# Checks: smoke packages netbird shell debian distros
# smoke and packages run on the aarch64 image (the phone's CPU, emulated).
# Anything that uses proot runs on the x86_64 image instead: QEMU's user-mode
# emulation has no ptrace, which proot needs. Phones have it.
#
# Needs Docker. For arm64 on an x86 machine, enable emulation once:
#   docker run --rm --privileged aptman/qus -s -- -p aarch64
# SPDX-License-Identifier: Apache-2.0
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
checks=("$@")
[ ${#checks[@]} -gt 0 ] || checks=(smoke packages netbird shell debian distros)

image_for() {
    case "$1" in
        smoke|packages) echo termux/termux-docker:aarch64 ;;
        *)              echo termux/termux-docker:x86_64 ;;
    esac
}

rc=0
for c in "${checks[@]}"; do
    img=$(image_for "$c")
    echo "### $c on $img"
    # MSYS_NO_PATHCONV stops Git Bash on Windows rewriting /repo paths.
    MSYS_NO_PATHCONV=1 docker run --rm --privileged \
        -v "$repo:/repo:ro" "$img" bash "/repo/tests/container/$c.sh" || rc=1
done
exit $rc
