# Goofeus Agent Coding Workspace — Planning

Status: **spec ready** — grill round 2 done; ready for Nix impl PR  
Hosts: **Goofeus** (primary agent runtime) ↔ **GoofyDesky** (desk handoff)  
Stack: **pi** + **pi-interactive-subagents** (tmux) + **handmux** (phone PWA) — **locked**

---

## Goals

1. Dedicated Linux user on Goofeus for AFK / phone-driven agent coding.
2. Full pi stack (extensions, skills, vendor submodules) from this repo — deployed on rebuild.
3. Phone access to live pi TUI sessions (approve prompts, git review, shell use).
4. Smooth handoff: code on phone outside → continue on GoofyDesky at home (same session when possible).
5. Keep **orchestrator + tmux subagents** workflow — non-negotiable.

**Out of scope (for now):** Droid / Nix-on-Droid access.

---

## Locked decisions

| Topic | Decision |
|-------|----------|
| Compute | **Goofeus primary** — agent runs on Goofeus; phone connects there |
| Linux user | **`agent`** HM user + **root** stays admin/remote-builder |
| Root `NixConfig` | **Deprecated for builds** — agent owns `~/NixConfig`; root may build from `/home/agent/NixConfig` |
| Phone frontend | **handmux + tmux** — **locked** (muxr / Herdr mobile relay rejected) |
| Multiplexer | **tmux** — **locked** — required by `pi-interactive-subagents` |
| handmux network | **Tailscale only** — no public tunnel; bind tailnet IP |
| handmux pkg | **buildNpmPackage from npm** (pinned), Node ≥ 22.16 |
| handmux boot | **systemd autostart** (`handmux service install`) under agent user |
| tmux boot | **Empty `agents` session** on boot — pi started manually |
| NixConfig deploy | **Auto-pull on HM switch** — `main` = flake SSOT; agent work in **worktrees** |
| Desk handoff | **SSH attach only** — `ssh agent@goofeus -t tmux attach -t agents` |
| GoofyDesky pi | **Local pi + SSH** — goofy keeps desk pi; shared sessions via Goofeus attach |
| Rebuilds | **agent runs rebuild** — **manual sudo with password**; **never** passwordless sudo for agent |
| Engram | **Local per host** — cross-host sync **deferred** (see TODO below) |
| SSH keys | **Fleet keys** — GoofyDesky, GoofyEnvy, Droid (same as root pattern) |
| agenix / secrets | **Full nushell HM** on agent — cursor-api-key, github-mcp-token, etc. |
| agent decrypt | **Agent own age key** — never reuse root host key |
| Bootstrap | **Remote builder** from GoofyDesky — `nh os switch --flake .#Goofeus` triggers first Goofeus rebuild creating agent user |
| Droid | Dismissed (Nix-on-Droid access via handmux N/A for now; SSH key still in fleet) |

---

## Why not muxr / Herdr

`pi-interactive-subagents` is **tmux-only** — splits subagent panes off `TMUX_PANE`. Herdr replaces tmux for muxr/Herdr-mobile stack → subagents break.

| Stack | Subagents | muxr inbox |
|-------|-----------|------------|
| Herdr pane → pi | ❌ | ✅ |
| Herdr → tmux → pi (nested) | ⚠️ maybe | ❌ agent detection sees tmux not pi |
| tmux → pi | ✅ | ❌ muxr cannot attach |

**handmux** wraps **existing tmux** — no multiplexer swap. Same panes on phone and via `ssh agent@goofeus -t tmux attach`.

---

## Target architecture

```
Goofeus (NixOS)
├── root@goofeus
│   ├── remote builder / admin
│   ├── homeConfigurations.Goofeus (shell tooling only)
│   └── may nix build using /home/agent/NixConfig
│
└── agent@goofeus
    ├── ~/NixConfig              ← main branch; auto-pull on HM switch; worktrees for agent work
    ├── HM: pi-coding-agent, tmux, worktrunk, handmux, …
    ├── tmux session "agents"    ← empty shell on boot; pi started manually
    │   └── pi orchestrator (+ subagent panes when running)
    ├── handmux (systemd)        → PWA + push on Tailscale only
    └── ~/.pi/agent/*            ← HM symlinks from pi-coding-agent module

Phone (Android)
└── handmux PWA (Add to Home Screen) over Tailscale

GoofyDesky (home)
└── ssh agent@goofeus -t tmux attach -t agents   # same panes as phone
```

