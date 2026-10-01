# shellcheck shell=bash
# terminux -- usage text.
# SPDX-License-Identifier: Apache-2.0

cmd_help() {
    cat <<EOF
terminux $TERMINUX_VERSION -- Linux desktop, VS Code and NetBird for Termux

Usage: terminux <command> [args]

Health
  info                device and GPU profile

Other
  banner [on|off]     show the banner, or turn it on/off at login
  login               what runs when Termux opens (banner, sshd)
  version             print the version

Docs: $TERMINUX_REPO_URL
EOF
}
