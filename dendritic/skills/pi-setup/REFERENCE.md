# Pi Setup — Reference

Companion to [SKILL.md](SKILL.md). Layout, conventions, and debugging for pi in this NixConfig repo.

## Layout

```
NixConfig/
├── vendor/                          # ALL git submodules, grouped <Owner>/<repo>
│   ├── <owner>/<repo>/              # e.g. vendor/mattgmak/lean-ctx
│   └── …                            # extensions, themes, skills, zen, tools
└── dendritic/
    ├── skills/                      # global pi skills (SKILL.md dirs)
    │   ├── <skill-name>/            # local skill or symlink → ../../vendor/.../skills/...
    │   └── pi-setup/                # repo-owned skill
    └── home-modules/pi-coding-agent/
        ├── pi-coding-agent.nix      # wiring module
        ├── models.json              # custom providers/models
        ├── mcp.json                 # Pi global MCP override (~/.pi/agent/mcp.json)
        ├── extensions/              # pi TypeScript extensions
        │   └── <loader>/            # thin loader dir (package.json + index.ts → ../vendor/...)
        ├── prompts/                 # prompt templates (.md)
        └── themes/                  # symlinks into ../../../../vendor/<owner>/<repo>
```

Deployed at runtime:

| Repo path | `~/.pi/agent/` target | Mechanism |
|-----------|----------------------|-----------|
| `dendritic/skills/` | `skills/` | `coding-agents.skillsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/extensions/` | `extensions/` | compiled systems: built store dir (`piExtensionsDir`). elsewhere `coding-agents.pi-coding-agent.extensionsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/prompts/` | `prompts/` | `coding-agents.pi-coding-agent.promptsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/themes/` | `themes/` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/models.json` | `models.json` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/mcp.json` | `mcp.json` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/lean-ctx/config.toml` | `~/.config/lean-ctx/config.toml` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/AGENTS.md` | `AGENTS.md` | `coding-agents.agentsMdPath` → `mkOutOfStoreSymlink` |

`pi-coding-agent.nix` also imports `inputs.coding-agents.homeManagerModules.default`, enables `pi-coding-agent`, and adds `node-bin`.

User settings (`~/.pi/agent/settings.json`) are **not** managed by Nix.