---

## Locked runtime stack (handmux + tmux)

Contract — do not swap without revisiting subagents:

```
agent@goofeus
  # boot: empty tmux + handmux systemd (Tailscale bind)
  tmux attach -t agents          # shell; start pi when needed
  pi                             # orchestrator; subagents split in tmux
  handmux agent enable pi

Phone     → handmux PWA → one focused pane; inbox to jump panes
GoofyDesky → local pi (goofy) OR ssh agent@goofeus -t tmux attach -t agents
```

Rejected: muxr, Herdr mobile relay, zellij-as-phone-primary, agent-tmux-web (unless fallback only).

---

## handmux (phone frontend)

**What it is:** Self-hosted mobile cockpit around **real tmux panes** — not a read-only mirror, not agent-only.

**Shell use:** Yes. Command mode = direct terminal input. Any pane can be plain shell; agent inbox/smart status only on integrated agent panes (Codex built-in; Pi via `handmux agent enable pi`).

**Typical runtime:**

```bash
tmux new -A -s agents 'pi'   # orchestrator + subagent splits
handmux agent enable pi
handmux setup                # push, tunnel if needed
handmux service install      # optional autostart after reboot
handmux start                # LAN or --public-url for Tailscale IP
```

**Phone:** scan QR → PWA. Push when pane needs you. Git diff viewer, file preview, tmux split/close from phone.

**Desk handoff:** `ssh agent@goofeus -t tmux attach -t agents` — literal same session phone drives.

**Phone pane UX:** handmux shows **one full-width pane** at a time — not a squished multi-split mosaic. Inbox/pane map to jump between orchestrator and subagent panes.

**Network:** Tailscale only — `handmux start` on tailnet IP; no Cloudflare/public tunnel.

**Nix:** no nixpkgs yet — wrap `handmux` via `buildNpmPackage` in agent HM.

**Tradeoffs vs Herdr mobile relay:**

| handmux wins | Herdr relay wins |
|--------------|------------------|
| Keeps tmux + subagents | E2EE relay, per-device audit |
| Zero migration | Native Pi structured approvals |
| Git cockpit, web preview | Multi-machine agent herd |
| No vendor cloud | Richer agent lifecycle UI |

**Fallback:** mosh + Termux + SSH attach — best LTE, no inbox/git UI.

---

## Session / memory continuity (GoofyDesky)

**Daily flow:** SSH attach to Goofeus tmux — no pi-sync from day one.

**GoofyDesky:** keep local `goofy` pi for desk work; attach to Goofeus for shared phone sessions.

**Deferred (not in v1):**

| Layer | Scope | Status |
|-------|-------|--------|
| `@ersintarhan/pi-sync` / `pi-cloud-sessions` | session JSONL | later if needed |
| Engram cross-host sync | memory/facts | **TODO** — see below |

---

## Current repo state

| Area | Goofeus today | GoofyDesky |
|------|---------------|------------|
| HM user | `root` only | `goofy` |
| `pi-coding-agent` | ❌ | ✅ |
| tmux / worktrunk | ❌ | ✅ |
| NixConfig clone | manual `/root/NixConfig` | manual `~/NixConfig` |
| Syncthing | Music/Obsidian/OfflineMedia — not NixConfig | same |
| Tailscale + SSH keys | ✅ (Desky/Envy/Droid keys) | ✅ |

`pi-coding-agent` module wires: `dendritic/skills/` → `~/.pi/agent/skills/`, extension loaders → vendor under `~/NixConfig/vendor/`, `pi-npm-i` for vendor npm builds. See `dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix`, `dendritic/skills/pi-setup/REFERENCE.md`.

---

## Implementation plan (Nix)

### 1. New NixOS user + HM config

