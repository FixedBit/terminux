#!/usr/bin/env bats
# install.sh end to end, with Android and the network stubbed out.

load helpers

INSTALL="$REPO_ROOT/install.sh"

setup() {
    tx_sandbox
    export TERMUX_VERSION=0.118
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    for c in pkg npm sshd termux-open termux-open-url termux-reload-settings chsh; do
        stub "$c" "echo \"$c \$*\" >> \"\$CALLS\""
    done
    stub pm 'printf "package:com.termux.x11\npackage:com.termux.api\n"'
    # Package upgrades succeed unless a test says otherwise.
    stub apt-get 'exit 0'
    stub dpkg 'exit 0'
    stub pgrep 'exit 1'
    stub git 'echo "git $*" >> "$CALLS"; [ "$1" = clone ] && mkdir -p "${@: -1}"; exit 0'
    stub curl 'echo "curl $*" >> "$CALLS"; while [ $# -gt 0 ]; do [ "$1" = -o ] && : > "$2"; shift; done'
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"
        pd="'"$PREFIX"'/var/lib/proot-distro"
        if [ "$1" = install ]; then shift; n=""; i=""
            while [ $# -gt 0 ]; do case "$1" in --name|-n) n="$2"; shift 2;; *) i="$1"; shift;; esac; done
            mkdir -p "$pd/containers/${n:-$i}/rootfs/etc"; fi; exit 0'
    # The desktop installer is swapped for one that records what it was given.
    export TERMINUX_DESKTOP_INSTALLER="$BATS_TEST_TMPDIR/desktop.sh" REPO_ROOT
    cat > "$TERMINUX_DESKTOP_INSTALLER" <<'SH'
env | grep -E '^TERMINUX_(DE|WINE|APPS|TWEAKS|THEME|DPI|UPGRADED)=' | sort > "$BATS_TEST_TMPDIR/desktop.env"
echo "desktop-installer" >> "$CALLS"
printf '#!/bin/bash\n' > "$HOME/start-linux.sh"
SH
}

run_install() { run bash "$INSTALL" "$@" </dev/null; }

@test "refuses to run outside Termux" {
    unset TERMUX_VERSION
    run env -u TERMUX_VERSION bash "$INSTALL" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"Termux"* ]]
}

@test "installs the Termux basics before the desktop" {
    run_install
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    first_pkg=$(grep -n "pkg install -y .*termux-x11-nightly" "$CALLS" | head -1 | cut -d: -f1)
    desktop=$(grep -n "desktop-installer" "$CALLS" | cut -d: -f1)
    [ -n "$first_pkg" ] && [ "$first_pkg" -lt "$desktop" ]
    grep -q "pkg install -y .*termux-api" "$CALLS"
}

@test "passes the desktop choices to the desktop installer" {
    run_install --de kde --wine --theme light --dpi 150 --apps vscode,build --tweaks wakelock,hidpi
    grep -qx "TERMINUX_DE=4" "$BATS_TEST_TMPDIR/desktop.env"
    grep -qx "TERMINUX_WINE=y" "$BATS_TEST_TMPDIR/desktop.env"
    grep -qx "TERMINUX_THEME=light" "$BATS_TEST_TMPDIR/desktop.env"
    grep -qx "TERMINUX_DPI=150" "$BATS_TEST_TMPDIR/desktop.env"
    grep -qx "TERMINUX_APPS=vscode,build" "$BATS_TEST_TMPDIR/desktop.env"
    grep -qx "TERMINUX_TWEAKS=wakelock,hidpi" "$BATS_TEST_TMPDIR/desktop.env"
}

@test "automatic DPI isn't passed as a number" {
    run_install
    run grep -c "TERMINUX_DPI=" "$BATS_TEST_TMPDIR/desktop.env"
    [ "$output" = 0 ]
}

@test "links the terminux command and saves the choices" {
    run_install --with debian --user sam --shell bash
    [ -L "$PREFIX/bin/terminux" ] || [ -f "$PREFIX/bin/terminux" ]
    grep -qx "user=sam" "$HOME/.config/terminux/config"
    grep -qx "shell=bash" "$HOME/.config/terminux/config"
}

@test "sets up the chosen shell and the banner" {
    run_install --shell zsh --zsh ohmyzsh
    [ -d "$HOME/.oh-my-zsh" ]
    grep -q ">>> terminux >>>" "$HOME/.zshrc"
    [ -e "$HOME/.hushlogin" ]
}

@test "--no-banner leaves Termux's welcome alone" {
    run_install --no-banner
    [ ! -e "$HOME/.hushlogin" ]
    grep -qx "banner=no" "$HOME/.config/terminux/config"
}

