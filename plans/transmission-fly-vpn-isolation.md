# Transmission + fly-vpn isolation plan

**Status:** draft / idea  
**Host:** Goofeus  
**Goal:** Route only Transmission torrent traffic through an ephemeral fly-vpn exit node, without breaking homelab services (donetick, trek, Caddy, Tailscale Serve, *Arr stack).

---

## Problem

Running fly-vpn on Goofeus enables a **host-wide** Tailscale exit node:

```bash
tailscale set --exit-node=fly-vpn-exit
```

That routes all non-tailnet traffic through the Fly.io exit node. Side effects on Goofeus:

| Issue | Effect |
|-------|--------|
| No `--exit-node-allow-lan-access` on Goofeus | Host cannot reliably use its own LAN (`192.168.50.0/24`) while exit node is active |
| `--accept-dns=true` + exit node | DNS hijacked to exit node; MagicDNS names like `trek.dab-octatonic.ts.net` may fail |
| Public URL hairpin | `donetick.px.goofy.me.in` from Goofeus routes out via Fly and back — often fails |
| Server as exit client | Caddy, Tailscale Serve, Podman sidecars (trek-ts) share the host network stack |

**Enabling LAN access on Goofeus alone is a partial fix** (helps container/LAN routing) but does **not** fix DNS hijacking or public-hostname hairpin. It is not sufficient for the homelab + torrenting use case.

### Current service layout (relevant)

| Service | Exposure | Notes |
|---------|----------|-------|
| **donetick** | `127.0.0.1:2021` → Caddy + `svc:donetick` | Host Tailscale Serve |
| **trek** | `trek.dab-octatonic.ts.net` | Independent `trek-ts` sidecar (Serve + Funnel) |
| **transmission** | `127.0.0.1:9091` RPC → Caddy + `svc:transmission` | Native systemd service; downloads on HDD |

---

## Goal

Use fly-vpn for **Transmission torrenting only** (P2P peer traffic through exit node), while the **host Tailscale stays normal** (no exit node).

---

## Constraints

1. **fly-vpn does not support per-app split tunneling** — Launch always calls `connect_exit_node()` on the machine where it runs.
2. **Tailscale on Linux has no per-app exit node** (unlike Android app split tunneling).
3. **Transmission proxy settings are insufficient** — `proxy-server` / SOCKS only cover HTTP trackers and webseeds, **not** peer-to-peer connections.
4. **Sonarr/Radarr must keep reaching Transmission RPC** on loopback (or a stable host-published port).

---

## Recommended approach: Transmission sidecar (trek-ts pattern)

Isolate Transmission in a Podman container that shares a network namespace with a **dedicated Tailscale sidecar**. Only the sidecar uses the fly-vpn exit node; host `tailscaled` is never set as an exit client.

```
┌─ Goofeus host ─────────────────────────────────────────────┐
│  tailscaled: normal (no exit node)                          │
│  donetick, trek (separate trek-ts), caddy, sonarr, radarr   │
│                                                              │
│  ┌─ transmission-ts (sidecar) ────────────────────────────┐ │
│  │  tailscale → --exit-node=fly-vpn-exit                  │ │
│  │  (optional) --exit-node-allow-lan-access               │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌─ transmission (app container) ─────────────────────────┐ │
│  │  transmission-daemon, network=container:transmission-ts│ │
│  │  RPC published to host 127.0.0.1:9091 for *Arr         │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Why this works

- Torrent peer traffic exits via the sidecar's default route (fly-vpn exit node).
- Host homelab traffic, DNS, and Tailscale Serve are unchanged.
- Matches existing Nix patterns (`trek.nix`, `donetick.nix`, `caddy.nix`).
- Sonarr/Radarr continue using `http://127.0.0.1:9091` (or configured RPC port).

---

## fly-vpn workflow (host must not stay connected)

fly-vpn spawns `fly-vpn-exit` on the tailnet but auto-connects the **local** machine. For Goofeus:

1. **Launch** fly-vpn (creates ephemeral exit node on Fly.io).
2. **Immediately clear exit node on the host:**

   ```bash
   tailscale set --exit-node=
   ```

3. **Connect only inside the torrent sidecar:**

   ```bash
   tailscale set --exit-node=fly-vpn-exit --exit-node-allow-lan-access
   ```

4. **Stop** fly-vpn when done → teardown destroys Fly app + removes device from tailnet.

### fly-vpn gaps to address later

- No "spawn exit node but don't connect locally" mode.
- `connect_exit_node()` does not pass `--exit-node-allow-lan-access`.
- Possible follow-ups: patch fly-vpn, wrapper script, or Nix module that orchestrates launch + host disconnect + sidecar connect.