Pi itself is pinned via the `coding-agents` flake input (`flake.nix` → `github:kissgyorgy/coding-agents`). `dendritic/overlays.nix` overrides `pkgs.pi-coding-agent` with `dendritic/packages/pi-bolt.nix` — the native Pi-Bolt binary, which ships `bin/pi` for the swap — so the node build is not installed. On x86_64-linux and aarch64-darwin the overlay installs `dendritic/packages/pi-bolt-compiled.nix` instead, the same binary with 31 extensions compiled in (see [Compiled host](#compiled-host-picompiled)). Bump = `dendritic/packages/pi-bolt.nix` (version + per-platform hash) plus `dendritic/packages/pi-bolt-compiled.nix` (version + six hashes). Linux hosts need `programs.nix-ld.enable`: the linux asset is a dynamically linked ELF hardcoding `/lib64/ld-linux-x86-64.so.2`, which NixOS otherwise only provides as a stub.

### Loader, theme, and skill examples

**Extension submodule** — vendored under `vendor/<owner>/<repo>/`, exposed via loader dir `extensions/<name>/`:

```
vendor/fitchmultz/pi-cursor-sdk/
extensions/pi-cursor-sdk/index.ts     → ../vendor/fitchmultz/pi-cursor-sdk/dist/index.js (built by pi-ext-deps-install)
extensions/pi-nvim/index.ts          → ../vendor/carderne/pi-nvim/extension.ts
```

**Loader package** — thin dir with `package.json` + `./index.ts` re-export:

```
extensions/pi-simplify/index.ts     → ../vendor/MattDevy/pi-extensions/...
extensions/rpiv-todo/index.ts       → ../vendor/juicesharp/rpiv-mono/...
```

Use `./index.ts` in `pi.extensions` so pi shows `<name>/index.ts`, not nested vendor paths.

**Loader path depth is fixed at one level up (`../vendor/...`).** Pi resolves loader
imports relative to the **live path** `~/.pi/agent/extensions/<name>/` (textual, no
symlink-following), so repo-relative depths break at runtime. `../vendor` lands on the
`extensions/vendor` **compat symlink** → repo root `vendor/`, which resolves in the repo tree
and through the live agent dir. On the compiled systems that dir ends in the built store tree.
Its `vendor` entry links to the repo root `vendor/` as before. Things directly inside
`extensions/` (smoke test, `pi-agent-sesh`) use `vendor/...` (0 ups). Never use absolute
paths or repo-relative depths in loaders.

**Theme submodules** — vendored under `vendor/<owner>/<repo>/`, exposed via symlinks at `themes/*.json`:

```
vendor/dracula/pi-coding-agent/dracula.json
themes/dracula.json     -> ../../../../vendor/dracula/pi-coding-agent/dracula.json
themes/ansi-dark.json   -> ../../../../vendor/leblancfg/pi-ansi-themes/themes/ansi-dark.json
```

**Skill (local)** — markdown under `dendritic/skills/<name>/SKILL.md`.

**Skill (vendored)** — submodule + top-level symlink:

```
vendor/mattpocock/skills/
skills/tdd -> ../../vendor/mattpocock/skills/skills/engineering/tdd
```

Vendored extensions are usually pi packages (`keywords: ["pi-package"]`). Pi discovers subdirs via `package.json` → `pi.extensions` array, or `index.ts`/`index.js`. Skills = `SKILL.md` in a directory.

Loader dirs in `extensions/` are what pi loads; the submodule checkouts live at the repo-root `vendor/`.

## Compiled host (`piCompiled`)

`packages.piCompiled` (`dendritic/packages/pi-bolt-compiled.nix`) runs on x86_64-linux and aarch64-darwin. `dendritic/overlays.nix` points `pkgs.pi-coding-agent` at it on both systems, and at `packages.pi` (plain 1.0.4) on the others.

The package compiles 31 loaders into the executable. On linux the binary costs 562 MB and the store path costs 1.6 GB. On darwin the binary costs 461 MB and the store path costs 1.3 GB. A warm build takes 5 to 9 minutes on linux.

### Package shape

Three release assets per platform, all from `bolt-v<version>`:

| Asset | Content |
|-------|---------|
| `pi-bolt-<variant>.tar.xz` | app tree, with the hashes from `pi-bolt.nix` |
| `pi-bolt-runtime-<variant>.tar.gz` | the bun runtime that the compiler drives |
| `pi-bolt-kit-<variant>.tar.gz` | compile kit: patched Pi sources plus `node_modules` |

`--kit` together with `--runtime` is the offline pair. Without either one the compile fetches `SHA256SUMS` and `SHA256SUMS.sig` from the release.

The build stages the loaders and a real `vendor` tree. It then runs the compile with `HOME=$out/share/pibolt-home`, so the recorded root stays in the store path. Every staged file takes `@1` as its mtime, so both sides of the fingerprint read `1000`. The step calls the nixpkgs `find` and the nixpkgs `touch`: BSD `touch` takes no `-d @1`.

`dontFixup`, `dontStrip` and `dontPatchELF` stay set. The AOT image appends page-aligned sections and a trailer, and the runtime re-opens the executable to verify that trailer. A strip, a signature or an rpath rewrite corrupts it. On Linux `patchelf --set-interpreter` only grows the file, so the build sets the interpreter and passes `LD_LIBRARY_PATH` for the compile itself.

The darwin app splits in two: a 37 KB `pi` launcher execs the real app `pi-bin` beside it. The build swaps them, as `pi-bolt.nix` does. The real AOT image becomes `pi`. The launcher stays as `pi-launcher`. `pi-bin` becomes a symlink to `pi`. Linux ships one self-contained `pi`, so the swap is darwin-only.

`PI_PACKAGE_DIR` overrides the directory of the executable, so the wrapper pins it to `$out/libexec/pi`. `PIBOLT_NPM=1` stops `pi update` from curl-installing over the store path.

### Fingerprint internals

`extensionFingerprint` (`core/extensions/compiled.js`) reads one of three scopes. The generator picks the scope from where it found the loader:

| Scope | Fingerprint |
|-------|-------------|
| `file` | `file:<size>:<mtimeMs>` of the entry |
| `package` | `package:<manifest.version>:<size>:<mtimeMs>` of the entry |
| `folder` | `folder:<fileCount>:<byteSum>:<newest mtimeMs>`, skips `node_modules` and `.git`, stops at 2000 files |

The map key is the real path of the entry. The lookup tries the resolved extension path first, then `realpathSync(path)`. A key miss returns `undefined` with no message, and Pi loads the files as in any other build. A key hit with a different fingerprint returns `changed`, and Pi prints this warning:

```
changed since it was compiled in, so it was loaded from its files: run `pi-bolt compile` to compile it in again
```

A copy of the store tree misses every key, because the map holds store paths only. The store tree also holds no `node_modules`, so a copy of it fails the two rpiv loaders.

### Writable mirror

Two loaders write beside their own code, so a symlink into the store fails with `EROFS`:

| Loader | Write | Cost of a missing write |
|--------|-------|------------------------|
| `pi-permission-system` | `logs/` on the first audit line | no audit trail |
| `pi-lean-ctx` | `mcp-schema-cache.json` | 3.3 s on every start. A warm cache costs about 4 ms |

`writableExtensions` in `pi-coding-agent.nix` names them. `writableMirror` builds a real directory for each name, with one symlink per leaf file. A compiled name takes its leaves from the store tree, else from the repo. `builtins.readDir` lists the files at eval time, so the build makes links only. A new file in a writable loader needs a rebuild.

### lndir

`home.file.".pi/agent/extensions"` sets `recursive = true`. Home Manager builds `home-manager-files` with `lndir -silent`, so the generation holds real directories with one symlink per leaf. Activation links those leaves into `$HOME` and makes the parent directories real. `~/.pi/agent/extensions/<name>/` is now a real directory, and `<name>/index.ts` resolves into the store tree.

The compile leaves some loaders out. Each of those links to the repo directory as a whole, so a new file in it appears at once. A compiled name links into the store, so a new file there does not appear.

### Offline deps

The compile needs no network. Each staged repo that imports npm packages gets its own `node_modules`:

| Repo | Mechanism |
|------|-----------|
| `mattgmak/agent-sesh/extensions/pi-agent-sesh`, `nicobailon/pi-mcp-adapter`, `nicobailon/pi-web-access`, `omaclaren/pi-markdown-preview` | `npmDepRepos`: `pkgs.importNpmLock.buildNodeModules` per repo |
| `gotgenes/pi-packages` | `fetchPnpmDeps` for the workspace, `fetcherVersion = 4`, plus `pnpmConfigHook` |
| `fitchmultz/pi-cursor-sdk` | lockfile install, then `bun build` as one extra kit entry |
| `fitchmultz/pi-agent-browser-native` | dev lockfile install, then `node scripts/build.mjs` |
| `ctotheameron/agent-ste` | gleam build, plus four hex tarballs in `$HOME/.cache/gleam/hex/hexpm/packages`, named by manifest checksum |
| `Gentleman-Programming/engram` | manifest cut to `dependencies`, then `npm install --omit=dev --offline`. Bare imports reach the staged `vendor/node_modules` |
| `mattgmak/lean-ctx/packages/pi-lean-ctx` | dev install trimmed to `@modelcontextprotocol/sdk` and `esbuild`, then `npm run build:vendor` |

`npmNodeModules` takes `dropPackages` (a name test on lock entries) and `dropOverrides` (drop the manifest `overrides`). The lean-ctx install needs both. An override cannot name a store file, and the bundled shrinkwrap records seven `@earendil-works` tarballs with no integrity. `prodLock` drops the dev entries for the same reason.

A lockfile change makes `fetchPnpmDeps` stop and print the new `hash`.

### Patches

No patch remains. 1.0.5 compile maps `@sinclair/typebox` and the other Pi module names to the kit, so the `pi-interactive-subagents` patch went out. The rpiv patches went out at 1.0.3, which compiles top-level await. `vendor/juicesharp/rpiv-mono` stays on upstream.

### Extension set decisions

| Decision | Reason |
|----------|--------|
| `pi-lean-ctx` compiled in, with a writable dir | its factory wants a schema cache beside its config |
| `pi-clinepass-provider` removed | no loader or `.gitmodules` entry remains, so the set holds no cline provider |
| `mcp-nixos` loader removed, `nixos` MCP server added | the generated store path from nixpkgs `mcp-nixos` pins the server. `mcp.json` is the human-edited source |

### Failure signatures

| Symptom | Cause |
|---------|-------|
| `EROFS` on a cache or log write | the loader is a symlink into the store, so add its name to `writableExtensions` |
| a loader reports import time under `PI_TIMING`, with no warning | the key missed: the run-time path differs from the recorded one |
| `changed since it was compiled in, so it was loaded from its files` in the output | same path, different content or mtime. The store copy changed after the compile |
| every key rejected after a copy of the store tree | the map holds absolute store paths, and a copy has new paths |
| no `builtin:` entry in the `PI_TIMING` list | the loader is not in `extensions` in `pi-bolt-compiled.nix`, so it stays a repo symlink |

## Extensions vs skills

| | Extensions | Skills |
|---|-----------|--------|
| Format | TypeScript module, default-export factory | `SKILL.md` markdown instructions |
| Runs as | Code in pi process (tools, events, commands) | Prompt context for model |
| Location here | `home-modules/pi-coding-agent/extensions/` | `dendritic/skills/` |
| Needs `npm install` | Often yes (runtime deps) | No |
| Hot reload | `/reload` works for auto-discovered paths | `/reload` |

## Pi extension file shape

Minimal extension:

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("loaded", "info");
  });
}
```

Package with deps — add `package.json`:

```json
{
  "type": "module",
  "pi": { "extensions": ["./index.ts"] },
  "peerDependencies": {
    "@mariozechner/pi-coding-agent": "*",
    "@mariozechner/pi-ai": "*"
  },
  "dependencies": { "some-lib": "^1.0.0" }
}
```

Discovery rules in `extensions/` (one level):

1. `*.ts` / `*.js` at top level → load directly
2. Subdir with `package.json` + `pi.extensions` → load declared entrypoints
3. Subdir with `index.ts` / `index.js` → load index
4. No deeper recursion — complex packages must declare paths in `pi.extensions`

Bundled pi imports: `@mariozechner/pi-coding-agent`, `@mariozechner/pi-ai`, `@mariozechner/pi-tui`, `@mariozechner/pi-agent-core`, `typebox`.

## Git submodule vendoring

We vendor third-party pi resources as git submodules. Nix flake has `self.submodules = true`.

### Submodule naming

Name each submodule in `.gitmodules` as **`owner/repo`** parsed from the git URL (without `.git`), not the checkout path.

| URL | Submodule name | Path (may differ) |
|-----|----------------|-------------------|
| `https://github.com/dracula/pi-coding-agent.git` | `dracula/pi-coding-agent` | `vendor/dracula/pi-coding-agent` |
| `https://github.com/mattgmak/zen-wireframe-2.0` | `mattgmak/zen-wireframe-2.0` | `vendor/mattgmak/zen-wireframe-2` |
| `https://github.com/nicobailon/pi-web-access.git` | `nicobailon/pi-web-access` | `vendor/nicobailon/pi-web-access` |

