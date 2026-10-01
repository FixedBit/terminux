# 0004 — NetBird runs rootless in netstack mode

**Status:** Accepted, 2026-10-01

## Context

The phone should join the owner's NetBird mesh so other peers can reach it
(SSH on port 8022) and it can reach them. Options:

1. **The NetBird Android app.** A real system VPN, but enrollment happens in
   its UI, so it can't be scripted, and it occupies Android's single VPN slot.
2. **The NetBird Linux client with a TUN device.** Needs root.
3. **The NetBird Linux client in netstack mode** (`NB_USE_NETSTACK_MODE=true`):
   WireGuard over gVisor's userspace TCP/IP stack, no TUN, no root. Outbound
   traffic goes through a local SOCKS5 proxy; inbound connections to the
   peer's NetBird IP are forwarded to local services with
   `NB_ENABLE_NETSTACK_LOCAL_FORWARDING=true`.

The official `netbird_<ver>_linux_arm64` release binary is statically linked
Go, so it runs natively on Android.

## Decision

Option 3. terminux downloads the release binary and runs it under `proot`
only to map the paths it hard-codes onto writable Termux directories
(`/var/lib/netbird`, `/etc/netbird`, `/var/run`, `/var/log/netbird`) and to
provide `/etc/resolv.conf`, which Android lacks (Go's resolver would
otherwise query `127.0.0.1:53`).

## Consequences

- Scriptable end to end, coexists with any VPN app, survives without root.
- Only Termux processes that use the SOCKS5 proxy (`127.0.0.1:1080`) reach
  the mesh; other Android apps don't. The Android app remains the answer for
  a system-wide tunnel and is documented as the alternative.
- Untested assumptions to verify on a device: netlink interface listing under
  Termux's SDK level, and the daemon's behaviour under `proot -0`.
