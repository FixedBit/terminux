#!/usr/bin/env bats
# lib/private.sh: private values are parsed against an allow-list, never run.
# See docs/adr/0003-secrets-at-runtime.md.

load helpers

setup() {
    tx_sandbox
    tx_load private
    unset NB_SETUP_KEY NB_MANAGEMENT_URL NB_HOSTNAME TERMINUX_DE
    F="$BATS_TEST_TMPDIR/private.env"
}

@test "loads NB_ and TERMINUX_ values from a file" {
    printf 'NB_SETUP_KEY=abc-123\nNB_MANAGEMENT_URL=https://nb.example.com\nTERMINUX_DE=kde\n' > "$F"
    tx_private_load "$F"
    [ "$NB_SETUP_KEY" = abc-123 ]
    [ "$NB_MANAGEMENT_URL" = https://nb.example.com ]
    [ "$TERMINUX_DE" = kde ]
}

@test "ignores everything outside the allow-list" {
    printf 'PATH=/evil\nLD_PRELOAD=/evil.so\nNB_SETUP_KEY=ok\n' > "$F"
    old_path="$PATH"
    tx_private_load "$F"
    [ "$PATH" = "$old_path" ]
    [ -z "${LD_PRELOAD:-}" ]
    [ "$NB_SETUP_KEY" = ok ]
}

@test "values are data: command substitutions are never run" {
    printf 'NB_SETUP_KEY=$(touch %s/pwned)\nNB_HOSTNAME=`touch %s/pwned2`\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$F"
    tx_private_load "$F"
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
    [ ! -e "$BATS_TEST_TMPDIR/pwned2" ]
    [ "$NB_SETUP_KEY" = "\$(touch $BATS_TEST_TMPDIR/pwned)" ]
}

@test "handles quotes, export, comments, blank lines and Windows line endings" {
    printf '# my keys\r\n\r\nexport NB_SETUP_KEY="quoted"\r\nNB_HOSTNAME='"'"'fold'"'"'\r\n' > "$F"
    tx_private_load "$F"
    [ "$NB_SETUP_KEY" = quoted ]
    [ "$NB_HOSTNAME" = fold ]
}

@test "values already in the environment win" {
    printf 'NB_SETUP_KEY=from-file\n' > "$F"
    NB_SETUP_KEY=from-env
    tx_private_load "$F"
    [ "$NB_SETUP_KEY" = from-env ]
}

@test "loads from an https link" {
    stub curl 'printf "NB_SETUP_KEY=from-link\n"'
    tx_private_load https://gist.githubusercontent.com/me/secret/raw/x.env
    [ "$NB_SETUP_KEY" = from-link ]
}

@test "refuses plain http links" {
    stub curl 'printf "NB_SETUP_KEY=leaked\n"'
    run tx_private_load http://example.com/x.env
    [ "$status" -ne 0 ]
    [[ "$output" == *"https"* ]]
}

@test "a missing file is an error" {
    run tx_private_load "$BATS_TEST_TMPDIR/nope.env"
    [ "$status" -ne 0 ]
}

@test "the default private.env is locked down to the owner" {
    mkdir -p "$HOME/.config/terminux"
    printf 'NB_SETUP_KEY=x\n' > "$HOME/.config/terminux/private.env"
    chmod 644 "$HOME/.config/terminux/private.env"
    tx_private_load_default
    [ "$NB_SETUP_KEY" = x ]
    [ "$(stat -c %a "$HOME/.config/terminux/private.env")" = 600 ]
}