- Add `users.users.agent` on Goofeus NixOS module.
- New `homeConfigurations.Goofeus-agent` (name TBD) with agent stack:

```nix
# Minimum agent slice (mirror GoofyEnvy agent modules)
pi-coding-agent
tmux
zellij          # optional alt mux
worktrunk       # linear ticket worktrees
bash
carapace
# handmux       # buildNpmPackage wrap — add module
```

- Keep `homeConfigurations.Goofeus` (root) as shell tooling only — no pi stack.
- SSH: phone + GoofyDesky keys → `agent@goofeus`.

### 2. NixConfig clone on rebuild — **locked: auto-pull**

HM `home.activation` on agent user:

- If `~/NixConfig/.git` missing → `git clone --recurse-submodules <url>`.
- On every `home-manager switch` → `git fetch` + fast-forward **`main`** + `submodule update --init --recursive`.
- **`main` = flake SSOT** for `nixos-rebuild` / `nh os switch`; agent coding work in **worktrees** (`worktrunk`) so auto-pull on main is safe.
- agenix deploy key or gh credential for private repo.

### 3. Root builder path

- Point `NH_OS_FLAKE` / remote builder at `/home/agent/NixConfig`.
- Deprecate `/root/NixConfig` clone over time.

### 4. handmux module — **locked**

- Wrap `handmux` via `buildNpmPackage` in agent HM.
- `handmux service install` on first deploy — systemd user autostart.
- Tailscale bind only — no tunnel flags in service config.
- `handmux agent enable pi` in setup docs / optional activation hook.

### 5. Boot services (agent user)

- systemd: **handmux** autostart.
- systemd or login hook: `tmux new -A -ds agents` (empty shell, no pi).
- pi started manually after attach.

### 6. Rebuilds — **locked**

- agent may run `nixos-rebuild` / `nh os switch` from `~/NixConfig` **main**.
- **Requires interactive sudo password** — no passwordless sudo for agent, ever.
- Rebuild from phone: handmux shell → `cd ~/NixConfig && sudo nh os switch` (user types pw).

### 7. Secrets (agenix)

- cursor-api-key, github-mcp-token, etc. — extend `secrets.nix` for agent user if not already covered.
- Session sync secrets (`PI_SYNC_*`) — only if B-layer enabled; not in NixConfig git.

### 8. Post-rebuild manual (until automated)

```bash
cd ~/NixConfig && pi-npm-i
pi list   # verify exts/skills
```

---

## Deferred TODO (out of v1 scope)

- [ ] **Engram cross-host sync** — Goofeus `agent` vs GoofyDesky `goofy` local SQLite; evaluate git chunks / Engram Cloud later
- [ ] **handmux Pi approve UX** — validate structured permission cards vs raw TUI on real Goofeus box
- [ ] **pi-sync** — only if SSH attach insufficient for offline handoff

---

## Implementation notes (locked)

### handmux packaging
- Wrap `handmux` via **`buildNpmPackage`** from npm registry (pinned version), Node ≥ 22.16 runtime.
- No vendor submodule — npm wrap fits repo convention for non-repo-own tooling.

