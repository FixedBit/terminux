# Environments

Besides the native Termux desktop, terminux can keep any number of Linux
environments side by side, each its own proot container with its own
packages. Make one for development, another for a second desktop, another
to try things in, and throw them away when you're done.

```sh
terminux env                          # pick one, then enter / run / rename / back up / reset / remove
terminux env list                     # what you have, with profile and size
terminux env profiles                 # what you can make
terminux env create work --from dev   # make one
terminux env enter work               # a shell in it, as your user
terminux env run work -- make test    # one command
terminux env backup work              # to ~/work-<date>.tar.gz
terminux env remove work              # asks first; --yes to skip the question
```

Every environment gets your user account (`--user` from the install) with
passwordless `sudo`, shares Termux's `/tmp` so graphical apps open on the
Termux:X11 display, and sends sound to Termux's PulseAudio.

## Profiles

| Profile | Starts from | What's in it |
|---------|-------------|--------------|
| `dev` | Debian | build tools, git, Python, Node.js, Go, CMake |
| `desktop` | Debian | XFCE and Firefox; run `startxfce4` inside it with Termux:X11 open |
| `minimal` | Alpine | a shell, curl and git; about 20 MB, quick to make |
| `gaming` | Debian | RetroArch, DOSBox, ScummVM |
| `security` | Kali Linux (official image) | Kali's standard command-line toolset |

Profiles are small files in [`envs/`](../envs); copy one to make your own.
Each sets `IMAGE` (any image proot-distro can install, e.g. `ubuntu:24.04`),
`FAMILY` (`apt` or `apk`) and `PACKAGES`.

The `security` profile is for learning and for testing systems you own or
have written permission to test. Scanning or attacking networks and devices
without permission is illegal in most places. Many tools also need raw
network access that Android doesn't give unrooted apps, so some features
won't work inside proot.

## The Debian environment

`terminux debian` and `terminux app debian` manage one environment called
`debian`, which is what Microsoft VS Code, Cursor and Aider use. It shows up
in `terminux env list` like any other.

## Under the hood

Environments are [proot-distro](https://github.com/termux/proot-distro)
containers. terminux works with both proot-distro's current layout
(`$PREFIX/var/lib/proot-distro/containers/<name>/rootfs`) and the older one
(`installed-rootfs/<name>`), and keeps each environment's profile in
`~/.config/terminux/envs/<name>`.
