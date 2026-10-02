#!/bin/bash
# zsh, Oh My Zsh, Powerlevel10k and plugins really install and load.
. /repo/tests/container/lib.sh
prepare git
# shellcheck disable=SC2034 # read by the sourced modules
TX_LIB=/repo/lib; . /repo/lib/core.sh; . /repo/lib/shell.sh
ln -sf /repo/bin/terminux "$PREFIX/bin/terminux"
check "zsh setup" tx_shell_setup zsh ohmyzsh,powerlevel10k,autosuggestions,syntax-highlighting
check ".zshrc is valid zsh" zsh -n "$HOME/.zshrc"
check "zsh starts with the config" zsh -ic 'exit 0'
check "plugins are loaded" zsh -ic 'typeset -f _zsh_autosuggest_start >/dev/null'
check "the banner shows at login" bash -c "TERMINUX_TTY=1 zsh -ic 'true' 2>/dev/null | grep -q 'terminux start' || TERMINUX_TTY=1 terminux login | grep -q 'terminux start'"
check "bash setup leaves a working .bashrc" bash -c "bash -n $HOME/.bashrc"
done_checks
