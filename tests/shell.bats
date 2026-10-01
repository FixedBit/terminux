#!/usr/bin/env bats
# lib/shell.sh: zsh/bash setup and the login hook block.

load helpers

setup() {
    tx_sandbox
    tx_load shell
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    stub chsh 'echo "chsh $*" >> "$CALLS"'
    stub termux-reload-settings 'echo "termux-reload-settings" >> "$CALLS"'
    # git clone <url> <dir>: record it and make the directory.
    stub git 'echo "git $*" >> "$CALLS"; [ "$1" = clone ] && mkdir -p "${@: -1}"; exit 0'
    stub curl 'echo "curl $*" >> "$CALLS"; while [ $# -gt 0 ]; do [ "$1" = -o ] && { echo font > "$2"; }; shift; done'
}

@test "rc block is added once and replaced, never duplicated" {
    echo "alias ll='ls -l'" > "$HOME/.bashrc"
    tx_rc_block "$HOME/.bashrc"
    tx_rc_block "$HOME/.bashrc"
    [ "$(grep -c '>>> terminux >>>' "$HOME/.bashrc")" -eq 1 ]
    grep -q "alias ll" "$HOME/.bashrc"
    grep -q "terminux login" "$HOME/.bashrc"
}

@test "rc block loads ~/.aliases" {
    tx_rc_block "$HOME/.bashrc"
    echo "alias hi='echo hello'" > "$HOME/.aliases"
    run bash -c "shopt -s expand_aliases; terminux() { :; }; . '$HOME/.bashrc'; alias hi"
    [ "$status" -eq 0 ]
}

@test "bash setup only touches .bashrc" {
    tx_shell_setup bash ""
    grep -q ">>> terminux >>>" "$HOME/.bashrc"
    [ ! -e "$HOME/.zshrc" ]
    run grep -c chsh "$CALLS"
    [ "$output" = 0 ]
}

@test "zsh with every extra: oh-my-zsh, p10k theme, both plugins, default shell" {
    tx_shell_setup zsh ohmyzsh,powerlevel10k,autosuggestions,syntax-highlighting
    grep -q "pkg install -y zsh" "$CALLS"
    [ -d "$HOME/.oh-my-zsh" ]
    [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]
    grep -qx 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"
    grep -qE '^plugins=\(git zsh-autosuggestions zsh-syntax-highlighting\)' "$HOME/.zshrc"
    grep -q ">>> terminux >>>" "$HOME/.zshrc"
    grep -q "chsh -s zsh" "$CALLS"
}

@test "zsh without oh-my-zsh sources the extras directly" {
    tx_shell_setup zsh powerlevel10k,autosuggestions
    [ ! -d "$HOME/.oh-my-zsh" ]
    grep -q "powerlevel10k.zsh-theme" "$HOME/.zshrc"
    grep -q "zsh-autosuggestions.zsh" "$HOME/.zshrc"
    run grep -c "oh-my-zsh.sh" "$HOME/.zshrc"
    [ "$output" = 0 ]
}

@test "the generated .zshrc is valid zsh" {
    command -v zsh >/dev/null || skip "zsh not installed on this host"
    tx_shell_setup zsh ohmyzsh,powerlevel10k,autosuggestions,syntax-highlighting
    zsh -n "$HOME/.zshrc"
}

@test "an existing .zshrc that isn't ours is backed up" {
    echo "my precious config" > "$HOME/.zshrc"
    tx_shell_setup zsh ohmyzsh
    grep -q "my precious config" "$HOME/.zshrc.pre-terminux"
}

@test "re-running zsh setup doesn't re-clone or re-backup" {
    tx_shell_setup zsh ohmyzsh
    : > "$CALLS"
    tx_shell_setup zsh ohmyzsh
    run grep -c "git clone" "$CALLS"
    [ "$output" = 0 ]
    [ ! -e "$HOME/.zshrc.pre-terminux" ]
}

@test "powerlevel10k installs a Nerd Font for Termux unless you have one" {
    tx_shell_setup zsh ohmyzsh,powerlevel10k
    [ -s "$HOME/.termux/font.ttf" ]
    grep -q termux-reload-settings "$CALLS"
    echo mine > "$HOME/.termux/font.ttf"
    tx_shell_setup zsh ohmyzsh,powerlevel10k
    [ "$(cat "$HOME/.termux/font.ttf")" = mine ]
}