When adding:

```bash
git submodule add <url> <path>
# then rename [submodule "<path>"] → [submodule "<owner>/<repo>"] in .gitmodules if git used the path
```

Prefer `.git/modules/<owner>/<repo>` for the internal git dir.

### Clone repo with submodules

```bash
git clone --recurse-submodules <NixConfig-url>
# or after clone:
git submodule update --init --recursive
```

Git config in `dendritic/home-modules/git.nix`:

- `submodule.recurse = true` — checkout/pull update submodules to recorded SHAs
- `fetch.recurseSubmodules = on-demand`
- `clone.recurseSubmodules = true`

For a full upstream fetch across all vendor submodules:

```bash
~/NixConfig/githooks/submodule-refresh.sh
```

Do **not** re-add `post-checkout`/`post-merge` hooks that run `git submodule foreach fetch`.

### Fork vendored extensions

Upstream needs local patches → fork upstream, point the submodule at your fork, push fixes there, bump the submodule SHA in NixConfig when ready.

Extension submodules whose `.gitmodules` URL is **your fork** must be checked against **upstream**, not just `origin`. During `pi-setup update`, fetch upstream and compare **every fork in scope** before proposing a bump.

#### Registry (extension forks)

| Loader / vendor dir | Submodule URL (fork) | Upstream | Upstream branch |
|---------------------|----------------------|----------|-----------------|
| `pi-cursor-sdk` (`vendor/fitchmultz/pi-cursor-sdk`) | *(direct upstream)* | `https://github.com/fitchmultz/pi-cursor-sdk.git` | default — active loader `extensions/pi-cursor-sdk/`; provider `cursor` |
| `lean-ctx` (`vendor/mattgmak/lean-ctx`) | `mattgmak/lean-ctx` | `https://github.com/yvgude/lean-ctx.git` | `main` |
| `pi-interactive-subagents` (`vendor/mattgmak/pi-interactive-subagents`) | `mattgmak/pi-interactive-subagents` | `https://github.com/amosblomqvist/pi-interactive-subagents.git` | `main` |
| `pi-nvim-bridge` (`vendor/mattgmak/pi-nvim-bridge`) | `mattgmak/pi-nvim-bridge` | `https://github.com/dabstractor/pi-nvim-bridge.git` | `main` |
| `pi-simplify` (`vendor/MattDevy/pi-extensions`) | `MattDevy/pi-extensions` | *(your repo — no separate upstream)* | `main` |

