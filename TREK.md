# TREK self-host plan — Goofeus

Self-host [TREK](https://github.com/mauriceboe/TREK) on `Goofeus` with Costs (bill-splitting), Tailscale Funnel for public access, and invite-only auth.

## Decisions (locked in)

| Item | Choice |
|------|--------|
| Host | `Goofeus` (`dendritic/hosts/Goofeus.nix`) |
| Version | Build from pinned `dev` commit (Costs feature) |
| Public access | **Tailscale Funnel only** (no Cloudflare/Caddy vhost) |
| Tailnet access | Tailscale Serve on dedicated sidecar node `trek` |
| Auth | Invite-only (`DISABLE_LOCAL_REGISTRATION=true`) |
| Admin email | `172981@gmail.com` |
| `APP_URL` | `https://trek.dab-octatonic.ts.net` |
| Collaborators | ~5 people per trip |
| Image build | `trek-image-build.service` (podman on host at deploy) |

## Costs feature — release status

**[PR #1106](https://github.com/mauriceboe/TREK/pull/1106)** merged to `dev` on 2026-06-04. Not in any published Docker Hub tag (`latest` = v3.0.22, May 2026).

| Feature | Details |
|---------|---------|
| Rename | Budget → **Costs** (UI only; DB/MCP ids unchanged) |
| Bill splitting | Multiple payers, equal split, settle-up with undo |
| Currency | Per-expense currency + live FX to display currency |
| Mobile | Dedicated Costs layout + quick-add from bottom nav |

**Pinned commit:** `e65acb3de765f3c958dd4e139064b11fbbde79d1` (dev HEAD at plan time, includes bug batch #1145).

Bump `inputs.trek-src` URL in `flake.nix` when you want a newer dev build.

## URLs

| Audience | URL | How |
|----------|-----|-----|
| Public (guests, no Tailscale) | `https://trek.dab-octatonic.ts.net` | Tailscale Funnel |
| Tailnet (your devices) | `https://trek.dab-octatonic.ts.net` | Tailscale Serve (same hostname) |
| ~~Cloudflare~~ | ~~`trek.px.goofy.me.in`~~ | **Not used** (funnel-only) |

### Tailnet routing vs Funnel

Both **Serve** and **Funnel** are configured on the `trek-ts` sidecar via `TS_SERVE_CONFIG` with `AllowFunnel: true` for `trek.dab-octatonic.ts.net:443` → `http://127.0.0.1:3000`.

- **Your tailnet devices** reach the `trek` node directly over WireGuard (dedicated sidecar, not Goofeus host serve).
- **Public guests** hit Tailscale's Funnel edge, which proxies inbound HTTPS to the sidecar.
- **Same hostname** (`trek.dab-octatonic.ts.net`) works for both audiences. Tailnet clients are still routed over the tailnet where possible.

No Cloudflare DNS record is required for Funnel — Tailscale provides DNS + TLS on `*.ts.net`.

## Architecture

```
Public internet ──► Tailscale Funnel edge ──► trek-ts (sidecar) :443 ──► 127.0.0.1:3000 (TREK)
Your tailnet    ──► Tailscale Serve        ──► trek-ts (sidecar) :443 ──► 127.0.0.1:3000 (TREK)
                                                          │
                                                          ▼
                                            /mnt/2TBSeagateHDD/trek/
                                              ├── data/            (SQLite)
                                              ├── uploads/         (photos, files)
                                              └── tailscale-state/ (sidecar identity)
```

Two Podman containers share a network namespace (sidecar pattern):

| Container | Role |
|-----------|------|
| `trek-ts` | Tailscale client; MagicDNS hostname `trek`; Serve + Funnel via `TS_SERVE_CONFIG` |
| `trek` | TREK app; `--network=container:trek-ts`; listens on `127.0.0.1:3000` inside the pod |

TREK is **not** exposed on the Goofeus host `tailscale0` or via `svc:trek` / `tailscale-serve` in `caddy.nix`.

## Nix modules

| File | Role |
|------|------|
| `flake.nix` | `trek-src` input (pinned dev rev) |
| `dendritic/packages/trek-image.nix` | Image build script + metadata (`trek:dev-<rev>`) |
| `dendritic/nixos-modules/trek.nix` | Sidecar + TREK containers, serve config, secrets, state dir |
| `dendritic/hosts/Goofeus.nix` | Import `trek` module |
| `dendritic/nixos-modules/restic-goofeus.nix` | Backup `/mnt/2TBSeagateHDD/trek` |
| `secrets/trek-env.age` | `ENCRYPTION_KEY`, `ADMIN_PASSWORD` |
| `secrets/trek-tailscale-auth.age` | `TS_AUTHKEY` for the sidecar |

## Environment variables

```dotenv
NODE_ENV=production
PORT=3000
TZ=Asia/Hong_Kong
FORCE_HTTPS=true
TRUST_PROXY=1
APP_URL=https://trek.dab-octatonic.ts.net
ALLOWED_ORIGINS=https://trek.dab-octatonic.ts.net
DISABLE_LOCAL_REGISTRATION=true
ADMIN_EMAIL=172981@gmail.com
# ADMIN_PASSWORD + ENCRYPTION_KEY from secrets/trek-env.age
```

Sidecar auth (`secrets/trek-tailscale-auth.age`):

```dotenv
TS_AUTHKEY=tskey-auth-...?ephemeral=false
```

The sidecar uses **host DNS** (`/etc/resolv.conf` + `1.1.1.1`/`8.8.8.8` fallbacks) with `TS_ACCEPT_DNS=false`. MagicDNS alone (`100.100.100.100`) cannot forward to Let's Encrypt for Serve TLS unless your tailnet has global nameservers configured in admin.

`ENCRYPTION_KEY`: generate with `openssl rand -hex 32`.

## Security (Funnel + invite-only)

| Risk | Mitigation |
|------|------------|
| Public login page | Registration disabled; you create accounts |
| Brute-force login | Strong `ADMIN_PASSWORD`; ~5 trusted users |
| Bot scanners | No open signup; monitor logs |
| No Cloudflare WAF | Acceptable for small group; add Caddy vhost later if abused |
| Session cookies | `FORCE_HTTPS=true` + Tailscale TLS |

**Tailnet ACL** — allow Funnel on the trek sidecar node:

```json
"tagOwners": {
  "tag:trek": ["autogroup:admin"]
},
"nodeAttrs": [
  { "target": ["tag:trek"], "attr": ["funnel"] }
]
```

## Tailscale sidecar setup

1. **Remove `svc:trek`** from the [Tailscale Services](https://login.tailscale.com/admin/services) admin console (migrating from host-based serve).
2. In ACL: define `tag:trek` in `tagOwners` and grant `funnel` node attribute (see above).
3. Create a **reusable auth key** tagged with `tag:trek` (Settings → Keys).
4. `cd secrets && agenix -e trek-tailscale-auth.age` — set `TS_AUTHKEY=<key>`.
5. Deploy; the `trek-ts` container joins the tailnet as hostname `trek` and applies Serve + Funnel from `TS_SERVE_CONFIG`.

Serve config (rendered by Nix into the sidecar `/config/serve.json`):

```json
{
  "TCP": { "443": { "HTTPS": true } },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": { "/": { "Proxy": "http://127.0.0.1:3000" } }
    }
  },
  "AllowFunnel": { "${TS_CERT_DOMAIN}:443": true }
}
```

`${TS_CERT_DOMAIN}` is expanded by containerboot to `trek.dab-octatonic.ts.net`.

## Caddy / reverse proxy notes

TREK wiki requirements when behind a proxy:

- WebSocket upgrades on `/ws` (automatic with Tailscale proxy)
- Body size ≥ 500 MB for backup restore (use tailnet access if large restores fail over funnel)

No Caddy vhost is configured (funnel-only). Caddy module remains enabled for other services on Goofeus.

## Auth workflow (invite-only)

1. First boot: admin created with `172981@gmail.com` + password from `trek-env.age`
2. Admin → Settings: confirm registration disabled
3. Admin → Users: create accounts for trip members
4. Per trip: invite collaborators via trip share/invite links

## Data & backups

| Path | Contents |
|------|----------|
| `/mnt/2TBSeagateHDD/trek/data` | SQLite, logs, keys |
| `/mnt/2TBSeagateHDD/trek/uploads` | Photos, documents, avatars |
| `/mnt/2TBSeagateHDD/trek/tailscale-state` | Sidecar Tailscale identity |

Included in `restic-goofeus` daily backup to B2. TREK also has built-in backup/restore in Admin UI.

## Image build

Podman cannot run inside the Nix build sandbox (needs host user namespaces), so the OCI image is built **on the host at deploy time**, not during `nix build`.

| Step | What happens |
|------|----------------|
| `nix build` / `nixos-rebuild` | Installs `packages.trek-image` (a `trek-image-build` script only) |
| `trek-image-build.service` | Runs before `podman-trek`; `podman build` from `inputs.trek-src` |
| `podman-trek-ts.service` | Starts Tailscale sidecar (before TREK) |
| `podman-trek.service` | Starts TREK in the sidecar network namespace |

```bash
# Deploy (image build runs automatically on first switch / rev bump)
nh os switch --hostname Goofeus

# Watch first-time image build (~10–20 min)
journalctl -fu trek-image-build.service

# Manual rebuild (e.g. after bumping trek-src)
sudo systemctl start trek-image-build.service
sudo systemctl restart podman-trek.service
```

To build the image by hand without switching:

```bash
nix run .#packages.x86_64-linux.trek-image --command trek-image-build
```

Rebuild when you bump the `trek-src` flake input (tag changes to `dev-<new-rev>`).

## Pre-deploy checklist

```
Secrets
  [ ] cd secrets && agenix -e trek-env.age
      ENCRYPTION_KEY=<openssl rand -hex 32>
      ADMIN_PASSWORD=<strong password>
  [ ] cd secrets && agenix -e trek-tailscale-auth.age
      TS_AUTHKEY=<reusable key tagged tag:trek>

Tailnet ACL + migration
  [ ] Define tag:trek in tagOwners; grant funnel node attribute
  [ ] Remove svc:trek from Tailscale admin Services (if present)

Deploy
  [ ] nh os switch --hostname Goofeus

Verify
  [ ] journalctl -u trek-image-build.service   # image built OK
  [ ] systemctl status podman-trek-ts podman-trek
  [ ] tailscale status   # should show node "trek" (from sidecar)
  [ ] curl -s https://trek.dab-octatonic.ts.net/api/health
  [ ] Login as admin from tailnet device
  [ ] Test funnel URL from phone on cellular (no Tailscale)
  [ ] Create test trip → Costs → multi-payer expense → settle-up
  [ ] Invite a collaborator; confirm they cannot self-register
  [ ] Check restic backup includes /mnt/2TBSeagateHDD/trek
```

## Upgrading TREK

1. Check `dev` branch / PRs for fixes
2. Update `trek-src` rev in `flake.nix`
3. `nh os switch --hostname Goofeus` (rebuilds image if tag changed)
4. Data in `/mnt/2TBSeagateHDD/trek` persists across image updates

## Rollout risks (dev branch)

| Risk | Notes |
|------|-------|
| Bleeding-edge | `dev` is active; pin commits, don't float |
| NestJS migration | Large backend rewrite (#1087); test core flows |
| Costs migration | Budget items auto-migrated on first load |
| Image build time | Multi-stage Node 24 build, ~10–20 min first time |

Recent fixes on pinned commit: #1145, #1139, #1113 (post-Costs hardening).

## Future options

- Add `trek.px.goofy.me.in` via Caddy + Cloudflare if Funnel gets abused (WAF, rate limits)
- Switch to stable `mauriceboe/trek:3.x` when Costs ships in a release
- OIDC/SSO via `OIDC_*` env vars + agenix secrets
