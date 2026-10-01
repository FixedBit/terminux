#!/usr/bin/env bats
# lib/catalog.sh: terminux add.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub pkg 'echo "pkg $*" >> "$CALLS"'
    stub npm 'echo "npm $*" >> "$CALLS"'
    stub code-oss 'echo "code-oss $*" >> "$CALLS"'
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"'
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    mkdir -p "$HOME/.config/terminux"; echo user=jason > "$HOME/.config/terminux/config"
}

@test "add an npm tool: makes sure Node.js is there, then installs globally" {
    run bash "$TX" add claude-code
    [ "$status" -eq 0 ]
    grep -q "pkg install -y nodejs" "$CALLS"
    grep -q "npm install -g @anthropic-ai/claude-code" "$CALLS"
}

@test "add a Termux package" {
    bash "$TX" add ollama
    grep -q "pkg install -y ollama" "$CALLS"
}

@test "add from an official installer script downloads it and runs it with bash" {
    stub curl 'echo "curl $*" >> "$CALLS"; echo "echo installer-ran >> \"$CALLS\""'
    bash "$TX" add graperoot
    grep -q "curl -fsSL https://raw.githubusercontent.com/kunal12203/Codex-CLI-Compact/main/install.sh" "$CALLS"
    grep -qx "installer-ran" "$CALLS"
}

@test "add VS Code extensions installs each one into code-oss" {
    bash "$TX" add vscode-ai
    grep -q "code-oss --install-extension Continue.continue" "$CALLS"
    grep -q "code-oss --install-extension saoudrizwan.claude-dev" "$CALLS"
}

@test "add a pipx tool installs it in the Debian environment as your user" {
    bash "$TX" add aider
    grep -q "^proot-distro|login|debian|--user|jason|.*pipx install aider-chat" "$CALLS"
}

@test "add several at once" {
    bash "$TX" add ollama llama-cpp
    grep -q "pkg install -y ollama" "$CALLS"
    grep -q "pkg install -y llama-cpp" "$CALLS"
}

@test "add an unknown id fails and suggests --list" {
    run bash "$TX" add doom-eternal
    [ "$status" -eq 2 ]
    [[ "$output" == *"--list"* ]]
}

@test "add --list shows a category with labels" {
    run bash "$TX" add --list ai
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-code"*"Claude Code"* ]]
    [[ "$output" == *"graperoot"* ]]
}

@test "add with no arguments lets you pick a category, then apps by number" {
    # category 1 (ai), then items 1 and 2
    TERMINUX_TTY=1 run bash "$TX" add <<<$'1\n1 2\n'
    [ "$status" -eq 0 ]
    grep -q "npm install -g @anthropic-ai/claude-code" "$CALLS"
    grep -q "npm install -g @openai/codex" "$CALLS"
}

@test "one failed install doesn't stop the rest, and is reported" {
    stub npm 'echo "npm $*" >> "$CALLS"; exit 1'
    run bash "$TX" add claude-code ollama
    [ "$status" -ne 0 ]
    grep -q "pkg install -y ollama" "$CALLS"
    [[ "$output" == *"claude-code"* ]]
}