Add new rows here when vendoring through a fork.

#### Detect fork submodules

```bash
# From NixConfig root — extension vendor paths whose URL is your GitHub user
rg 'url = https://github.com/(mattgmak|MattDevy)/' .gitmodules
```

#### Upstream comparison (per fork)

```bash
VENDOR=vendor/<owner>/<name>
UPSTREAM_URL=https://github.com/<owner>/<repo>.git
UPSTREAM_BRANCH=main   # pi-lens uses master

# Ensure upstream remote exists
git -C "$VENDOR" remote get-url upstream >/dev/null 2>&1 || \
  git -C "$VENDOR" remote add upstream "$UPSTREAM_URL"

git -C "$VENDOR" fetch origin
git -C "$VENDOR" fetch upstream

echo "pinned:  $(git -C "$VENDOR" rev-parse --short HEAD)"
echo "fork:     $(git -C "$VENDOR" rev-parse --short origin/$UPSTREAM_BRANCH 2>/dev/null || git -C "$VENDOR" rev-parse --short origin/HEAD)"
echo "upstream: $(git -C "$VENDOR" rev-parse --short upstream/$UPSTREAM_BRANCH)"

# behind\t ahead (upstream-only \t fork-only)
git -C "$VENDOR" rev-list --left-right --count HEAD...upstream/$UPSTREAM_BRANCH

echo "=== upstream-only (first 10) ==="
git -C "$VENDOR" log --oneline HEAD..upstream/$UPSTREAM_BRANCH | head -10

echo "=== fork-only (first 10) ==="
git -C "$VENDOR" log --oneline upstream/$UPSTREAM_BRANCH..HEAD | head -10
```

