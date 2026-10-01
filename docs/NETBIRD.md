# NetBird mesh

terminux can put the phone on a [NetBird](https://netbird.io) network — a
private WireGuard mesh — without root, so your other machines can SSH into
the phone and the phone can reach them.

## Joining

Choose **NetBird mesh** in the wizard (`--with netbird`), or later:

```sh
terminux netbird join
```

You'll need a **setup key** from your NetBird dashboard (Setup Keys → Create).
Make it **one-off** (usage limit 1) with a short expiry: once the phone has
enrolled, the key is never needed again.

For a self-hosted NetBird, also give your management URL. Without one,
terminux uses NetBird's cloud.

## Giving it your key privately

The key never goes in this repo or the wizard. Pick one:

| How | Example |
|-----|---------|
| Type it when asked (hidden) | `terminux netbird join` |
| A private file on the phone | `~/.config/terminux/private.env`, mode 600 |
| A private link | `bash install.sh --with netbird --private https://gist.githubusercontent.com/you/<secret-id>/raw/terminux.env` |
| Environment variables | `NB_SETUP_KEY=… NB_MANAGEMENT_URL=… terminux netbird join` |

A private file or link holds `KEY=VALUE` lines:

```sh
NB_MANAGEMENT_URL=https://netbird.example.com
NB_SETUP_KEY=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
NB_HOSTNAME=fold
```

Only `NB_*` and `TERMINUX_*` keys are read. The file is parsed, never
executed, so even a tampered link can't run code on your phone, and plain
`http://` links are refused. Environment variables can end up in your shell
history, so prefer the prompt or a private file for the key.

The key is handed to NetBird through a temporary file that only you can
read; it never appears in the process list, and it's deleted as soon as the
phone has enrolled.

## Day to day

```sh
terminux netbird status   # peers, IPs, connection state
terminux netbird start    # after a reboot (terminux start does this too)
terminux netbird stop
terminux netbird logs
terminux netbird boot     # start NetBird at boot (needs the Termux:Boot app)
```

## How it works, and its limits

Android only lets one app hold the VPN, and creating a network interface
needs root. So terminux runs NetBird's official Linux client in **netstack
mode**: WireGuard runs over a userspace network stack inside the NetBird
process ([ADR 0004](adr/0004-netbird-netstack.md)).

- **Other peers → phone** works for any service listening on the phone, such
  as Termux's SSH server: `ssh -p 8022 <user>@<phone's NetBird IP>`.
- **Phone → other peers** goes through a SOCKS5 proxy on `127.0.0.1:1080`:

  ```sh
  curl --socks5-hostname 127.0.0.1:1080 http://100.x.y.z:8080
  ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' user@100.x.y.z
  ```

- Other Android apps don't see the mesh. For a system-wide tunnel, use the
  NetBird Android app instead.
