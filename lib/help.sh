# shellcheck shell=bash
# terminux -- usage text.
# SPDX-License-Identifier: Apache-2.0

cmd_help() {
    cat <<EOF
terminux $TERMINUX_VERSION -- Linux desktop, VS Code and NetBird for Termux

Usage: terminux [command] [args]     (no command: open the menu)

Desktop
  start               start the desktop in the background, open Termux:X11
  stop                stop the desktop
  restart             stop, then start
  status              what's running

Debian
  debian              a shell in Debian as your user
  debian -- <cmd>     run one command in Debian

Apps
  app vscode          VS Code (Code - OSS, native, Open VSX extensions)
  app vscode-ms       Microsoft VS Code, in Debian (run: code-ms)
  app cursor          Cursor CLI, in Debian (run: cursor-agent)
  app debian          install or update the Debian environment

Health
  info                device and GPU profile

Other
  menu                the menu (same as plain terminux)
  banner [on|off]     show the banner, or turn it on/off at login
  login               what runs when Termux opens (banner, sshd)
  version             print the version

Docs: $TERMINUX_REPO_URL
EOF
}
