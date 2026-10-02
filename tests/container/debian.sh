#!/bin/bash
# A real Debian environment with a user (needs ptrace: native-arch image).
. /repo/tests/container/lib.sh
prepare proot-distro
# shellcheck disable=SC2034 # read by the sourced modules
TX_LIB=/repo/lib; . /repo/lib/core.sh; . /repo/lib/debian.sh
check "Debian installs with user sam" tx_debian_install sam bash ""
check "terminux debian runs a command as sam" bash -c "bash /repo/bin/terminux debian -- id -un | grep -qx sam"
check "sam has passwordless sudo" bash -c "bash /repo/bin/terminux debian -- sudo -n true"
check "DISPLAY points at Termux:X11" bash -c "bash /repo/bin/terminux debian -- bash -lc 'echo \$DISPLAY' | grep -qx :0"
check "env create (minimal, Alpine)" bash /repo/bin/terminux env create tiny --from minimal
check "env run in it" bash -c "bash /repo/bin/terminux env run tiny -- cat /etc/alpine-release"
check "env list shows both" bash -c "bash /repo/bin/terminux env list | grep -q tiny"
check "env remove --yes" bash /repo/bin/terminux env remove tiny --yes
done_checks