#### Interpret results

| Upstream-only | Fork-only | Meaning | Update action |
|---------------|-----------|---------|---------------|
| 0 | 0 | Fork matches upstream | Safe to bump to fork tip if desired |
| N | 0 | Fork is behind upstream | Merge/rebase upstream into fork, push, then bump submodule |
| 0 | N | Fork is ahead (patches only) | Bump to fork tip; consider upstreaming patches |
| N | M | Diverged | Merge upstream into fork, resolve conflicts, push, then bump |

**Do not** mark a fork extension “up to date” in an update preview based on `origin/HEAD` alone when upstream has unreconciled commits.

#### Reconcile before bump (when upstream is ahead or diverged)

Merge, **not** rebase — the submodule pointer records a SHA, and rebasing rewrites the fork-only patch trail. Same commands as SKILL.md `update` step 2:

```bash
cd vendor/<owner>/<name>
git checkout main   # or master for pi-lens
git merge upstream/<branch>
# resolve conflicts; preserve fork-only fixes
npm install --omit=dev   # if package.json changed
git push origin HEAD

cd ~/NixConfig
git add vendor/<owner>/<name>
```

Then run `pi-ext-deps-install` from the repo root if deps changed.

## Vendored skills (`mattpocock/skills`)

Submodule at `vendor/mattpocock/skills`. Expose skills via symlinks at `dendritic/skills/<name>` → `../../vendor/mattpocock/skills/skills/{engineering,productivity}/<name>`.

Run **`/setup-matt-pocock-skills` once per target repo** before engineering skills that need issue tracker / triage labels / `docs/agents/` layout.

## Add a local extension (no upstream repo)

```bash
mkdir -p dendritic/home-modules/pi-coding-agent/extensions/my-ext
# write index.ts + optional package.json
cd dendritic/home-modules/pi-coding-agent/extensions/my-ext
npm install --omit=dev   # if deps needed
```

Commit directly in NixConfig (not submodule).

## Tool allowlist

`extensions/tool-allowlist/index.ts` caps the tools each pi session declares. The cap
is a DENYLIST. `BLOCKED_TOOLS` and `BLOCKED_PATTERNS` hold every name the setup hides.
A registered tool that matches no entry stays active.

`REVIEWED_TOOLS` records the tools the setup keeps active on purpose. It never filters.

An entry with `*`, `?`, or `[` works as a glob. MCP direct names change with the server
prefix and the metadata cache, so they need patterns such as `Linear_*` and
`github-readonly_*`.

### Change the list

1. Decide the tool. Add it to `BLOCKED_TOOLS` to hide it, or to `REVIEWED_TOOLS` to keep it.
2. Run `sh dendritic/home-modules/pi-coding-agent/scripts/tool-audit.sh`. It prints
   every registered tool that carries no decision.
3. Repeat until the script exits zero.

The audit script fails the compiled build on an unknown name. `pi-bolt-compiled.nix`
runs it in the build.

At session start the extension prints one `console.debug` line per undecided tool.
Nothing hides by silence.

**Done when** — the audit script exits zero, and every new tool carries a decision.

### Two pairings

- Denying `read` or `bash` also denies the pi-cursor-sdk replay wrappers. They share those names.
- agent-ste lints only `write`, `edit`, `say`, and `bash`. A write through `ctx_patch` skips the hard-fault gate.

## Install extension deps (`pi-ext-deps-install`)

Home Manager installs `pi-ext-deps-install`. It walks top-level `extensions/*` loaders and `vendor/<owner>/*` submodules, running `npm i --omit=dev` where `package.json` has deps (skipping themes/skills/zen/tools repos and the special-case installers for `lean-ctx`, `pi-packages`, `fgladisch/pi-extensions`, `engram`, `pi-cursor-sdk`).

`pi-cursor-sdk` (`vendor/fitchmultz/pi-cursor-sdk`) runs `npm ci --ignore-scripts`, then `node scripts/build.mjs`, then `npm prune --omit=dev --ignore-scripts` (skips `prepare`, which can mutate `package-lock.json`). Restores tracked submodule files after install so vendor discard stays clean. Loader needs built `dist/index.js`; `pi-ext-deps-install` fails if missing.

`pi-agent-browser-native` (`vendor/fitchmultz/pi-agent-browser-native`) uses the same build pattern. Loader needs `dist/extensions/agent-browser/index.js`.

**pi-bolt (compiled bun host) can't resolve extension deps at runtime.** Its extension loader runs jiti in embedded mode (`isBunBinary` → `{ virtualModules, tryNative: false }`), which fails on bare specifiers reached *inside* a package's own dependency tree (`Cannot find package 'X'`), while plain node/bun resolve the same tree fine. Workaround pattern: `pi-ext-deps-install` bundles the extension for that host and the loader picks the bundle when `process.versions.bun` is set — see `install_pi_cursor_sdk` (`bun build … --external '@earendil-works/*' --external 'typebox*' --external '*.node'`) and `extensions/pi-cursor-sdk/index.ts`. Put generated bundles in the loader dir (**not** the submodule): `discard_vendor_changes` runs `git clean -fd` in every vendor submodule at the end of `pi-ext-deps-install`.

