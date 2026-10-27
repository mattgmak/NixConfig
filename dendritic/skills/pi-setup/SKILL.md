---
name: pi-setup
description: >
  Add or bump pi extensions, skills, and themes. Use when adding a vendored pi
  extension/skill/theme, bumping pi or extension versions, or debugging pi
  discovery/reload. Subcommands: `extend` (install), `update` (bump with changelog review),
  `blackhole` (refresh free memory-model chains).
---

References are relative to `~/NixConfig/dendritic` unless noted.

# Pi Setup (NixConfig)

Pi runs via Home Manager + `coding-agents` flake module: extensions/skills live in-repo, HM links them into `~/.pi/agent/` via `mkOutOfStoreSymlink`. The one exception is `~/.pi/agent/extensions` on x86_64-linux and aarch64-darwin, which links into the built extensions dir of the compiled binary. Layout, vendoring rules, debugging: [REFERENCE.md](REFERENCE.md).

## Compiled host (`piCompiled`)

On x86_64-linux and aarch64-darwin `pi` runs `packages.piCompiled` (`dendritic/packages/pi-bolt-compiled.nix`), not the plain binary. That package compiles 31 loaders into the executable. On linux the binary costs 562 MB and the store path costs 1.6 GB. On darwin the binary costs 461 MB and the store path costs 1.3 GB. A warm build takes 5 to 9 minutes on linux.

**The rule that decides everything.**

The compiler records the absolute path of each extension and a fingerprint of file count, byte sum and newest mtime. Compiled code runs only while the run-time files sit at that recorded path. Only the store tree holds those paths. A copy of that tree misses every key, and Pi loads the files instead. Each compiled name must resolve into the store tree, never into a copy.

| Command | Binary | Loaders |
|---------|--------|---------|
| `pi` | `packages.piCompiled` | 31 compiled names from the store tree |
| `pi-stock` | `packages.pi`, plain 1.0.4 | every loader from the repo tree, for extension development |

`pi-stock` sets `PI_CODING_AGENT_DIR=~/.pi/agent-dev`, so it keeps its own sessions and cache.

**Rebuild trigger.** Any edit to a compiled extension, its deps, or the extension list needs `nh`. Such an edit is not live after `/reload`. `pi-permission-system` and `pi-lean-ctx` stay writable, so their own log and cache files still land at run time.

**Measured on 1.0.3:** warm first prompt 678 ms compiled against 2578 ms plain.

## Dispatch

| Invocation | Action |
|------------|--------|
| `/pi-setup extend …` | Run **extend** (install) |
| `/pi-setup update …` | Run **update** (bump) |
| `/pi-setup blackhole …` | Run **blackhole** (refresh free memory-model chains) |
| `/pi-setup` (no subcommand) | Ask the user which: `extend`, `update`, or `blackhole` (never guess) |

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

