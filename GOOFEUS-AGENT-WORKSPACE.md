# Goofeus Agent Coding Workspace — Planning

Status: **spec ready** — grill round 2 done; ready for Nix impl PR  
Hosts: **Goofeus** (primary agent runtime) ↔ **GoofyDesky** (desk handoff)  
Stack: **pi** + **pi-interactive-subagents** (tmux) — **locked**

---

## Goals

1. Dedicated Linux user on Goofeus for AFK / phone-driven agent coding.
2. Full pi stack (extensions, skills, vendor submodules) from this repo — deployed on rebuild.
3. Live pi TUI access from any browser via SSH + tmux (approve prompts, git review, shell use).
4. Smooth handoff: code on phone outside → continue on GoofyDesky at home (same session when possible).
5. Keep **orchestrator + tmux subagents** workflow — non-negotiable.

**Out of scope (for now):** Droid / Nix-on-Droid access.

---

## Locked decisions

| Topic | Decision |
|-------|----------|
| Compute | **Goofeus primary** — agent runs on Goofeus; phone connects there |
| Linux user | **`agent`** HM user + **root** stays admin/remote-builder |
| Root `NixConfig` | **Deploy-time pin** — `scripts/deploy-goofeus.sh` symlinks it to the deployed flake source store path (gcroot); agent owns its own `~/NixConfig` workspace |
| Frontend | **No phone/PWA frontend** — browser via SSH tmux only |
| Multiplexer | **tmux** — **locked** — required by `pi-interactive-subagents` |
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
| Droid | Dismissed (Nix-on-Droid access N/A for now; SSH key still in fleet) |

---

## Why not muxr / Herdr

`pi-interactive-subagents` is **tmux-only** — splits subagent panes off `TMUX_PANE`. Herdr replaces tmux for muxr/Herdr-mobile stack → subagents break.

| Stack | Subagents | muxr inbox |
|-------|-----------|------------|
| Herdr pane → pi | ❌ | ✅ |
| Herdr → tmux → pi (nested) | ⚠️ maybe | ❌ agent detection sees tmux not pi |
| tmux → pi | ✅ | ❌ muxr cannot attach |

