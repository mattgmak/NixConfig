---
name: pi-setup
description: >
  Install or update pi and its vendored extensions in this NixConfig repo. Use when
  adding a new pi extension/skill/theme, bumping pi or extension versions, or debugging
  pi discovery/reload. Subcommands: `extend` (install), `update` (bump with changelog review).
---

References are relative to `~/NixConfig/dendritic` unless noted.

# Pi Setup (NixConfig)

This repo manages pi via Home Manager + `coding-agents` flake module. Extensions/skills live in-repo; Home Manager links them into `~/.pi/agent/` via `mkOutOfStoreSymlink`.

**Convention details** (layout, vendoring rules, debugging): see [REFERENCE.md](REFERENCE.md).

## Dispatch

Parse the user's intent from the slash command or message:

| Invocation | Action |
|------------|--------|
| `/pi-setup extend …` | Run **extend** (install) |
| `/pi-setup update …` | Run **update** (bump) |
| `/pi-setup` (no subcommand) | **Ask the user** which subcommand: `extend` or `update` |

Do not guess — if ambiguous, ask.

---

## `extend` — install extensions, skills, or themes

Use when adding something new to pi in this repo.

### 1. Clarify target

Ask what to install if not specified:

- **Extension** (TypeScript, `extensions/vendor/` + loader)
- **Skill** (markdown `SKILL.md`, `dendritic/skills/`)
- **Theme** (`themes/vendor/` + symlink)

### 2. Gather upstream info

For vendored items, confirm:

- Git URL (prefer upstream; fork only if patches needed)
- Desired ref (default: default branch HEAD)
- Loader name (extension only — usually matches repo short name)

List what is already installed:

```bash
ls dendritic/skills/
ls dendritic/home-modules/pi-coding-agent/extensions/
ls dendritic/home-modules/pi-coding-agent/extensions/vendor/
cat .gitmodules
```

### 3. Install per type

Follow [REFERENCE.md](REFERENCE.md) for the exact steps. Summary:

**Extension (submodule)**

```bash
# From NixConfig root
git submodule add <url> dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>

# Expose to pi discovery (loader dir)
cd dendritic/home-modules/pi-coding-agent/extensions
mkdir <name>
# package.json: { "pi": { "extensions": ["./index.ts"] } }
# index.ts: export { default } from "../vendor/<name>/index.ts";

cd vendor/<name> && npm install --omit=dev   # if package.json has deps
```

**Skill (local)** — `mkdir dendritic/skills/<name>/` + `SKILL.md` with frontmatter.

**Skill (vendored)** — submodule under `skills/vendor/` + symlink at `skills/<name>`.

**Theme** — submodule under `themes/vendor/` + `ln -sfn` each `*.json` to `themes/`.

Submodule naming in `.gitmodules`: **`owner/repo`** from the git URL, not the checkout path.

### 4. Finish

- Run `pi-npm-i` if any extension has runtime deps
- Verify with `pi list` or `pi -e …/extensions/<name>/index.ts`
- Commit `.gitmodules`, submodule pointer, loader/symlink files
- Tell user to `/reload` in pi (no HM rebuild needed for content-only changes)

---

## `update` — bump pi and/or extensions

Use when upgrading pi itself or vendored extension submodules.

### Target resolution

| User says | Targets |
|-----------|---------|
| `pi` / `pi-coding-agent` | pi only (coding-agents flake input) |
| `<extension-name>` | that extension's vendor submodule (match loader dir name or `.gitmodules` path) |
| `all` or nothing specified | **pi + every extension** under `extensions/vendor/` |

Also accept comma-separated lists (e.g. `pi, pi-lens, cursor-provider`).

Themes and skill submodules are **out of scope** unless the user explicitly names them; mention they can be updated the same way if asked.

### Step 1 — Changelog report (required)

For each target, determine **current** and **proposed** versions before changing anything.

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
VENDOR=dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
git -C "$VENDOR" rev-parse HEAD                    # current
git -C "$VENDOR" fetch origin
git -C "$VENDOR" rev-parse origin/HEAD             # proposed (or user-specified tag)
git -C "$VENDOR" log --oneline HEAD..origin/HEAD   # commit summary
# Also read CHANGELOG.md, RELEASE_NOTES.md, or GitHub releases in that repo if present
```

**Fork vendored extensions (required when submodule URL is your fork)**

Some vendor submodules point at **your fork** (`mattgmak/*`, `MattDevy/*`) because upstream needed local patches. For those, comparing pinned SHA to `origin/HEAD` only means “matches your fork” — **not** “matches upstream”.

Before the preview report, run the fork upstream check for every target whose `.gitmodules` URL is a fork. See [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions) for the registry and commands.

For each fork target, report:

- **Fork status** — pinned SHA vs `origin` (should match unless fork has unpushed work)
- **Upstream status** — pinned SHA vs upstream default branch: behind / ahead / diverged / current
- **Fork-only commits** — local patches that must be preserved on merge
- **Upstream-only commits** — what you would gain by merging upstream into the fork
- **Proposed bump** — if upstream is ahead: merge/rebase upstream into the fork first, push, then propose the new fork SHA (do **not** silently propose `origin/HEAD` when upstream has unreconciled commits)

Include a **Fork upstream** subsection in the preview when any fork targets are in scope.

Present a **single report** covering all targets:

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
| `<name>` | `<sha>` | `<sha>` | N commits | N commits | merge upstream → push fork → bump |

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
- [ ] bump submodule SHAs + `git add`
- [ ] `pi-npm-i` for extensions with changed package.json
- [ ] `home-manager switch` if pi package changed
```

**Stop here.** Ask the user: **Continue with the update?** Do not modify files until they confirm.

### Step 2 — Apply update (only after user confirms)

Respect the setup convention from [REFERENCE.md](REFERENCE.md).

**Pi**

```bash
cd ~/NixConfig
nix flake update coding-agents
# If pi-coding-agent npm deps changed, rebuild may fail on npmDepsHash —
# read the nix error, update hash in dendritic/overlays.nix, retry.
home-manager switch --flake .#<host>   # ask user for host if unknown
```

**Each extension**

For **fork vendored extensions** where upstream is ahead or diverged: reconcile in the fork first (merge upstream → push) — see [REFERENCE.md — Fork vendored extensions](REFERENCE.md#fork-vendored-extensions). Only then bump the submodule pointer.

```bash
cd dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
git checkout <proposed-ref>    # tag, branch, or commit from step 1
cd ~/NixConfig
git add dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
```

**Deps + verify**

```bash
pi-npm-i
pi list
# spot-check: pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts
```

**Commit** with a message summarizing what was bumped (e.g. `bump pi-coding-agent and pi-lens`).

Tell the user to `/reload` or restart pi. Rebuild HM only when pi package or Nix wiring changed.

### Bulk fetch (optional prep)

Before step 1 on many extensions:

```bash
~/NixConfig/githooks/submodule-refresh.sh
```

Do not run this automatically on every update — only when fetching upstream refs for a wide bump.
