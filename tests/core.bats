#!/usr/bin/env bats
# lib/core.sh: settings files are parsed, never executed.

load helpers

setup() { tx_sandbox; tx_load; }

@test "kv_get reads plain, exported, quoted and commented values" {
    f="$BATS_TEST_TMPDIR/cfg"
    printf '%s\n' 'A=1' 'export B=two   # note' 'C="three"' "D='four'" > "$f"
    [ "$(tx_kv_get "$f" A)" = 1 ]
    [ "$(tx_kv_get "$f" B)" = two ]
    [ "$(tx_kv_get "$f" C)" = three ]
    [ "$(tx_kv_get "$f" D)" = four ]
}

@test "kv_get never executes the value" {
    f="$BATS_TEST_TMPDIR/cfg"
    echo 'X=$(touch '"$BATS_TEST_TMPDIR"'/pwned)' > "$f"
    tx_kv_get "$f" X
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "kv_set replaces, uncomments, or appends" {
    f="$BATS_TEST_TMPDIR/cfg"
    printf '%s\n' 'A=1' '# export LINUX_DPI=160   # hint' > "$f"
    tx_kv_set "$f" A 2
    tx_kv_set "$f" LINUX_DPI 180 "export "
    tx_kv_set "$f" NEW yes
    [ "$(tx_kv_get "$f" A)" = 2 ]
    grep -qx 'export LINUX_DPI=180' "$f"
    [ "$(tx_kv_get "$f" NEW)" = yes ]
    [ "$(grep -c LINUX_DPI "$f")" -eq 1 ]
}