**tmux** is the only multiplexer — no swap. Same panes from any client via `ssh agent@goofeus -t tmux attach`.

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
    ├── HM: pi-coding-agent, tmux, worktrunk, …
    ├── tmux session "agents"    ← empty shell on boot; pi started manually
    │   └── pi orchestrator (+ subagent panes when running)
    └── ~/.pi/agent/*            ← HM symlinks from pi-coding-agent module

Browser / phone (SSH only)
└── ssh agent@goofeus -t tmux attach -t agents

GoofyDesky (home)
└── ssh agent@goofeus -t tmux attach -t agents   # same panes as any other client
```

---

## Locked runtime stack (tmux)

Contract — do not swap without revisiting subagents:

```
agent@goofeus
  # boot: empty tmux session
  tmux attach -t agents          # shell; start pi when needed
  pi                             # orchestrator; subagents split in tmux

Browser / phone → ssh agent@goofeus -t tmux attach -t agents
GoofyDesky      → local pi (goofy) OR ssh agent@goofeus -t tmux attach -t agents
```

Rejected: muxr, Herdr mobile relay, zellij-as-phone-primary, agent-tmux-web (unless fallback only).

---

## Session / memory continuity (GoofyDesky)

**Daily flow:** SSH attach to Goofeus tmux — no pi-sync from day one.

**GoofyDesky:** keep local `goofy` pi for desk work; attach to Goofeus for shared sessions.

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

`pi-coding-agent` module wires: `dendritic/skills/` → `~/.pi/agent/skills/`, extension loaders → vendor under `~/NixConfig/vendor/`, `pi-ext-deps-install` for vendor npm builds. See `dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix`, `dendritic/skills/pi-setup/REFERENCE.md`.

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
```

- Keep `homeConfigurations.Goofeus` (root) as shell tooling only — no pi stack.
- SSH: phone + GoofyDesky keys → `agent@goofeus`.

### 2. NixConfig clone on rebuild — **locked: auto-pull**

HM `home.activation` on agent user:

- If `~/NixConfig/.git` missing → `git clone --recurse-submodules <url>`.
- On every `home-manager switch` → `git fetch` + fast-forward **`main`** + `submodule update --init --recursive`.
- **`main` = flake SSOT** for `nixos-rebuild` / `nh os switch`; agent coding work in **worktrees** (`worktrunk`) so auto-pull on main is safe.
- agenix deploy key or gh credential for private repo.

### 3. Root NixConfig dir — **locked**

`/root/NixConfig` is not a checkout. `scripts/deploy-goofeus.sh` points it at the flake
source store path of the revision being deployed (`nix flake metadata` → `nix copy` →
`ln -sfn`) and pins that source with a gcroot, so the directory is exactly what gets
built, survives `nix-collect-garbage`, and needs no git, branch or pull.

- `scripts/deploy-goofeus.sh` syncs, writes the boot entry and activates.
- `--dir-only` syncs without activating, `--dry` prints what `nh` would do, `--no-boot`
  activates without touching the boot entry.
- The directory is read-only by design. `~/.config/nvim/lazy-lock.json` is symlinked
  into it, so `:Lazy update` cannot write there.
- Nix's flake source holds tracked paths only: `git add` a new file or it is silently
  absent from the deployed tree (the script warns about untracked files).

### 4. Boot services (agent user)

- systemd or login hook: `tmux new -A -ds agents` (empty shell, no pi).
- pi started manually after attach.

### 5. Rebuilds — **locked**

- agent may run `nixos-rebuild` / `nh os switch` from `~/NixConfig` **main**.
- **Requires interactive sudo password** — no passwordless sudo for agent, ever.
- Rebuild remotely: SSH tmux pane → `cd ~/NixConfig && sudo nh -R os switch` (user types pw; `nh` refuses to run as root without `-R`).

### 6. Secrets (agenix)

- cursor-api-key, github-mcp-token, etc. — extend `secrets.nix` for agent user if not already covered.
- Session sync secrets (`PI_SYNC_*`) — only if B-layer enabled; not in NixConfig git.

### 7. Post-rebuild manual (until automated)

```bash
cd ~/NixConfig && pi-ext-deps-install
pi list   # verify exts/skills
```

---

## Deferred TODO (out of v1 scope)

- [ ] **Engram cross-host sync** — Goofeus `agent` vs GoofyDesky `goofy` local SQLite; evaluate git chunks / Engram Cloud later
- [ ] **pi-sync** — only if SSH attach insufficient for offline handoff

---

## Implementation notes (locked)

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
| Herdr + mobile relay | ❌ | 9/10 | partial | best inbox; kills tmux subagents |
| mosh + Termux | ✅ | 3/10 | ✅ | emergency fallback |
| agent-tmux-web APK | ✅ | 6/10 | wrap npm | no pi launcher |
| muxr (trymuxr) | ❌ | 9/10 | wrap npm | requires Herdr |

**Current:** no phone frontend — SSH + tmux only.

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

- `dendritic/home-modules/nixconfig-sync.nix` — auto-pull ~/NixConfig on HM switch (clone / ff main / submodules).
- `dendritic/hosts/Goofeus.nix` — `homeConfigurations.GoofeusAgent` (pi stack + tmux zellij worktrunk bash carapace nixconfig-sync), `users.users.agent` (fleet SSH keys), `home-manager.users.agent`, NixOS `age.secrets.agent-age-key` (owner=agent), empty `agents` tmux boot service.
- `dendritic/home-modules/home.nix` / `nushell.nix` / `atuin.nix` — switched to `config.home.username` (per-user) instead of host-global `username` specialArg; fixes 2-user hosts. All hosts eval (Goofeus/Desky/Envy).
- `secrets/secrets.nix` — `AgentAge` pubkey added to 7 API secrets, `agent-age-key.age` encrypted (recipients: Goofeus hostkey + GoofyDeskyRoot); rekeyed; AgentAge decrypt verified.

**Pending (on Goofeus at deploy):**

- Bootstrap from GoofyDesky: `nh os switch --flake .#Goofeus` (creates agent user first run).
- First login: `passwd agent`.
- `pi-ext-deps-install` in ~/NixConfig after first clone.
- NixOS `age.secrets.agent-age-key` path lands at `/run/agenix/agent-age-key` — already wired into agent HM `age.identityPaths`.

**Notes:** Temp agent private key under `$TMPDIR/agent-tmp/agent-agekey/` (do NOT delete until Goofeus bootstrapped; needed once to re-encrypt if recipient set grows).

---

## Sources

- [Herdr agents](https://herdr.dev/docs/agents/) — Pi hooks, tmux-nesting caveat
- [pi-interactive-subagents](vendor/mattgmak/pi-interactive-subagents/) — tmux requirement
- Local: `dendritic/hosts/Goofeus.nix`, `GoofyDesky.nix`, `pi-coding-agent.nix`, `syncthing.nix`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-09-03 | Initial plan from grill session — decisions, Nix outline |
| 2026-09-03 | **Locked** tmux stack; SSH desk attach default |
| 2026-09-03 | Grill round 2: agent user, auto-pull main, Tailscale-only, boot services, sudo policy, Engram deferred |
| 2026-09-03 | Grill round 3: fleet SSH keys, nushell/agenix HM, remote-builder bootstrap |
| 2026-09-03 | Grill round 4: agent own age key, nh os switch bootstrap |
| 2026-10-17 | Dropped phone PWA frontend — browser via SSH tmux only |