Run after submodule add/update when an extension has runtime deps.

### Engram ext/bin version sync

`gentle-engram` ext (submodule `vendor/Gentleman-Programming/engram`, `plugin/pi`) + `engram` bin (`dendritic/packages/engram.nix`) stay in sync. Bump both together.

Ext calls HTTP routes on the running `engram serve` bin. Old bin → missing route → ext degrades gracefully (404 → fallback/warning), but features silently die:

| Route | Feature | Server floor |
|-------|---------|--------------|
| `/review`, `/review/mark_reviewed` | `mem_review` list/mark_reviewed | v1.20.0+ |
| `/context/compaction` | session-summary + compaction recovery | 2.0.0-rc era (post-1.20.0) |

Check floor per tag: `git -C vendor/Gentleman-Programming/engram grep -l '<route>' v<tag> -- '*.go'`. Pin bin to latest stable (= 1.20.0 ceiling for stable); rc only if you need compaction recovery.

Bump procedure (`dendritic/packages/engram.nix`):

1. Set `version` = new tag; keep `baseUrl` scheme.
2. Fetch 4 tarballs `engram_<v>_{linux_amd64,linux_arm64,darwin_arm64,darwin_amd64}.tar.gz` from releases. SRI hash per platform: `curl -fsSLO <url>; nix hash file <tarball>` (`nix-prefetch-url` can be blocked by the lean-ctx shell allowlist).
3. Verify flat layout (binary `engram` at archive root — `dontUnpack` + `tar -xOf` depends on it) and `engram version` prints the new version (installCheck greps it).
4. `nix build --no-link .#engram` → installCheck confirms version.
5. Running server = old bin until `nixos-rebuild switch` / home-manager switch applies the new generation.

## Apply config changes

Repo paths are linked with `mkOutOfStoreSymlink`, so **content edits are live** at `~/.pi/agent/*` without rebuilding Home Manager. On the compiled systems this holds for skills, prompts, themes and config files only. A compiled loader under `~/.pi/agent/extensions/` links into the store tree, so an edit to it needs `nh`.

After editing extensions/skills/themes/prompts/models:

```bash
/reload                    # pick up discovery changes in a running session
# Or restart pi (needed for some settings / models.json changes)
pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/my-ext/index.ts
```

Rebuild Home Manager only when **wiring** changes (paths in `pi-coding-agent.nix`, new `home.file` entries, enable flags, or pi package bump):

```bash
home-manager switch --flake .#<host>
```

## Do NOT

Positive defaults: submodule under `vendor/<owner>/<repo>` + HM symlink = source of truth; edit in-repo (never under `~/.pi/agent/`); run `pi-ext-deps-install` after every submodule add/update with runtime deps; rebuild HM when Nix wiring changes.

- Put extensions in `dendritic/skills/` or skills in `extensions/`
- Use `pi install` for extensions we already vendor — submodule + HM symlink is source of truth
- Commit `node_modules/` in NixConfig-owned extensions unless intentional
- Edit files under `~/.pi/agent/extensions` or `skills` directly — they link to the repo, or on the compiled systems to the compiled store tree
- Forget `npm install --omit=dev` / `pi-ext-deps-install` after submodule add/update when extension has runtime deps
- Vendor a repo anywhere except `vendor/<owner>/<repo>` — all submodules live under the root `vendor/`, grouped by owner, named `owner/repo` in `.gitmodules`
- Break the `extensions/vendor` compat symlink (→ repo root `vendor/`) — loaders resolve `../vendor/...` through it; treat it as read-only plumbing
- Symlink mattpocock `caveman` over local `skills/caveman/` — keep the local copy
- Add an extension that registers tools, then skip `BLOCKED_TOOLS` and the audit script.

## Debugging

```bash
ls -la ~/.pi/agent/extensions ~/.pi/agent/skills
readlink ~/.pi/agent/extensions
pi --verbose
pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts   # interactive, extension loaded
printf '' | pi -ne -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts --mode rpc   # load check: loads it, no model turn
```

Common failures:

- Empty submodule dir → `git submodule update --init --recursive`
- Extension load error → missing `npm install`, bad `pi.extensions` path, or stale `@mariozechner/*` peer dep
- Load unconfirmable by other means: `pi -e <path> --help` exits 0 even for a nonexistent path; `list` outside the first argv token is a **prompt** (real model turn, 403 on unresolved `defaultModel`); `pi list` says “No packages installed” under HM symlinks; `-ne` does not suppress compiled-in extensions. Confirm: `printf '' | pi -ne -e <loader>/index.ts --mode rpc` (load error → non-zero exit)
- Changes not visible → `/reload` or restart pi; rebuild HM only if Nix wiring changed
- Pi package build fails after a release bump → update the pin hash in `dendritic/packages/pi-bolt.nix` (`platformAttrs.<system>.hash`) or `dendritic/packages/pi-bolt-compiled.nix` (`appHash`)
- Pi resolves to `piCompiled` on `x86_64-linux` and `aarch64-darwin`. Other systems get `pi`. `dendritic/overlays.nix` holds no npm hash

