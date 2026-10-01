# shellcheck shell=bash
# terminux -- terminux app <name>: VS Code, Microsoft VS Code, Cursor, Debian.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/debian.sh
. "$TX_LIB/debian.sh"

TX_APPS="vscode vscode-ms cursor debian"
TX_VSCODE_MS_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"

# VS Code keeps sign-ins (GitHub, Settings Sync) in the desktop keyring, and
# Termux has none; "basic" stores them encrypted in VS Code's own files.
tx_vscode_argv() {
    local f="$1"
    mkdir -p "$(dirname "$f")"
    if [ ! -s "$f" ] || grep -qE '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$f"; then
        printf '{\n\t"password-store": "basic"\n}\n' > "$f"
    elif ! grep -q '"password-store"' "$f"; then
        # argv.json may have comments, so edit it as text: add the key as the
        # first entry after the opening brace.
        sed -i '0,/^[[:space:]]*{[[:space:]]*$/s//{\n\t"password-store": "basic",/' "$f"
    fi
}

_tx_desktop_entry() {
    local file="$1" name="$2" exec="$3" icon="$4"
    mkdir -p "$HOME/Desktop"
    cat > "$HOME/Desktop/$file" <<EOF
[Desktop Entry]
Name=$name
Exec=$exec
Icon=$icon
Type=Application
Categories=Development;IDE;TextEditor;
EOF
    chmod +x "$HOME/Desktop/$file"
}

# Make sure Debian exists, using the account settings chosen at install.
_tx_need_debian() {
    tx_debian_installed && return 0
    tx_debian_install "$(tx_debian_user)" "$(tx_config_get shell 2>/dev/null || echo bash)" \
        "$(tx_config_get zsh 2>/dev/null || true)"
}

_tx_app_vscode() {
    pkg install -y x11-repo >/dev/null
    pkg install -y code-oss || return 1
    tx_vscode_argv "$HOME/.vscode-oss/argv.json"
    # Android doesn't allow Electron's setuid sandbox.
    _tx_desktop_entry VSCode.desktop "VS Code" "code-oss --no-sandbox %F" code-oss
    tx_ok "VS Code installed. Open it from the desktop, or run: code-oss --no-sandbox"
}

_tx_app_vscode_ms() {
    _tx_need_debian || return 1
    local user; user=$(tx_debian_user)
    tx_step "Installing Microsoft VS Code in Debian"
    _tx_debian_root "
        set -e
        cd /tmp
        curl -fsSL -o code.deb '$TX_VSCODE_MS_URL'
        DEBIAN_FRONTEND=noninteractive apt-get install -y ./code.deb
        rm -f code.deb
    " || { tx_fail "Installing VS Code in Debian failed"; return 1; }
    tx_vscode_argv "$TX_DEBIAN_ROOTFS/home/$user/.vscode/argv.json"

    cat > "$PREFIX/bin/code-ms" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Microsoft VS Code, running in terminux's Debian environment.
exec terminux debian -- code --no-sandbox "$@"
EOF
    chmod +x "$PREFIX/bin/code-ms"
    _tx_desktop_entry VSCode-Microsoft.desktop "VS Code (Microsoft)" "code-ms %F" code-oss
    tx_ok "Microsoft VS Code installed. Run code-ms, or use the desktop shortcut."
}

_tx_app_cursor() {
    # Cursor ships a glibc node and glibc native modules; a copy installed
    # straight into Termux can never run, so clear it out.
    rm -rf "$HOME/.local/share/cursor-agent" "$HOME/.local/bin/agent"
    _tx_need_debian || return 1
    local user; user=$(tx_debian_user)
    tx_step "Installing the Cursor CLI in Debian"
    proot-distro login debian --user "$user" --shared-tmp -- bash -c "
        set -e
        curl -fsS https://cursor.com/install | bash
    " || { tx_fail "Installing Cursor failed"; return 1; }

    cat > "$PREFIX/bin/cursor-agent" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# Cursor's agent CLI, running in terminux's Debian environment.
exec terminux debian -- /home/$user/.local/bin/agent "\$@"
EOF
    chmod +x "$PREFIX/bin/cursor-agent"
    tx_ok "Cursor installed. Run: cursor-agent"
}

_tx_app_debian() {
    tx_debian_install "$(tx_debian_user)" "$(tx_config_get shell 2>/dev/null || echo bash)" \
        "$(tx_config_get zsh 2>/dev/null || true)"
}

cmd_app() {
    case "${1:-}" in
        vscode)    _tx_app_vscode ;;
        vscode-ms) _tx_app_vscode_ms ;;
        cursor)    _tx_app_cursor ;;
        debian)    _tx_app_debian ;;
        *)
            tx_fail "usage: terminux app <name>   (one of: $TX_APPS)"
            return 2 ;;
    esac
}
