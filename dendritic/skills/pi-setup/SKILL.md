---
name: pi-setup
description: >
  Add or bump pi extensions, skills, and themes. Use when adding a vendored pi
  extension/skill/theme, bumping pi or extension versions, or debugging pi
  discovery/reload. Subcommands: `extend` (install), `update` (bump with changelog review).
---

References are relative to `~/NixConfig/dendritic` unless noted.

# Pi Setup (NixConfig)

Pi runs via Home Manager + `coding-agents` flake module: extensions/skills live in-repo, HM links them into `~/.pi/agent/` via `mkOutOfStoreSymlink`. Layout, vendoring rules, debugging: [REFERENCE.md](REFERENCE.md).

## Dispatch

| Invocation | Action |
|------------|--------|
| `/pi-setup extend …` | Run **extend** (install) |
| `/pi-setup update …` | Run **update** (bump) |
| `/pi-setup` (no subcommand) | Ask the user which: `extend` or `update` (never guess) |

Discovery/reload failures: [REFERENCE.md — Debugging](REFERENCE.md#debugging).

---

## `extend` — install extensions, skills, or themes

### 1. Clarify target

Fix the target type before proceeding — **extension** (TypeScript, `vendor/` submodule + loader dir in `extensions/`), **skill** (markdown `SKILL.md`, `dendritic/skills/`), or **theme** (`vendor/` submodule + symlink). Ask if unspecified.

### 2. Gather upstream info

For vendored items, confirm:

- Git URL (prefer upstream; fork only if patches needed)
- Desired ref (default: default branch HEAD)
- Loader name (extension only — usually matches repo short name)

List what is already installed:

```bash
ls dendritic/skills/
ls dendritic/home-modules/pi-coding-agent/extensions/
ls vendor/
cat .gitmodules
```

**Done when** — target type, git URL, ref, and loader name known; current installs listed.

### 3. Install per type

Exact steps per type: [REFERENCE.md](REFERENCE.md). Summary:

**Extension (submodule)**

```bash
# From NixConfig root
git submodule add <url> vendor/<owner>/<name>

# Expose to pi discovery (loader dir)
cd dendritic/home-modules/pi-coding-agent/extensions
mkdir <name>
# package.json: { "pi": { "extensions": ["./index.ts"] } }
# index.ts: export { default } from "../vendor/<owner>/<name>/index.ts";  # depth fixed: ../vendor lands on extensions/vendor compat symlink → repo root vendor/

cd ~/NixConfig/vendor/<owner>/<name> && npm install --omit=dev   # if package.json has deps
```

**Skill (local)** — `mkdir dendritic/skills/<name>/` + `SKILL.md` with frontmatter.

**Skill (vendored)** — submodule under `vendor/<owner>/<repo>` + symlink at `skills/<name>`.

**Theme** — submodule under `vendor/<owner>/<repo>` + `ln -sfn` each `*.json` to `themes/`.

Submodule naming in `.gitmodules`: **`owner/repo`** from the git URL, not the checkout path.

**Fork when patching** — upstream needs durable local changes (e.g. `pi-interactive-subagents` curated pass-through): fork to `mattgmak/<repo>`, point submodule URL at fork, register upstream in [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions). Patch in `vendor/mattgmak/<repo>/`, push fork, bump submodule pointer in NixConfig.

**Done when** — item present at its repo path, deps installed, exposed (loader dir, symlink, or `SKILL.md`).

### 4. Finish

- Run `pi-npm-i` if any extension has runtime deps
- Verify the loader: `pi -ne -e dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts list` per loader (`-ne` disables discovery, explicit `-e` still loads → only this loader runs). `pi list` is useless here — HM symlinks, not packages → “No packages installed”. `pi -e <path> --help` never loads extensions, and exit 0 does not prove a load.
- Commit `.gitmodules`, submodule pointer, loader/symlink files
- Tell user to `/reload` in pi — content edits are live; HM rebuild only when Nix wiring changed ([REFERENCE.md — Apply config changes](REFERENCE.md#apply-config-changes))

**Done when** — loader check passes for the new item, commit made, user told to `/reload`.

---

## `update` — bump pi and/or extensions

Upgrade pi or vendored extension submodules.

### Target resolution

| User says | Targets |
|-----------|---------|
| `pi` / `pi-coding-agent` | pi only (coding-agents flake input) |
| `<extension-name>` | that extension's vendor submodule (match loader dir name or `.gitmodules` path) |
| `all` or nothing specified | **pi + every extension** under `vendor/` |

Also accept comma-separated lists (e.g. `pi, cursor-provider`).

**Fork upstream sync (default, every fork in scope)**: merge upstream → push fork → bump submodule. Applies even when user names targets explicitly. Opt out only when user explicitly says skip fork sync. Registry + commands: [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions).

**pi bin**: `dendritic/packages/pi-bolt.nix` (pi-bolt, `github:opensec-git/Pi-Bolt`, release tag `bolt-v*`) is the default pi binary — overlays redirect the `pi-coding-agent` package to it. Every `update` that includes `pi` must also bump `pi-bolt.nix` (version + both platform sha256) to the latest `bolt-v*` release; the `coding-agents` flake bump alone does not change the installed pi.

Themes and skill submodules **out of scope** unless user names them explicitly; mention they can update same way if asked.

### Fleet scan (prep, many extensions)

Wide bump → scan once (`submodule-refresh.sh` fetches refs for every vendor submodule), then the per-target `rev-parse`/`log` in step 1 run offline against fresh refs. Write the preview from that scan.

```bash
~/NixConfig/githooks/submodule-refresh.sh
```

Skip the scan on a narrow update — one or two targets just `fetch origin`/`upstream` directly.

### Step 1 — Changelog report (required)

Per target: find **current** + **proposed** version. Before touching anything.

**Pi (`coding-agents` flake input)**

```bash
# Current locked rev
nix flake metadata . --json | jq '.locks.nodes["coding-agents"].locked'

# Latest on default branch
nix flake metadata github:kissgyorgy/coding-agents --json | jq '.lastModified, .revision'

# Changelog / release notes
# Fetch CHANGELOG.md, GitHub releases, or git log between revs from kissgyorgy/coding-agents
# Focus on packages/pi-coding-agent changes
```

**Extension submodule**

```bash
VENDOR=vendor/<owner>/<name>
git -C "$VENDOR" rev-parse HEAD                    # current
git -C "$VENDOR" fetch origin
git -C "$VENDOR" rev-parse origin/HEAD             # proposed (or user-specified tag)
git -C "$VENDOR" log --oneline HEAD..origin/HEAD   # commit summary
# Also read CHANGELOG.md, RELEASE_NOTES.md, or GitHub releases in that repo if present
```

**Fork vendored extensions (required when submodule URL is your fork)**

Vendor submodules pointing at **your fork** (`mattgmak/*`, `MattDevy/*`) — upstream needed local patches. There, pinned SHA vs `origin/HEAD` = “matches your fork”, **NOT** “matches upstream”.

Before the preview report, run the fork upstream check for **every** target whose `.gitmodules` URL is a fork. Registry + commands: [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions).

For each fork target, report:

- **Fork status** — pinned SHA vs `origin` (should match unless fork has unpushed work)
- **Upstream status** — pinned SHA vs upstream default branch: behind / ahead / diverged / current
- **Fork-only commits** — local patches that must be preserved on merge
- **Upstream-only commits** — what you would gain by merging upstream into the fork
- **Proposed bump** — if upstream is ahead: merge upstream into the fork first (merge, not rebase), push, then propose the new fork SHA (do **not** silently propose `origin/HEAD` when upstream has unreconciled commits)

Include **Fork upstream** subsection in preview when any fork targets in scope.

**Single report**, all targets:

```markdown
## Pi setup update preview

### Versions
| Target | Current | Proposed | Delta |
|--------|---------|----------|-------|
| pi (coding-agents) | `<rev>` | `<rev>` | … |
| extension `<name>` | `<sha>` | `<sha>` | … commits |

### Fork upstream (when any fork vendored extensions are in scope)
| Extension | Fork | Upstream | Fork-only | Upstream-only | Action |
|-----------|------|----------|-----------|---------------|--------|
| `<name>` | `<sha>` | `<sha>` | N commits | N commits | fork upstream sync |

### Summary
[1–3 sentences: what this update does overall]

### New features
- …

### Breaking changes / migration
- …

### Other effects
- dependency changes, npm lockfile changes, overlay hash updates, etc.

### Post-update steps (if continuing)
- [ ] `nix flake update coding-agents` (+ possibly `dendritic/overlays.nix` npmDepsHash)
- [ ] bump submodule SHAs + `git add` (include `flake.lock` when pi bumped)
- [ ] `pi-npm-i` for extensions with changed package.json
- [ ] `home-manager switch` if pi package changed
```

**Done when** — every in-scope target in one preview. **Stop here.** Ask the user: **Continue with the update?** Modify no files until they confirm.

### Step 2 — Apply update (only after user confirms)

Apply per [REFERENCE.md](REFERENCE.md) conventions.

**Pi**

```bash
cd ~/NixConfig
nix flake update coding-agents
git add flake.lock
# If pi-coding-agent npm deps changed, rebuild may fail on npmDepsHash —
# read the nix error, update hash in dendritic/overlays.nix, retry.
home-manager switch --flake .#<host>   # hand off to user; ask for host if unknown
```

**Each extension**

Fork targets where upstream is ahead or diverged: reconcile the fork first, then bump the submodule pointer to the fork tip. Registry (fork URL, upstream URL, branch): [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions).

```bash
VENDOR=vendor/<owner>/<name>
git -C "$VENDOR" remote get-url upstream >/dev/null 2>&1 || \
  git -C "$VENDOR" remote add upstream <upstream-url>
git -C "$VENDOR" fetch upstream
git -C "$VENDOR" checkout main          # or master (pi-lens)
git -C "$VENDOR" merge upstream/main    # merge, not rebase; resolve conflicts, keep fork-only patches
git -C "$VENDOR" push origin HEAD

cd vendor/<owner>/<name>
git checkout <proposed-ref>    # tag, branch, or new fork SHA from step 1
cd ~/NixConfig
git add vendor/<owner>/<name>
# flake.lock too when pi itself was bumped
```

**Deps + verify**

```bash
pi-npm-i
# per bumped loader — `pi list` prints “No packages installed” here (HM symlinks, not packages)
pi -ne -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts list
```

**Commit** with a message summarizing what was bumped (e.g. `bump pi-coding-agent`).

Tell the user to `/reload` or restart pi. Rebuild HM only when pi package or Nix wiring changed.

**Done when** — every in-scope target at its proposed ref, loader check passes for every bumped extension, commit made; no target skipped.