---

## Alternatives considered

| Approach | Verdict |
|----------|---------|
| Host-wide fly-vpn + LAN access on Goofeus | Partial fix; DNS/hairpin still broken |
| **tailsocks** (SOCKS5 via exit node) | Not suitable — Transmission P2P does not use SOCKS |
| `ip netns` + second `tailscaled` | Same idea as sidecar; more manual on NixOS |
| Policy routing (nftables owner `transmission`) | Possible but fragile; harder to maintain |
| Run fly-vpn on GoofyDesky/GoofyEnvy only | Good for general browsing; does not isolate Transmission on Goofeus |

---

## Implementation plan (future)

### Phase 1 — Document & manual proof of concept

- [ ] Launch fly-vpn; confirm `fly-vpn-exit` appears in `tailscale status`
- [ ] Clear host exit node; verify donetick + trek reachable
- [ ] Manual Podman: `transmission-ts` + `transmission` with shared netns
- [ ] Set exit node only in sidecar; verify public IP of torrent traffic (e.g. via tracker or `curl` from inside container)
- [ ] Confirm Sonarr/Radarr can reach RPC on published host port

### Phase 2 — NixOS module (`transmission-vpn.nix` or extend `arr.nix`)

- [ ] `virtualisation.oci-containers.containers.transmission-ts` — Tailscale sidecar
  - `TS_USERSPACE=false`, `NET_ADMIN`, `/dev/net/tun`
  - State dir on HDD (e.g. `/mnt/2TBSeagateHDD/servarr/transmission/tailscale-state`)
  - **No** Serve/Funnel unless needed; RPC stays on host loopback via port publish
- [ ] `virtualisation.oci-containers.containers.transmission` — official or homelab image
  - `networks = [ "container:transmission-ts" ]`
  - Volumes: existing `transmissionRoot` downloads + config
  - Environment: bind RPC to `0.0.0.0` inside netns; publish `127.0.0.1:9091:9091` on host
- [ ] systemd oneshot or script: `transmission-vpn-exit-node.service`
  - After fly-vpn exit is up: `tailscale set --exit-node=fly-vpn-exit` **inside sidecar only**
  - On stop: disconnect sidecar exit node
- [ ] Deprecate or disable `services.transmission` (native) once container path is stable
- [ ] Keep `caddy.nix` / `tailscale-serve` RPC proxy pointed at `127.0.0.1:9091`

### Phase 3 — Automation with fly-vpn lifecycle

- [ ] Wrapper: `fly-vpn-torrent` — launch fly-vpn, skip or revert host connect, connect sidecar
- [ ] Optional: integrate with Transmission "only when downloading" (start exit on queue non-empty)
- [ ] Watchdog / teardown: ensure host never left on exit node; sidecar disconnect on fly-vpn Stop

### Phase 4 — Hardening

- [ ] ACL: ensure `tag:ephemeral-vpn` (fly-vpn) and torrent sidecar tags are scoped
- [ ] Kill switch in sidecar netns if exit node drops (optional)
- [ ] Document operator runbook in this file

---

## Operator runbook (interim manual)

```bash
# 1. Start fly-vpn TUI and Launch (pick region)
fly-vpn

# 2. On Goofeus host — do NOT leave exit node on host
tailscale set --exit-node=

# 3. In transmission-ts sidecar (once module exists), or manual netns:
#    tailscale set --exit-node=fly-vpn-exit --exit-node-allow-lan-access

# 4. Use Transmission / let Sonarr-Radarr send jobs

# 5. When finished: Stop in fly-vpn TUI (teardown exit node + Fly app)
#    Confirm host: tailscale debug prefs → ExitNodeID empty
```

---

## References

- fly-vpn: `flyexit/tailscale.py` — `connect_exit_node()` is host-wide only
- Nix: `dendritic/nixos-modules/tailscale.nix` — Goofeus omits `--exit-node-allow-lan-access`
- Nix: `dendritic/nixos-modules/trek.nix` — sidecar pattern reference
- Nix: `dendritic/nixos-modules/arr.nix` — current Transmission (systemd, loopback RPC)
- Tailscale: exit nodes hijack DNS when `--accept-dns=true`; use "Use with exit node" on DNS resolvers in admin console if needed inside sidecar

---

## Open questions

1. Should the torrent sidecar use a **dedicated Tailscale identity** (`transmission-vpn`) or reuse host auth?
2. Auto-start exit node when Transmission has active torrents, or manual fly-vpn session only?
3. Patch upstream fly-vpn vs local wrapper for "no host connect"?
