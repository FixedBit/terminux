#!/bin/bash
# The CLI and installer front door work in real Termux.
. /repo/tests/container/lib.sh
TX=/repo/bin/terminux
check "terminux --version" bash $TX --version
check "terminux help" bash $TX help
check "terminux doctor runs" bash -c "bash $TX doctor; [ \$? -le 1 ]"
check "doctor knows it's in Termux" bash -c "bash $TX doctor 2>&1 | grep -q 'Running in Termux'"
check "install.sh --dry-run" bash /repo/install.sh --dry-run --de kde --add claude-code --envs dev
check "install.sh --help" bash /repo/install.sh --help
check "terminux add --list" bash $TX add --list ai
check "terminux env profiles" bash $TX env profiles
done_checks