## pi-interactive-subagents fork (curated subagent stack)

Fork: `vendor/mattgmak/pi-interactive-subagents` → loader `extensions/pi-interactive-subagents/`.

Restricted subagents (`tools:` in agent frontmatter) launch with `--no-extensions` plus explicit `-e` paths. The fork injects a **global base list** before tool-backed extensions:

| Loader | Role |
|--------|------|
| `pi-lean-ctx` | ctx_* read/search/shell (replace mode) |
| `pi-permission-system` | permission gates on ctx_shell |
| `pi-cursor-sdk` | cursor provider models |
| `pi-web-access` | web_search / fetch_content |
| `pi-powerline-footer` | footer in tmux panes |
| `pi-caveman` | caveman mode in subagents |
| `filter-output` | redacts secrets in tool output, blocks sensitive reads |
| `rpiv-todo` | `todo` tool, needs `todo` in the agent `tools:` line |
| `pi-codegraph` | codegraph tools |
| `pi-token-speed` | live tok/s in subagent footer |
| `agent-ste` | STE lint on subagent writes and replies |

**Conditional:**
- `pi-interactive-subagents` loader when agent declares `subagent_agents` (worker spawn path).
- `pi-opencode-go-usage` for the `/opencode-go-usage` command. It reads the provider key from `ctx.modelRegistry`, so it works with the built-in `opencode-go` provider.
- The built-in `opencode-go` provider serves `opencode-go/*` models. Pi owns that catalog, so a live id missing there needs a `models.json` override.
- `pi-opencode-provider` stays removed: third-party ext forced `supportsReasoningEffort: false`, so DeepSeek V4.1 thinking levels collapsed to on/off. The built-in provider sends the level map.

**Denied (implicit):** engram, observational-memory, agent-sesh, pi-nvim*, … — not in base list; `--no-extensions` blocks discovery.

**Edit list:** `vendor/mattgmak/pi-interactive-subagents/pi-extension/subagents/index.ts` → `SUBAGENT_BASE_EXTENSIONS`. Run `npm test` in that submodule. Bump NixConfig submodule pointer after push to `mattgmak/pi-interactive-subagents`.

**Agent tools:** use `ctx_read`, `ctx_grep`, `ctx_find`, `ctx_ls`, `ctx_shell` in `dendritic/home-modules/pi-coding-agent/agents/*.md` (not native `read`/`bash`).

**MCP tools in subagents:** name each tool. Do not name bare `mcp`.

- `mcp` is the gateway. It calls every tool of every enabled server. A child that names `mcp` bypasses the parent deny list. Live proof: the gateway reached 105 tools, including Linear write verbs.
- Name direct tools instead: `Linear_get_issue`. The name exists only when `mcp.json` sets `"toolExposure": {"get_issue": "direct"}`. The child `--tools` flag still filters the final set.
- Name a server namespace to limit a child to one server: `mcp__argent`. Omit `mcp` at the same time.
- An unknown name fails silent. The child starts without the tool and prints nothing. Verify with a dump extension or `pi mcp list`.
- `peer.md` declares no `tools:` line. It keeps the full surface by design.

**Per-agent MCP files:** avoid `cwd/.pi/agent/mcp.json`. The fork exports `PI_CODING_AGENT_DIR` from it, and the child loses the global `settings.json`, `auth.json`, skills and extension list. A malformed file crashes the child with SIGSEGV.

**Permissions:** mirror `bash` rules under `ctx_shell` in `extensions/pi-permission-system/config.json`.

**Upstream merges:** fetch `upstream` (amosblomqvist), merge into fork, re-apply fork commits if needed, push `origin`, bump submodule SHA in NixConfig.

## Key files to edit