- Run `pi-ext-deps-install` if any extension has runtime deps
- Verify the loader loads: `printf '' | pi -ne -e dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts --mode rpc` — loads the extension with no model turn; load errors print (`Failed to load extension …`) and exit non-zero. `pi list` is useless here — HM symlinks, not packages → “No packages installed”; a `list` anywhere but the first argv token parses as a **prompt** (real model turn, 403 on an unresolved `defaultModel`); `pi -e <path> --help` exits 0 even for a nonexistent path.
- Commit `.gitmodules`, submodule pointer, loader/symlink files
- Tell the user to `/reload` in pi — content edits are live for a repo loader; HM rebuild only when Nix wiring changed ([REFERENCE.md — Apply config changes](REFERENCE.md#apply-config-changes)). A compiled loader needs `nh` instead: see [Compiled host](#compiled-host-picompiled).

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

**pi bin**: `dendritic/packages/pi-bolt.nix` (pi-bolt, `github:opensec-git/Pi-Bolt`, release tag `bolt-v*`) holds the plain binary as `packages.pi`. `dendritic/packages/pi-bolt-compiled.nix` holds the compiled host as `packages.piCompiled`. The overlay in `dendritic/overlays.nix` installs `piCompiled` on x86_64-linux and aarch64-darwin, and `pi` on the other systems. Every `update` that includes `pi` must bump both files to the latest `bolt-v*` release: version, the two platform sha256 in `pi-bolt.nix`, and the six hashes (app, runtime, kit per platform) in `pi-bolt-compiled.nix`. A `coding-agents` flake bump alone changes neither binary.

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
- [ ] `nix flake update coding-agents` (+ possibly the Pi pin hash in `dendritic/packages/pi-bolt.nix` or `pi-bolt-compiled.nix`)
- [ ] bump submodule SHAs + `git add` (include `flake.lock` when pi bumped)
- [ ] `pi-ext-deps-install` for extensions with changed package.json
- [ ] `home-manager switch` if pi package, a compiled extension, or its deps changed
```

**Done when** — every in-scope target in one preview. **Stop here.** Ask the user: **Continue with the update?** Modify no files until they confirm.

### Step 2 — Apply update (only after user confirms)

Apply per [REFERENCE.md](REFERENCE.md) conventions.

**Pi**

```bash
cd ~/NixConfig
nix flake update coding-agents
git add flake.lock
# A Pi release bump can fail on a stale pin hash. Read the nix error.
# Update the hash in dendritic/packages/pi-bolt.nix or pi-bolt-compiled.nix, then retry.
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
pi-ext-deps-install
# per bumped loader — loads it, no model turn; load errors print + exit non-zero
printf '' | pi -ne -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts --mode rpc
```

`pi list` prints “No packages installed” here (HM symlinks, not packages); trailing `list` = prompt, not the subcommand; `-ne` does not suppress compiled-in extensions.

**Commit** with a message summarizing what was bumped (e.g. `bump pi-coding-agent`).

Tell the user to `/reload` or restart pi. Rebuild HM when the pi package, a compiled extension or its deps changed, or when Nix wiring changed.

**Done when** — every in-scope target at its proposed ref, loader check passes for every bumped extension, commit made. No target skipped.

---

## `blackhole` — refresh free memory-model chains

Replace the pi-blackhole observer, reflector, and dropper chains with fresh zero-cost models. Probe first, then rank. Never pick a model from a name alone.

### Config file

Edit the repo file only:

```
dendritic/home-modules/pi-coding-agent/extensions/pi-blackhole/pi-blackhole-config.json
```

HM links it to `~/.pi/agent/pi-blackhole/pi-blackhole-config.json`. Changing the runtime copy does nothing after the next switch.

### 1. List free candidates

Use the live catalog, not the current config.

- **openrouter** — `curl -s https://openrouter.ai/api/v1/models`. Keep ids ending `:free` with zero `pricing`, `tools` in `supported_parameters`, and text output.
- **opencode-go** — `~/.pi/agent/models-store.json`, key `."opencode-go".models`. Keep entries with zero `cost`.
- **commandcode** — `~/.pi/agent/commandcode-models.json`, key `.models`. Keep free ids.

Drop any id that bills. Check the price, not the `:free` suffix. `inclusionai/ling-3.1-flash` dropped its free tier and still bills.

### 2. Probe

```bash
node dendritic/skills/pi-setup/scripts/blackhole-probe.mjs \
  --config dendritic/home-modules/pi-coding-agent/extensions/pi-blackhole/pi-blackhole-config.json \
  --json /tmp/agent-tmp/blackhole/probe.json
```

The script sends one forced tool call per model with `max_tokens` 512. It resolves keys from env, then agenix, then `~/.pi/agent/auth.json`. Stdout stays TSV. Provenance and the summary go to stderr.

Drop these results at once:

- `404` — model gone upstream
- `403` — geo block or agentic-harness only
- `429` each time — quota exhausted
- `toolCall=no` — cannot drive a worker

The script sets `max_tokens` 512 on purpose. A 64-token probe truncates reasoning models and fakes a failure.

### 3. Rank per stage

Order the surviving models by measured latency. Then fit the stage:

- **observer** — fastest valid tool call. Chunk input is `observerChunkMaxTokens`.
- **reflector** — strongest reasoning first. Input cap is `reflectorInputMaxTokens`, so context window must cover it.
- **dropper** — fastest model with `thinking` off. Retention decisions are cheap.

Put each provider in the chain. One provider outage must not empty a stage. Keep 7 entries per stage.

### 4. Rewrite the chains

Each entry needs `provider`, `id`, `thinking`, `cooldownHours`, and `contextWindow`. Take `contextWindow` from the model store, not from memory. Set the base `model` to the newest verified free model.

Unknown keys and `_comment` fields are dropped without error. A typo in `provider` or `id` fails at run time, not at load.

### 5. Verify

Run all four checks. Fix, then repeat.

```bash
# 1. parse
jq . <config> > /dev/null
# 2. ids exist in the provider store (openrouter, opencode-go, commandcode)
# 3. openrouter ids price at zero in /api/v1/models
# 4. removed ids absent: rg 'apodex|ling-3.1-flash|nemotron-3-super' <config>
```

### 6. Report

Show a table of provider, model, latency, and tool call. List every removed id with its reason. Note the config path and the `nh` switch reminder. Commit only when the user asks.

**Done when** — every chain holds only probe-verified zero-cost ids, all four checks pass, and the report shows the rank and the removals. No id picked by name.
