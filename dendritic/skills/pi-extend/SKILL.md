---
name: pi-extend
description: >
  How this NixConfig repo extends pi (extensions, skills, themes, prompts, models).
  Use when adding/changing pi extensions or skills, vendoring upstream repos as git
  submodules, wiring home-manager, or debugging pi discovery/reload issues.
---

References are relative to `~/NixConfig/dendritic` unless noted.

# Pi Extend (NixConfig)

This repo manages pi via Home Manager + `coding-agents` flake module. Extensions/skills live in-repo; Home Manager links them into `~/.pi/agent/` via `mkOutOfStoreSymlink` (live edits in the repo, no rebuild needed for content changes).

## Layout

```
dendritic/
├── skills/                          # global pi skills (SKILL.md dirs)
│   ├── vendor/                      # git submodules (upstream skill repos)
│   │   └── mattpocock-skills/       # mattpocock/skills checkout
│   ├── <skill-name>/                # local skill or symlink → vendor/.../skills/...
│   └── pi-extend/                   # repo-owned skill
└── home-modules/pi-coding-agent/
    ├── pi-coding-agent.nix          # wiring module
    ├── models.json                  # custom providers/models
    ├── mcp.json                     # Pi global MCP override (~/.pi/agent/mcp.json)
    ├── extensions/                  # pi TypeScript extensions
    │   ├── vendor/                  # git submodules (upstream sources)
    │   │   └── <name>/              # e.g. vendor/cursor-provider/
    │   ├── <name>/                  # symlink → vendor/<name> (direct exts)
    │   └── <loader>/                # thin loader package.json (monorepo exts)
    ├── prompts/                     # prompt templates (.md)
    └── themes/                      # e.g. git submodule of theme repo
```

List what is actually installed:

```bash
ls dendritic/skills/
ls dendritic/home-modules/pi-coding-agent/extensions/
ls dendritic/home-modules/pi-coding-agent/extensions/vendor/
cat .gitmodules
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

`pi-coding-agent.nix` also imports `inputs.coding-agents.homeManagerModules.default`, enables `pi-coding-agent`, and adds `nodejs_22`.

User settings (`~/.pi/agent/settings.json`) are **not** managed by Nix (provider, model, theme, etc.).

### Examples (not exhaustive)

**Extension submodule** — vendored under `extensions/vendor/<name>/`, exposed via symlink `extensions/<name>`:

```
extensions/vendor/cursor-provider/   # git submodule checkout
extensions/cursor-provider -> vendor/cursor-provider
extensions/pi-nvim/index.ts     → ../vendor/pi-nvim/extension.ts
```

**Loader package** — thin dir with `./index.ts` re-export (good pi config names):

```
extensions/mcp-nixos/index.ts       → ../vendor/mcp-nixos/...
extensions/pi-simplify/index.ts     → ../vendor/pi-extensions/...
extensions/context-mode/index.ts    → ../vendor/context-mode/build/adapters/pi/extension.js
extensions/rpiv-todo/index.ts       → ../vendor/rpiv-mono/...
```

Use `./index.ts` in `pi.extensions` so pi shows `<name>/index.ts`, not nested vendor paths.

**Theme submodules** — vendored under `themes/vendor/`, exposed via symlinks at `themes/*.json` (not `extensions/`):

```
themes/vendor/dracula/dracula.json
themes/vendor/pi-ansi-themes/themes/ansi-dark.json
themes/dracula.json     -> vendor/dracula/dracula.json
themes/ansi-dark.json   -> vendor/pi-ansi-themes/themes/ansi-dark.json
themes/ansi-light.json  -> vendor/pi-ansi-themes/themes/ansi-light.json
themes/catppuccin-latte.json     -> vendor/pi-coding-agent-catppuccin/catppuccin-latte.json
themes/catppuccin-frappe.json    -> vendor/pi-coding-agent-catppuccin/catppuccin-frappe.json
themes/catppuccin-macchiato.json -> vendor/pi-coding-agent-catppuccin/catppuccin-macchiato.json
themes/catppuccin-mocha.json     -> vendor/pi-coding-agent-catppuccin/catppuccin-mocha.json
```

`themes/.gitignore` lists `vendor/` (same pattern as `extensions/`).

**Skill (local)** — markdown under `dendritic/skills/<name>/SKILL.md`:

```
skills/caveman/SKILL.md       # repo-owned (not from mattpocock)
```

**Skill (vendored)** — submodule + top-level symlink:

```
skills/vendor/mattpocock-skills/          # git submodule (mattpocock/skills)
skills/tdd -> vendor/mattpocock-skills/skills/engineering/tdd
skills/grill-me -> vendor/mattpocock-skills/skills/productivity/grill-me
```

`skills/.gitignore` lists `vendor/` so pi does not treat the submodule root as a skill.

Vendored extensions are usually pi packages (`keywords: ["pi-package"]`). Pi discovers subdirs via `package.json` → `pi.extensions` array, or `index.ts`/`index.js`. Skills = `SKILL.md` in a directory; pi auto-discovers from the global skills dir.

`extensions/.gitignore` lists `vendor/` so pi auto-discovery skips duplicate scans of submodule checkouts. Top-level symlinks + loader dirs are what pi loads.

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

Bundled pi imports available to extensions: `@mariozechner/pi-coding-agent`, `@mariozechner/pi-ai`, `@mariozechner/pi-tui`, `@mariozechner/pi-agent-core`, `typebox`.

## Git submodule vendoring

We vendor third-party pi resources as git submodules under `dendritic/home-modules/pi-coding-agent/extensions/vendor/`. Nix flake has `self.submodules = true`.

### Submodule naming

Name each submodule in `.gitmodules` as **`owner/repo`** parsed from the git URL (without `.git`), not the checkout path.

Examples:

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

Prefer `.git/modules/<owner>/<repo>` for the internal git dir (move + update `gitdir:` in the submodule `.git` file if renaming an existing submodule).

### Add new extension submodule

From NixConfig repo root:

```bash
# 1. Add submodule under vendor/ (name in .gitmodules = owner/repo)
git submodule add <upstream-url> dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>

# 2. Expose to pi discovery
cd dendritic/home-modules/pi-coding-agent/extensions
ln -s "vendor/<name>" "<name>"    # direct package
# OR add a loader dir with package.json → ../vendor/<mono>/...

# 3. Install runtime deps inside submodule (required before pi loads it)
cd vendor/<name>
npm install --omit=dev

# 4. Verify package.json has pi manifest
#    "pi": { "extensions": ["./index.ts"] }

# 5. Commit .gitmodules + submodule pointer + symlink/loader
git add .gitmodules dendritic/home-modules/pi-coding-agent/extensions/
git commit -m "vendor pi extension <name>"
```

### Update vendored extension

```bash
cd dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
git fetch origin
git checkout <ref>          # tag, branch, or commit
cd ../../../../../../..     # back to NixConfig root
git add dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
git commit -m "bump <name> to <ref>"

# Re-run npm install if package.json/lock changed
cd dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>
npm install --omit=dev
```

### Clone repo with submodules

```bash
git clone --recurse-submodules <NixConfig-url>
# or after clone:
git submodule update --init --recursive
```

Git config in `dendritic/home-modules/git.nix` sets `submodule.recurse = true` and `push.recurseSubmodules = on-demand`.

### Fork workflow

When upstream needs local patches: fork upstream, point submodule at your fork, push fixes there, bump submodule SHA in NixConfig when ready.

Example: `offbynan/pi-cursor-provider` → fork `you/pi-cursor-provider` → submodule URL to fork.

### Theme submodule

Themes vendored under `themes/vendor/<name>/` (not `extensions/`). Pi discovers `*.json` at the top level of `themes/`, so symlink each theme file up from the submodule checkout.

```bash
git submodule add https://github.com/leblancfg/pi-ansi-themes.git \
  dendritic/home-modules/pi-coding-agent/themes/vendor/pi-ansi-themes
# .gitmodules entry: [submodule "leblancfg/pi-ansi-themes"]  (owner/repo, not path)

cd dendritic/home-modules/pi-coding-agent/themes
ln -sfn vendor/pi-ansi-themes/themes/ansi-dark.json ansi-dark.json
ln -sfn vendor/pi-ansi-themes/themes/ansi-light.json ansi-light.json
```

Symlinked to `~/.pi/agent/themes` via `mkOutOfStoreSymlink`. Select theme name in `~/.pi/agent/settings.json` (e.g. `ansi-dark`, `ansi-light`, `dracula`).

## Vendored skills (`mattpocock/skills`)

Submodule at `dendritic/skills/vendor/mattpocock-skills` (`.gitmodules`: `mattpocock/skills`). Expose skills via symlinks at `dendritic/skills/<name>` → `vendor/mattpocock-skills/skills/{engineering,productivity}/<name>`.

**Installed from upstream** (engineering + productivity; `caveman` excluded — use local `skills/caveman/`):

`diagnose`, `grill-with-docs`, `triage`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `tdd`, `to-issues`, `to-prd`, `zoom-out`, `prototype`, `grill-me`, `handoff`, `write-a-skill`

Run **`/setup-matt-pocock-skills` once per target repo** before engineering skills that need issue tracker / triage labels / `docs/agents/` layout.

### Add or bump vendored skills repo

```bash
# From NixConfig root — first time
 git submodule add https://github.com/mattpocock/skills.git \
   dendritic/skills/vendor/mattpocock-skills
# .gitmodules: [submodule "mattpocock/skills"]

# Expose a skill
cd dendritic/skills
ln -sfn vendor/mattpocock-skills/skills/engineering/<name> <name>

# Bump
cd dendritic/skills/vendor/mattpocock-skills && git fetch && git checkout <ref>
cd ~/NixConfig && git add dendritic/skills/vendor/mattpocock-skills
```

No `npm install`. `/reload` in pi after symlink or submodule changes.

## Add a new skill (no submodule)

```bash
mkdir -p dendritic/skills/<skill-name>
# write dendritic/skills/<skill-name>/SKILL.md with frontmatter:
# ---
# name: <skill-name>
# description: when to use this skill
# ---
```

No home-manager change needed if `skillsDir` already points at `dendritic/skills`. Edit the repo file and `/reload` in pi (or restart pi).

## Add a local extension (no upstream repo)

For repo-owned extensions not vendored:

```bash
mkdir -p dendritic/home-modules/pi-coding-agent/extensions/my-ext
# write index.ts + optional package.json
cd dendritic/home-modules/pi-coding-agent/extensions/my-ext
npm install --omit=dev   # if deps needed
```

Commit directly in NixConfig (not submodule).

## Install extension deps (`pi-npm-i`)

Home Manager installs `pi-npm-i`. It walks top-level `extensions/*` loaders/symlinks and runs `npm i --omit=dev` where `package.json` has deps.

Also builds vendored **context-mode** (needs devDependencies):

```bash
pi-npm-i   # vendor/context-mode: npm install && npm run build
```

Run after submodule add/update or when `vendor/context-mode/build/` is missing.

## Apply config changes

Repo paths are linked with `mkOutOfStoreSymlink`, so **content edits are live** at `~/.pi/agent/*` without rebuilding Home Manager.

After editing extensions/skills/themes/prompts/models:

```bash
# Pick up discovery changes in a running session
/reload

# Or restart pi (needed for some settings / models.json changes)

# One-off test without touching discovered extensions
pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/my-ext/index.ts
```

Rebuild Home Manager only when **wiring** changes (paths in `pi-coding-agent.nix`, new `home.file` entries, enable flags):

```bash
home-manager switch --flake .#<host>
```

## Do NOT

- Put extensions in `dendritic/skills/` or skills in `extensions/`
- Use `pi install` for extensions we already vendor — submodule + HM symlink is source of truth
- Commit `node_modules/` in NixConfig-owned extensions unless intentional; submodules may keep their own lockfiles
- Edit files under `~/.pi/agent/extensions` or `skills` directly — they symlink to repo; edit repo paths instead
- Forget `npm install --omit=dev` after submodule add/update when extension has runtime deps
- Remove `extensions/.gitignore` `vendor/` entry — pi would double-discover vendor checkouts
- Remove `skills/.gitignore` `vendor/` entry — pi would treat the submodule root as a skill
- Symlink mattpocock `caveman` over local `skills/caveman/` — keep the local copy

## Debugging

```bash
# What pi sees
ls -la ~/.pi/agent/extensions ~/.pi/agent/skills
readlink ~/.pi/agent/extensions

# List loaded extensions
pi list

# Verbose startup
pi --verbose

# Test single extension
pi -e ~/NixConfig/dendritic/home-modules/pi-coding-agent/extensions/<name>/index.ts
```

Common failures:

- Empty submodule dir → run `git submodule update --init --recursive`
- Extension load error → missing `npm install`, bad `pi.extensions` path, or stale `@mariozechner/*` peer dep
- Changes not visible → use `/reload` or restart pi; rebuild HM only if you changed Nix wiring (not repo content)

## Key files to edit

| Task | File(s) |
|------|---------|
| Wire paths / enable pi | `dendritic/home-modules/pi-coding-agent/pi-coding-agent.nix` |
| Custom models/providers | `dendritic/home-modules/pi-coding-agent/models.json` |
| MCP servers (Pi global override) | `dendritic/home-modules/pi-coding-agent/mcp.json` |
| Add skill | `dendritic/skills/<name>/SKILL.md` |
| Add/update extension | `dendritic/home-modules/pi-coding-agent/extensions/vendor/<name>/` + symlink/loader |
| Register submodule | `.gitmodules` + `git submodule add` under `extensions/vendor/` |
| pi package overlay | `dendritic/overlays.nix` (pi-coding-agent build tweaks) |