### agenix decrypt for agent
- **Agent own age key**: dedicated passphrase-less ed25519 identity for agent user.
- Add agent age pubkey to `secrets.nix` recipients (`cursor-api-key`, `github-mcp-token`, …).
- `nushell` HM on agent: `age.identityPaths = [ <agentKey> ]` (mirror root's host-key pattern, but own key).
- Root's `/etc/ssh/ssh_host_ed25519_key` stays root-only — **never** shared with agent.

### Bootstrap sequence (document in `pi-setup/REFERENCE.md`)
- From **GoofyDesky** (goofy): `nh os switch --flake .#Goofeus` → build via Goofeus remote builder + activate.
- First run creates `agent` user + HM; NixConfig auto-pull provisions `/home/agent/NixConfig`.
- Agent user gets fleet SSH keys (Desky/Envy/Droid) for subsequent access.

---

## Alternatives reference

### Phone frontends compared

| Option | Subagents | Phone UX | Nix | Notes |
|--------|-----------|----------|-----|-------|
| **handmux + tmux** | ✅ | 8/10 | wrap npm | **chosen** |
| Herdr + mobile relay | ❌ | 9/10 | partial | best inbox; kills tmux subagents |
| mosh + Termux | ✅ | 3/10 | ✅ | emergency fallback |
| agent-tmux-web APK | ✅ | 6/10 | wrap npm | no pi launcher |
| muxr (trymuxr) | ❌ | 9/10 | wrap npm | requires Herdr |

### Session sync architectures

| | A: SSH-primary | B: pi-sync ext | C: Syncthing sessions |
|--|----------------|----------------|------------------------|
| Continuity | live attach | handoff after close | handoff after close |
| Conflict risk | low | medium (LWW) | high |
| Nix complexity | low | medium | low |

**Pragmatic path:** A now, B when offline-on-Goofeus → resume-on-Desky needed without SSH.

---

## Implementation status (2026-09-04)

**Done — verified eval/build on GoofyDesky:**

- `dendritic/home-modules/handmux/handmux.nix` — buildNpmPackage 0.26.0 (vendored lockfile, npmDepsHash, custom installPhase for npm10 pack-json change). Smoke-tested: `handmux --help` runs.
- `dendritic/home-modules/nixconfig-sync.nix` — auto-pull ~/NixConfig on HM switch (clone / ff main / submodules).
- `dendritic/hosts/Goofeus.nix` — `homeConfigurations.GoofeusAgent` (pi stack + tmux zellij worktrunk handmux bash carapace nixconfig-sync), `users.users.agent` (fleet SSH keys), `home-manager.users.agent`, NixOS `age.secrets.agent-age-key` (owner=agent), handmux systemd user service + empty `agents` tmux boot service.
- `dendritic/home-modules/home.nix` / `nushell.nix` / `atuin.nix` — switched to `config.home.username` (per-user) instead of host-global `username` specialArg; fixes 2-user hosts. All hosts eval (Goofeus/Desky/Envy).
- `secrets/secrets.nix` — `AgentAge` pubkey added to 7 API secrets, `agent-age-key.age` encrypted (recipients: Goofeus hostkey + GoofyDeskyRoot); rekeyed; AgentAge decrypt verified.

**Pending (on Goofeus at deploy):**

- Bootstrap from GoofyDesky: `nh os switch --flake .#Goofeus` (creates agent user first run).
- First login: `passwd agent`, `handmux setup` (enable pi + push), `handmux agent enable pi`.
- `pi-npm-i` in ~/NixConfig after first clone.
- NixOS `age.secrets.agent-age-key` path lands at `/run/agenix/agent-age-key` — already wired into agent HM `age.identityPaths`.

**Notes:** handmux launcher works even though `nodejsInstallExecutables` uses build-provided node; systemd unit env pins node_22 + tmux PATH. Temp agent private key under `$TMPDIR/agent-tmp/agent-agekey/` (do NOT delete until Goofeus bootstrapped; needed once to re-encrypt if recipient set grows).

---

## Sources

- [handmux README](https://github.com/handmux/handmux) — tmux wrap, Pi agent, PWA, restore, tunnels
- [handmux docs](https://handmux.com/docs)
- [Herdr agents](https://herdr.dev/docs/agents/) — Pi hooks, tmux-nesting caveat
- [pi-interactive-subagents](vendor/mattgmak/pi-interactive-subagents/) — tmux requirement
- Local: `dendritic/hosts/Goofeus.nix`, `GoofyDesky.nix`, `pi-coding-agent.nix`, `syncthing.nix`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-09-03 | Initial plan from grill session — decisions, handmux choice, Nix outline |
| 2026-09-03 | **Locked** handmux + tmux phone stack; SSH desk attach default |
| 2026-09-03 | Grill round 2: agent user, auto-pull main, Tailscale-only, boot services, sudo policy, Engram deferred |
| 2026-09-03 | Grill round 3: fleet SSH keys, nushell/agenix HM, remote-builder bootstrap |
| 2026-09-03 | Grill round 4: handmux buildNpmPackage, agent own age key, nh os switch bootstrap |