@test "extra packages are installed" {
    run_install --packages htop,neovim
    grep -q "pkg install -y htop neovim" "$CALLS"
}

@test "--with debian creates the Debian environment with the user" {
    run_install --with debian --user sam --shell bash
    grep -q "^proot-distro|install|debian" "$CALLS"
    grep -q "useradd -m -s /bin/bash .*sam" "$CALLS"
}

@test "--add installs catalog apps" {
    run_install --add ollama,claude-code
    grep -q "pkg install -y ollama" "$CALLS"
    grep -q "npm install -g @anthropic-ai/claude-code" "$CALLS"
}

@test "--envs creates environments named after their profiles" {
    run_install --envs minimal
    grep -q "^proot-distro|install|--name|minimal|alpine" "$CALLS"
}

@test "--ssh turns the SSH server on" {
    run_install --ssh
    grep -qx "ssh=yes" "$HOME/.config/terminux/config"
}

@test "a failed extra doesn't stop the rest, and the summary says what failed" {
    stub npm 'exit 1'
    run_install --add claude-code,ollama
    [ "$status" -ne 0 ]
    grep -q "pkg install -y ollama" "$CALLS"
    [[ "$output" == *"claude-code"* ]]
    [ -L "$PREFIX/bin/terminux" ] || [ -f "$PREFIX/bin/terminux" ]
}

@test "the NetBird key from a private file never appears in the output" {
    printf 'NB_SETUP_KEY=super-secret-key\n' > "$BATS_TEST_TMPDIR/p.env"
    run_install --private "$BATS_TEST_TMPDIR/p.env" --with netbird
    [[ "$output" != *"super-secret-key"* ]]
}

@test "ends by telling you how to start" {
    run_install
    [[ "$output" == *"terminux start"* ]]
}

@test "Termux is upgraded by terminux's own upgrade step, and only once" {
    stub apt-get 'echo "apt-get $*" >> "$CALLS"'
    stub dpkg 'echo "dpkg $*" >> "$CALLS"'
    run_install
    grep -q "apt-get .*full-upgrade" "$CALLS"
    grep -qx "TERMINUX_UPGRADED=1" "$BATS_TEST_TMPDIR/desktop.env"
}

@test "a failed upgrade stops before the desktop, with the cause and a fix" {
    stub dpkg 'exit 0'
    stub apt-get '[[ "$*" == *full-upgrade* ]] && { cat "'"$REPO_ROOT"'/tests/fixtures/apt/corelib.log"; exit 100; }; exit 0'
    run_install
    [ "$status" -ne 0 ]
    run grep -c desktop-installer "$CALLS"
    [ "$output" = 0 ]
}

@test "when the desktop installer fails, its log is read and the cause shown" {
    stub apt-get 'exit 0'; stub dpkg 'exit 0'
    cat > "$TERMINUX_DESKTOP_INSTALLER" <<'SH'
cat "$REPO_ROOT/tests/fixtures/apt/overwrite.log" >> "$HOME/termux-setup.log"
exit 1
SH
    run_install
    [ "$status" -ne 0 ]
    [[ "$output" == *"mesa-zink"* ]]
    [[ "$output" == *"Fix:"* ]]
    [[ "$output" == *"terminux report"* ]]
}

@test "even when the upgrade fails, the terminux command is there to fix and report" {
    stub apt-get '[[ "$*" == *full-upgrade* ]] && { cat "'"$REPO_ROOT"'/tests/fixtures/apt/corelib.log"; exit 100; }; exit 0'
    run_install
    [ "$status" -ne 0 ]
    [ -L "$PREFIX/bin/terminux" ] || [ -f "$PREFIX/bin/terminux" ]
}

@test "--base debian builds the desktop inside Debian, not with the Termux installer" {
    run_install --base debian --de xfce --user sam
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    run grep -c desktop-installer "$CALLS"
    [ "$output" = 0 ]
    grep -q "^proot-distro|install|debian" "$CALLS"
    grep -q "startxfce4" "$HOME/start-linux.sh"
}

@test "Termux with no desktop skips the desktop installer and installs the apps" {
    run_install --de none --apps python,nodejs
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    run grep -c desktop-installer "$CALLS"
    [ "$output" = 0 ]
    grep -q "pkg install -y .*python" "$CALLS"
    grep -q "pkg install -y .*nodejs" "$CALLS"
}

@test "on a distro, extra packages are installed inside it with apt" {
    run_install --base ubuntu --de none --user sam --packages htop,neovim
    grep -q "^proot-distro|login|ubuntu|.*apt-get install -y htop neovim" "$CALLS"
}
