# shellcheck shell=bash
# terminux -- terminux ssh on|off: Termux's SSH server, started at login.
# SPDX-License-Identifier: Apache-2.0

cmd_ssh() {
    case "${1:-}" in
        on)
            pkg install -y openssh >/dev/null || return 1
            tx_config_set ssh yes
            pgrep -x sshd >/dev/null 2>&1 || sshd
            tx_ok "SSH is on (port 8022) and starts whenever Termux opens."
            tx_hint "Log in from another machine: ssh -p 8022 $(whoami 2>/dev/null || echo you)@<this phone's IP>"
            tx_hint "Set a password first with: passwd   (or add your key to ~/.ssh/authorized_keys)" ;;
        off)
            tx_config_set ssh no
            pkill -x sshd 2>/dev/null
            tx_ok "SSH is off." ;;
        *)
            if pgrep -x sshd >/dev/null 2>&1; then echo "SSH is running on port 8022."
            else echo "SSH is off. Turn it on with: terminux ssh on"; fi ;;
    esac
}