| Task | File(s) |
|------|---------|
| Wire paths / enable pi | `dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix` |
| Custom models/providers | `dendritic/home-modules/pi-coding-agent/models.json` |
| MCP servers (Pi global override) | `dendritic/home-modules/pi-coding-agent/mcp.json`. Human-edited source. `pi-coding-agent.nix` generates the store file from it |
| Add skill | `dendritic/skills/<name>/SKILL.md` |
| lean-ctx shell allowlist extras | `dendritic/home-modules/pi-coding-agent/lean-ctx/config.toml` |
| Agent shell permission rules | `dendritic/home-modules/pi-coding-agent/extensions/pi-permission-system/config.json` |
| Subagent curated extension list | `vendor/mattgmak/pi-interactive-subagents/pi-extension/subagents/index.ts` (`SUBAGENT_BASE_EXTENSIONS`) |
| Subagent agent profiles | `dendritic/home-modules/pi-coding-agent/agents/*.md` |
| Add/update extension | `vendor/<owner>/<name>/` + loader dir in `extensions/` (loader index.ts uses `../vendor/...`) |
| Register submodule | `.gitmodules` + `git submodule add <url> vendor/<owner>/<name>` |
| Bump pi package | `dendritic/packages/pi-bolt.nix` (version + both platform hashes) plus `dendritic/packages/pi-bolt-compiled.nix` (version + six hashes) |
| Bump engram binary (keep in sync with ext) | `dendritic/packages/engram.nix` (see Engram ext/bin version sync) |
| pi package overlay | `dendritic/overlays.nix` (pi-coding-agent = pi-bolt swap, `piCompiled` on x86_64-linux and aarch64-darwin) |
| Compiled host: extension list, deps, patches | `dendritic/packages/pi-bolt-compiled.nix` (see [Compiled host](#compiled-host-picompiled)) |
| Extension bundle for compiled bun hosts | `pi-ext-deps-install` → `install_pi_cursor_sdk` → `extensions/pi-cursor-sdk/pi-bolt-bundle.js` + bun branch in that loader's `index.ts` |
| Tool deny list | `dendritic/home-modules/pi-coding-agent/extensions/tool-allowlist/index.ts` |

## Goofeus agent workspace (GoofeusAgent)

`homeConfigurations.GoofeusAgent` on `dendritic/hosts/Goofeus.nix` — dedicated `agent` Linux user running pi + tmux orchestrator + `pi-interactive-subagents` + worktrunk + zellij + bash/carapace. Root stays admin/builder (no pi).

### Bootstrap from GoofyDesky (first deploy)

```bash
# on GoofyDesky, repo at ~/NixConfig
git add -A && git commit -m "goofeus: agent workspace (pi+age key)"   # then push
nh os switch --flake ~/NixConfig#Goofeus
```

First run creates `users.users.agent` + HM GoofeusAgent + NixOS `age.secrets.agent-age-key`. `~/NixConfig` is auto-cloned/fast-forwarded on every `home-manager switch` via `nixconfig-sync` home module (`main` = flake SSOT; agent coding work uses git worktrees via `worktrunk` — never main).

### Post-bootstrap manual (once)

```bash
sudo passwd agent                     # set agent user password (needed for sudo)
```

Everything else is Nix-managed:

- `pi-ext-deps-install-if-stale` runs `pi-ext-deps-install` when stale. Trigger: HM activation only (`autoExtDepsInstall`), so a switch installs. Stamp: `~/.local/state/pi-ext-deps-install.stamp`. It hashes node/npm versions plus path, mtime and size of every `package.json` and lockfile under `vendor/` and `extensions/`, so a node bump or a vendor update reruns installs. Failure is non-fatal. Run `pi-ext-deps-install` by hand when you change vendor deps without a switch.

HM already starts an empty `agents` tmux session on boot (`systemd.user.services.agents-tmux`). Start pi inside it: `tmux attach -t agents` then `pi`.

### Runtime

- No phone/PWA frontend — browser via SSH tmux only: `ssh agent@goofeus -t tmux attach -t agents`.
- Rebuilds: `agent` runs `nh os switch` with interactive sudo password — **never** passwordless sudo.

### Secrets

- `secrets/secrets.nix`: `AgentAge` pubkey added to the 8 pi API secrets (opencode/cursor/github-mcp/cline/mercury/context7/cursor-usage/deepseek) + `agent-age-key.age` (agent's private age identity, encrypted to Goofeus host key + GoofyDeskyRoot).
- MCP OAuth for Linear: `mcp.json` sets `settings.oauthCredentialStore` to `encrypted-file`. Tokens go to `~/.pi/agent/mcp-oauth-encrypted/`. Key comes from `secrets/pi-mcp-adapter-oauth-file-key.age` (`scripts/make-pi-oauth-key.sh` makes it) and lands at `~/.pi/agent/oauth-file-key`. The `pi` wrapper exports the key, so other shells never hold it. No keychain, so headless hosts work and no dialog appears.
- NixOS: `age.secrets.agent-age-key` → `/run/agenix/agent-age-key` (owner=agent, 0400). Agent HM: `age.identityPaths = [ "/run/agenix/agent-age-key" ]`.
- Rekey after adding/removing a recipient: `cd secrets && RULES=./secrets.nix agenix -r -i <decrypting-identity>` — ensure every `.age` file's recipients include an identity you hold, or comment that secret out of `secrets.nix` first (agent-age-key only decrypts with Goofeus host key / GoofyDeskyRoot, not a user key).
- Agent's private key backup: `$TMPDIR/agent-tmp/agent-agekey/id_agent_age` (keep until Goofeus bootstrapped; needed to re-encrypt if recipient set grows).
