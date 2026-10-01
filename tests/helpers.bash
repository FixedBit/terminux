# Shared setup: every test gets a throwaway $HOME and PREFIX, so nothing
# touches the machine running the suite.
REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
TX="$REPO_ROOT/bin/terminux"

tx_sandbox() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export PREFIX="$BATS_TEST_TMPDIR/usr"
    export TERMINUX_HOME="$REPO_ROOT"
    export NO_COLOR=1
    mkdir -p "$HOME" "$PREFIX/bin" "$PREFIX/tmp" "$PREFIX/etc"
    unset TERMINUX_CONFIG_DIR TERMINUX_STATE_DIR TERMINUX_GPU_CFG
}

# Load the libraries into the test shell the same way bin/terminux does.
tx_load() {
    TX_LIB="$REPO_ROOT/lib"
    # shellcheck source=/dev/null
    . "$TX_LIB/core.sh"
    local m
    for m in "$@"; do
        # shellcheck source=/dev/null
        . "$TX_LIB/$m.sh"
    done
}

# Put a fake command on PATH: stub <name> <script body>
stub() {
    mkdir -p "$BATS_TEST_TMPDIR/stubs"
    printf '#!/usr/bin/env bash\n%s\n' "$2" > "$BATS_TEST_TMPDIR/stubs/$1"
    chmod +x "$BATS_TEST_TMPDIR/stubs/$1"
    case ":$PATH:" in *":$BATS_TEST_TMPDIR/stubs:"*) ;; *) PATH="$BATS_TEST_TMPDIR/stubs:$PATH" ;; esac
}
