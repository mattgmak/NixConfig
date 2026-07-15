# Pi Setup — Reference

Companion to [SKILL.md](SKILL.md). Layout, conventions, and debugging for pi in this NixConfig repo.

## Layout

```
dendritic/
├── skills/                          # global pi skills (SKILL.md dirs)
│   ├── vendor/                      # git submodules (upstream skill repos)
│   │   └── mattpocock-skills/       # mattpocock/skills checkout
│   ├── <skill-name>/                # local skill or symlink → vendor/.../skills/...
│   └── pi-setup/                    # repo-owned skill
└── home-modules/pi-coding-agent/
    ├── pi-coding-agent.nix          # wiring module
    ├── models.json                  # custom providers/models
    ├── mcp.json                     # Pi global MCP override (~/.pi/agent/mcp.json)
    ├── extensions/                  # pi TypeScript extensions
    │   ├── vendor/                  # git submodules (upstream sources)
    │   │   └── <name>/              # e.g. vendor/cursor-provider/
    │   └── <loader>/                # thin loader dir (package.json + index.ts → vendor/)
    ├── prompts/                     # prompt templates (.md)
    └── themes/                      # e.g. git submodule of theme repo
```

Deployed at runtime:

| Repo path | `~/.pi/agent/` target | Mechanism |
|-----------|----------------------|-----------|
| `dendritic/skills/` | `skills/` | `coding-agents.skillsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/extensions/` | `extensions/` | `coding-agents.pi-coding-agent.extensionsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/prompts/` | `prompts/` | `coding-agents.pi-coding-agent.promptsDir` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/themes/` | `themes/` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/models.json` | `models.json` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/mcp.json` | `mcp.json` | `home.file` → `mkOutOfStoreSymlink` |
| `home-modules/pi-coding-agent/AGENTS.md` | `AGENTS.md` | `coding-agents.agentsMdPath` → `mkOutOfStoreSymlink` |

`pi-coding-agent.nix` also imports `inputs.coding-agents.homeManagerModules.default`, enables `pi-coding-agent`, and adds `nodejs_22`.

User settings (`~/.pi/agent/settings.json`) are **not** managed by Nix.

Pi itself is pinned via the `coding-agents` flake input (`flake.nix` → `github:kissgyorgy/coding-agents`). The `pi-coding-agent` package may be overridden in `dendritic/overlays.nix` (npm deps hash).

### Examples (not exhaustive)

**Extension submodule** — vendored under `extensions/vendor/<name>/`, exposed via loader dir `extensions/<name>/`:

```
extensions/vendor/cursor-provider/
extensions/cursor-provider/index.ts  → ../vendor/cursor-provider/index.ts
extensions/pi-nvim/index.ts          → ../vendor/pi-nvim/extension.ts
```

**Loader package** — thin dir with `package.json` + `./index.ts` re-export:

```
extensions/mcp-nixos/index.ts       → ../vendor/mcp-nixos/...
extensions/pi-simplify/index.ts     → ../vendor/pi-extensions/...
extensions/rpiv-todo/index.ts       → ../vendor/rpiv-mono/...
```

Use `./index.ts` in `pi.extensions` so pi shows `<name>/index.ts`, not nested vendor paths.

**Theme submodules** — vendored under `themes/vendor/`, exposed via symlinks at `themes/*.json`:

```
themes/vendor/dracula/dracula.json
themes/dracula.json     -> vendor/dracula/dracula.json
themes/ansi-dark.json   -> vendor/pi-ansi-themes/themes/ansi-dark.json
```

`themes/.gitignore` lists `vendor/` (same pattern as `extensions/`).

**Skill (local)** — markdown under `dendritic/skills/<name>/SKILL.md`.

**Skill (vendored)** — submodule + top-level symlink:

```
skills/vendor/mattpocock-skills/
skills/tdd -> vendor/mattpocock-skills/skills/engineering/tdd
```

`skills/.gitignore` lists `vendor/` so pi does not treat the submodule root as a skill.

Vendored extensions are usually pi packages (`keywords: ["pi-package"]`). Pi discovers subdirs via `package.json` → `pi.extensions` array, or `index.ts`/`index.js`. Skills = `SKILL.md` in a directory.

`extensions/.gitignore` lists `vendor/` so pi auto-discovery skips duplicate scans of submodule checkouts. Top-level loader dirs are what pi loads.

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
4. `vendor/` ignored via `extensions/.gitignore`
5. No deeper recursion — complex packages must declare paths in `pi.extensions`

Bundled pi imports: `@mariozechner/pi-coding-agent`, `@mariozechner/pi-ai`, `@mariozechner/pi-tui`, `@mariozechner/pi-agent-core`, `typebox`.

## Git submodule vendoring

We vendor third-party pi resources as git submodules. Nix flake has `self.submodules = true`.

### Submodule naming

Name each submodule in `.gitmodules` as **`owner/repo`** parsed from the git URL (without `.git`), not the checkout path.

| URL | Submodule name | Path (may differ) |
|-----|----------------|-------------------|
| `https://github.com/dracula/pi-coding-agent.git` | `dracula/pi-coding-agent` | `.../themes` |
| `https://github.com/mattgmak/zen-wireframe-2.0` | `mattgmak/zen-wireframe-2.0` | `.../zen-wireframe-2` |
| `https://github.com/nicobailon/pi-web-access.git` | `nicobailon/pi-web-access` | `.../extensions/vendor/pi-web-access` |

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

### Fork workflow

When upstream needs local patches: fork upstream, point submodule at your fork, push fixes there, bump submodule SHA in NixConfig when ready.

### Fork vendored extensions

Extension submodules whose `.gitmodules` URL is **your fork** must be checked against **upstream**, not just `origin`. During `pi-setup update`, always fetch upstream and compare before proposing a bump.

#### Registry (extension forks)

| Loader / vendor dir | Submodule URL (fork) | Upstream | Upstream branch |
|---------------------|----------------------|----------|-----------------|
| `cursor-provider` | `mattgmak/pi-cursor-provider` | `https://github.com/offbynan/pi-cursor-provider.git` | `main` |
| `pi-lens` | `mattgmak/pi-lens` | `https://github.com/apmantza/pi-lens.git` | `master` |
| `lean-ctx` | `mattgmak/lean-ctx` | `https://github.com/yvgude/lean-ctx.git` | `main` |
| `pi-simplify` (`vendor/pi-extensions`) | `MattDevy/pi-extensions` | *(your repo — no separate upstream)* | `main` |

Add new rows here when vendoring through a fork.

#### Detect fork submodules

```bash
# From NixConfig root — extension vendor paths whose URL is your GitHub user
grep -E 'url = https://github.com/(mattgmak|MattDevy)/' .gitmodules
```

#### Upstream comparison (per fork)

```bash
VENDOR=dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
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

```bash
cd dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
git checkout main   # or master for pi-lens
git merge upstream/<branch>   # or rebase if you prefer linear history
# resolve conflicts; preserve fork-only fixes
npm install --omit=dev   # if package.json changed
git push origin HEAD

cd ~/NixConfig
git add dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
```

Then run `pi-npm-i` from the repo root if deps changed.

## Vendored skills (`mattpocock/skills`)

Submodule at `dendritic/skills/vendor/mattpocock-skills`. Expose skills via symlinks at `dendritic/skills/<name>` → `vendor/mattpocock-skills/skills/{engineering,productivity}/<name>`.

Run **`/setup-matt-pocock-skills` once per target repo** before engineering skills that need issue tracker / triage labels / `docs/agents/` layout.

## Add a local extension (no upstream repo)

```bash
mkdir -p dendritic/home-modules/pi-coding-agent/extensions/my-ext
# write index.ts + optional package.json
cd dendritic/home-modules/pi-coding-agent/extensions/my-ext
npm install --omit=dev   # if deps needed
```

Commit directly in NixConfig (not submodule).

## Install extension deps (`pi-npm-i`)

Home Manager installs `pi-npm-i`. It walks top-level `extensions/*` loaders and `extensions/vendor/*` submodules, running `npm i --omit=dev` where `package.json` has deps.

Run after submodule add/update when an extension has runtime deps.

## Apply config changes

Repo paths are linked with `mkOutOfStoreSymlink`, so **content edits are live** at `~/.pi/agent/*` without rebuilding Home Manager.

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

- Put extensions in `dendritic/skills/` or skills in `extensions/`
- Use `pi install` for extensions we already vendor — submodule + HM symlink is source of truth
- Commit `node_modules/` in NixConfig-owned extensions unless intentional
- Edit files under `~/.pi/agent/extensions` or `skills` directly — they symlink to repo
- Forget `npm install --omit=dev` / `pi-npm-i` after submodule add/update when extension has runtime deps
- Remove `extensions/.gitignore` `vendor/` entry — pi would double-discover vendor checkouts
- Remove `skills/.gitignore` `vendor/` entry — pi would treat the submodule root as a skill
- Symlink mattpocock `caveman` over local `skills/caveman/` — keep the local copy

## Debugging

```bash
ls -la ~/.pi/agent/extensions ~/.pi/agent/skills
readlink ~/.pi/agent/extensions
pi list
pi --verbose
pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts
```

Common failures:

- Empty submodule dir → `git submodule update --init --recursive`
- Extension load error → missing `npm install`, bad `pi.extensions` path, or stale `@mariozechner/*` peer dep
- Changes not visible → `/reload` or restart pi; rebuild HM only if Nix wiring changed
- Pi package build fails after flake update → update `npmDepsHash` in `dendritic/overlays.nix`

## Key files to edit

| Task | File(s) |
|------|---------|
| Wire paths / enable pi | `dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix` |
| Custom models/providers | `dendritic/home-modules/pi-coding-agent/models.json` |
| MCP servers (Pi global override) | `dendritic/home-modules/pi-coding-agent/mcp.json` |
| Add skill | `dendritic/skills/<name>/SKILL.md` |
| Add/update extension | `dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>/` + loader dir |
| Register submodule | `.gitmodules` + `git submodule add` under `extensions/vendor/` |
| Bump pi package | `flake.nix` / `flake.lock` (`coding-agents` input) + `dendritic/overlays.nix` |
| pi package overlay | `dendritic/overlays.nix` (pi-coding-agent build tweaks) |
