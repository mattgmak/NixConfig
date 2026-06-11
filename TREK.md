# TREK self-host plan — Goofeus

Self-host [TREK](https://github.com/mauriceboe/TREK) on `Goofeus` with Costs (bill-splitting), Tailscale Funnel for public access, and invite-only auth.

## Decisions (locked in)

| Item | Choice |
|------|--------|
| Host | `Goofeus` (`dendritic/hosts/Goofeus.nix`) |
| Version | Build from pinned `dev` commit (Costs feature) |
| Public access | **Tailscale Funnel only** (no Cloudflare/Caddy vhost) |
| Tailnet access | Tailscale Serve (`svc:trek`) |
| Auth | Invite-only (`DISABLE_LOCAL_REGISTRATION=true`) |
| Admin email | `172981@gmail.com` |
| `APP_URL` | Funnel URL (see below) |
| Collaborators | ~5 people per trip |
| Image build | Nix `packages.trek-image` (podman build from source) |

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
| Public (guests, no Tailscale) | `https://trek-goofeus.dab-octatonic.ts.net` | Tailscale Funnel |
| Tailnet (your devices) | `https://trek-goofeus.dab-octatonic.ts.net` | Tailscale Serve (same hostname) |
| ~~Cloudflare~~ | ~~`trek.px.goofy.me.in`~~ | **Not used** (funnel-only) |

### Tailnet routing vs Funnel

Both **Serve** and **Funnel** are configured on `svc:trek` → `127.0.0.1:3000`.

- **Your tailnet devices** using the Serve path get **direct WireGuard routing** to Goofeus when NAT traversal succeeds (same as Donetick, Immich, etc.). Traffic does not hairpin out to the public internet.
- **Public guests** hit Tailscale's Funnel edge, which proxies inbound HTTPS to your machine.
- **Same hostname** (`trek-goofeus.dab-octatonic.ts.net`) works for both audiences once funnel is enabled on `svc:trek`. Tailnet clients are still routed over the tailnet where possible.

No Cloudflare DNS record is required for Funnel — Tailscale provides DNS + TLS on `*.ts.net`.

## Architecture

```
Public internet ──► Tailscale Funnel edge ──► goofeus:443 ──► 127.0.0.1:3000 (TREK)
Your tailnet    ──► Tailscale Serve        ──► goofeus:443 ──► 127.0.0.1:3000 (TREK)
                                                          │
                                                          ▼
                                            /mnt/2TBSeagateHDD/trek/
                                              ├── data/     (SQLite)
                                              └── uploads/  (photos, files)
```

TREK container binds **loopback only** (`127.0.0.1:3000`). No host port on `tailscale0` except via Tailscale proxy.

## Nix modules

| File | Role |
|------|------|
| `flake.nix` | `trek-src` input (pinned dev rev) |
| `dendritic/packages/trek-image.nix` | OCI image build via podman |
| `dendritic/nixos-modules/trek.nix` | Container, secrets, state dir |
| `dendritic/nixos-modules/caddy.nix` | Tailscale Serve + Funnel for `svc:trek` |
| `dendritic/hosts/Goofeus.nix` | Import `trek` module |
| `dendritic/nixos-modules/restic-goofeus.nix` | Backup `/mnt/2TBSeagateHDD/trek` |
| `secrets/trek-env.age` | `ENCRYPTION_KEY`, `ADMIN_PASSWORD` |

## Environment variables

```dotenv
NODE_ENV=production
PORT=3000
TZ=Asia/Hong_Kong
FORCE_HTTPS=true
TRUST_PROXY=1
APP_URL=https://trek-goofeus.dab-octatonic.ts.net
ALLOWED_ORIGINS=https://trek-goofeus.dab-octatonic.ts.net
DISABLE_LOCAL_REGISTRATION=true
ADMIN_EMAIL=172981@gmail.com
# ADMIN_PASSWORD + ENCRYPTION_KEY from secrets/trek-env.age
```

`ENCRYPTION_KEY`: generate with `openssl rand -hex 32`.

## Security (Funnel + invite-only)

| Risk | Mitigation |
|------|------------|
| Public login page | Registration disabled; you create accounts |
| Brute-force login | Strong `ADMIN_PASSWORD`; ~5 trusted users |
| Bot scanners | No open signup; monitor logs |
| No Cloudflare WAF | Acceptable for small group; add Caddy vhost later if abused |
| Session cookies | `FORCE_HTTPS=true` + Tailscale TLS |

**Tailnet ACL** — allow Funnel on Goofeus:

```json
"nodeAttrs": [
  { "target": ["tag:goofeus"], "attr": ["funnel"] }
]
```

## Tailscale proxy commands

```bash
# Tailnet-only (direct routing for your devices)
tailscale serve --yes --service=svc:trek --https=443 127.0.0.1:3000

# Public internet (trip collaborators without Tailscale)
tailscale funnel --yes --service=svc:trek --https=443 127.0.0.1:3000
```

Managed by `systemd.services.tailscale-serve` in `caddy.nix`.

## Caddy / reverse proxy notes

TREK wiki requirements when behind a proxy:

- WebSocket upgrades on `/ws` (automatic with Tailscale proxy)
- Body size ≥ 500 MB for backup restore (use tailnet access if large restores fail over funnel)

No Caddy vhost is configured (funnel-only). Caddy module remains enabled for other services.

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

Included in `restic-goofeus` daily backup to B2. TREK also has built-in backup/restore in Admin UI.

## Image build

```bash
# Build image locally (first deploy; needs network for npm in Dockerfile)
nix build .#packages.x86_64-linux.trek-image

# Deploy
nh os switch --hostname Goofeus
```

The image is built with podman from `inputs.trek-src` (pinned dev commit). Rebuild when you bump the flake input.

**Note:** Docker/podman build inside the Nix derivation may require sandbox disabled:

```bash
nix build .#packages.x86_64-linux.trek-image --option sandbox false
```

## Pre-deploy checklist

```
Secrets
  [ ] cd secrets && agenix -e trek-env.age
      ENCRYPTION_KEY=<openssl rand -hex 32>
      ADMIN_PASSWORD=<strong password>

Tailnet ACL
  [ ] Enable funnel attribute on Goofeus node

Deploy
  [ ] nix build .#packages.x86_64-linux.trek-image
  [ ] nh os switch --hostname Goofeus

Verify
  [ ] curl -s https://trek-goofeus.dab-octatonic.ts.net/api/health
  [ ] Login as admin from tailnet device
  [ ] Test funnel URL from phone on cellular (no Tailscale)
  [ ] Create test trip → Costs → multi-payer expense → settle-up
  [ ] Invite a collaborator; confirm they cannot self-register
  [ ] Check restic backup includes /mnt/2TBSeagateHDD/trek
```

## Upgrading TREK

1. Check `dev` branch / PRs for fixes
2. Update `trek-src` rev in `flake.nix`
3. `nix build .#packages.x86_64-linux.trek-image`
4. `nh os switch --hostname Goofeus`
5. Data in `/mnt/2TBSeagateHDD/trek` persists across image updates

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
