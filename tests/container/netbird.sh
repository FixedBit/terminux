#!/bin/bash
# The real NetBird client under proot (needs ptrace: run on a native-arch image).
. /repo/tests/container/lib.sh
prepare proot curl ca-certificates
TX_LIB=/repo/lib; . /repo/lib/core.sh; . /repo/lib/netbird.sh
check "NetBird downloads for $(uname -m)" tx_nb_install
check "netbird version runs under proot" _tx_nb version
check "the daemon starts" tx_nb_start
sleep 2
check "status talks to the daemon" bash -c "TX_LIB=/repo/lib; . /repo/lib/core.sh; . /repo/lib/netbird.sh; _tx_nb status | grep -q 'Daemon status'"
# A key the management server rejects: join must fail cleanly, and the key
# must be gone from disk and never written to a log.
NB_SETUP_KEY=terminux-container-test-not-a-real-key tx_nb_join >$TMPDIR/join.out 2>&1
check "a rejected key makes join fail" test $? -ne 0
check "the key file is deleted" bash -c "! ls -a $TX_NB_HOME/lib | grep -q setup-key"
check "the key is in no log" bash -c "! grep -rq terminux-container-test-not-a-real-key $TX_NB_HOME $TMPDIR/join.out"
done_checks
