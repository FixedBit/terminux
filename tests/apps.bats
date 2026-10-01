#!/usr/bin/env bats
# lib/apps.sh: terminux app <name>.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    export ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"
        [ "$1" = install ] && mkdir -p "'"$PREFIX"'/var/lib/proot-distro/installed-rootfs/$2/etc"; exit 0'
    mkdir -p "$HOME/.config/terminux"
    printf 'user=jason\nshell=bash\n' > "$HOME/.config/terminux/config"
}

@test "app vscode installs code-oss from x11-repo" {
    run bash "$TX" app vscode
    [ "$status" -eq 0 ]
    grep -q "pkg install -y x11-repo" "$CALLS"
    grep -q "pkg install -y code-oss" "$CALLS"
}

@test "app vscode stores sign-ins without a keyring" {
    bash "$TX" app vscode
    grep -q '"password-store": "basic"' "$HOME/.vscode-oss/argv.json"
}

@test "app vscode keeps an existing argv.json and adds the setting once" {
    mkdir -p "$HOME/.vscode-oss"
    printf '{\n\t"enable-crash-reporter": false\n}\n' > "$HOME/.vscode-oss/argv.json"
    bash "$TX" app vscode
    bash "$TX" app vscode
    grep -q '"enable-crash-reporter": false' "$HOME/.vscode-oss/argv.json"
    [ "$(grep -c password-store "$HOME/.vscode-oss/argv.json")" -eq 1 ]
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$HOME/.vscode-oss/argv.json"
}

@test "app vscode adds a desktop shortcut that works on Android" {
    bash "$TX" app vscode
    grep -q "^Exec=code-oss --no-sandbox" "$HOME/Desktop/VSCode.desktop"
}

@test "app vscode-ms installs Microsoft's build inside Debian" {
    run bash "$TX" app vscode-ms
    [ "$status" -eq 0 ]
    grep -q "^proot-distro|install|debian" "$CALLS"
    grep -q "code.visualstudio.com.*linux-deb-arm64" "$CALLS"
    grep -q "password-store" "$ROOTFS/home/jason/.vscode/argv.json"
}

@test "app vscode-ms gives you a code-ms command and a shortcut" {
    bash "$TX" app vscode-ms
    [ -x "$PREFIX/bin/code-ms" ]
    grep -q "terminux debian -- code --no-sandbox" "$PREFIX/bin/code-ms"
    grep -q "^Exec=code-ms" "$HOME/Desktop/VSCode-Microsoft.desktop"
}

@test "app cursor removes the broken native copy and installs in Debian" {
    mkdir -p "$HOME/.local/share/cursor-agent" "$HOME/.local/bin"
    touch "$HOME/.local/bin/agent"
    bash "$TX" app cursor
    [ ! -e "$HOME/.local/share/cursor-agent" ]
    [ ! -e "$HOME/.local/bin/agent" ]
    grep -q "^proot-distro|login|debian|--user|jason|.*cursor.com/install" "$CALLS"
    grep -q "terminux debian -- " "$PREFIX/bin/cursor-agent"
}

@test "app debian uses the saved user and shell" {
    printf 'user=sam\nshell=bash\n' > "$HOME/.config/terminux/config"
    bash "$TX" app debian
    grep -q "useradd -m -s /bin/bash .*sam" "$CALLS"
}

@test "unknown app lists the ones there are" {
    run bash "$TX" app emacs
    [ "$status" -eq 2 ]
    [[ "$output" == *"vscode"* && "$output" == *"cursor"* ]]
}
