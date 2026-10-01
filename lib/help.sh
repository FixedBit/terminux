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

Display
  display <mode>      Termux:X11 output: native | scaled | fold
  dpi [value]         show or set the desktop DPI
  touch [mode]        trackpad | touch (no argument: toggle)

Environments
  debian              a shell in Debian as your user
  debian -- <cmd>     run one command in Debian
  env                 pick an environment and what to do with it
  env list            your environments;  env profiles: what you can make
  env create <name> --from <profile>
  env enter|run|rename|backup|reset|remove <name>

Apps
  add                 pick apps to install from the catalog (AI tools, ...)
  add <id> [id...]    install apps by id;  add --list [category] to browse
  app vscode         VS Code (Code - OSS, native, Open VSX extensions)
  app vscode-ms       Microsoft VS Code, in Debian (run: code-ms)
  app cursor          Cursor CLI, in Debian (run: cursor-agent)
  app debian          install or update the Debian environment

Network
  netbird join        join a NetBird mesh (asks for the setup key)
  netbird [cmd]       status | start | stop | down | logs | boot
  ssh on|off          SSH server on port 8022, started when Termux opens

Health
  doctor              check for known problems and say how to fix each
  fix [what]          repair them: launchers (default), phantom, all
  info                device and GPU profile

Maintenance
  update [--check]    pull the latest terminux (or just see what's new)
  uninstall [--all]   remove terminux (--all: environments too)

Other
  menu               the menu (same as plain terminux)
  banner [on|off]     show the banner, or turn it on/off at login
  login               what runs when Termux opens (banner, sshd)
  version             print the version

Docs: $TERMINUX_REPO_URL
EOF
}
