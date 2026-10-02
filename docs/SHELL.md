# Account and shell

## Your Linux username

`--user` names your account in the [Debian environment](APPS.md#the-debian-environment),
created with `sudo` rights and no password prompt. It must be lowercase
letters, digits, `-` or `_`, starting with a letter, and can't be a system
account such as `root`.

Native Termux has no user accounts — everything there runs as the Termux
app — so the username only matters inside Debian.

## zsh

`--shell zsh` (the default) makes zsh your shell in Termux and in Debian,
with any of these extras (`--zsh`):

| Extra | id | |
|-------|----|-|
| [Oh My Zsh](https://ohmyz.sh) | `ohmyzsh` | Framework for themes and plugins |
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | `powerlevel10k` | Fast prompt with git status; run `p10k configure` to style it |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | `autosuggestions` | Grey suggestions from your history; → accepts |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | `syntax-highlighting` | Commands turn red when they don't exist |

Powerlevel10k looks best with a Nerd Font. In Termux: long-press the
terminal → **More… → Style** (needs the Termux:Styling app), or drop a font
at `~/.termux/font.ttf` and run `termux-reload-settings`. terminux installs
MesloLGS NF there when Powerlevel10k is chosen.

Your own aliases go in `~/.aliases`; both bash and zsh load it if it exists.

`--shell bash` keeps Termux's default shell; the extras are skipped.

## The banner

Every time Termux opens, terminux prints a short banner: whether the desktop
and NetBird are running, and the commands you're most likely to want.
`--no-banner` turns it off; so does `terminux banner off` later. Termux's own
welcome text is hidden while the banner is on.
