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
│   └── <skill-name>/                # e.g. pi-extend/
└── home-modules/pi-coding-agent/
    ├── pi-coding-agent.nix          # wiring module
    ├── models.json                  # custom providers/models
    ├── mcp.json                     # Pi global MCP override (~/.pi/agent/mcp.json)
    ├── extensions/                  # pi TypeScript extensions
    │   └── <ext-name>/              # e.g. git submodule or local dir
    ├── prompts/                     # prompt templates (.md)
    └── themes/                      # e.g. git submodule of theme repo
```

List what is actually installed:

```bash
ls dendritic/skills/
ls dendritic/home-modules/pi-coding-agent/extensions/
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

**Extension submodule** — vendored package under `extensions/<name>/`:

```
extensions/cursor-provider/   # upstream or fork; entry via package.json pi.extensions
extensions/pi-nvim/           # e.g. extension.ts declared in pi.extensions
```

**Theme submodule** — vendored under `themes/` (not `extensions/`):

```
themes/                       # e.g. dracula/pi-coding-agent theme JSON files
```

**Skill** — markdown instructions under `dendritic/skills/<name>/SKILL.md`:

```
skills/caveman/SKILL.md       # e.g. response-style instructions for the model
```

Vendored extensions are usually pi packages (`keywords: ["pi-package"]`). Pi discovers subdirs via `package.json` → `pi.extensions` array, or `index.ts`/`index.js`. Skills = `SKILL.md` in a directory; pi auto-discovers from the global skills dir.

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

Bundled pi imports available to extensions: `@mariozechner/pi-coding-agent`, `@mariozechner/pi-ai`, `@mariozechner/pi-tui`, `@mariozechner/pi-agent-core`, `typebox`.

## Git submodule vendoring

We vendor third-party pi resources as git submodules under `dendritic/home-modules/pi-coding-agent/`. Nix flake has `self.submodules = true`.

### Submodule naming

Name each submodule in `.gitmodules` as **`owner/repo`** parsed from the git URL (without `.git`), not the checkout path.

Examples:

| URL | Submodule name | Path (may differ) |
|-----|----------------|-------------------|
| `https://github.com/dracula/pi-coding-agent.git` | `dracula/pi-coding-agent` | `.../themes` |
| `https://github.com/mattgmak/zen-wireframe-2.0` | `mattgmak/zen-wireframe-2.0` | `.../zen-wireframe-2` |
| `https://github.com/nicobailon/pi-web-access.git` | `nicobailon/pi-web-access` | `.../extensions/pi-web-access` |

When adding:

```bash
git submodule add <url> <path>
# then rename [submodule "<path>"] → [submodule "<owner>/<repo>"] in .gitmodules if git used the path
```

Prefer `.git/modules/<owner>/<repo>` for the internal git dir (move + update `gitdir:` in the submodule `.git` file if renaming an existing submodule).

### Add new extension submodule

From NixConfig repo root:

```bash
# 1. Add submodule at target path (name in .gitmodules = owner/repo)
git submodule add <upstream-url> dendritic/home-modules/pi-coding-agent/extensions/<name>

# 2. Install runtime deps inside submodule (required before pi loads it)
cd dendritic/home-modules/pi-coding-agent/extensions/<name>
npm install --omit=dev

# 3. Verify package.json has pi manifest
#    "pi": { "extensions": ["./index.ts"] }

# 4. Commit .gitmodules + submodule pointer
git add .gitmodules dendritic/home-modules/pi-coding-agent/extensions/<name>
git commit -m "vendor pi extension <name>"
```

### Update vendored extension

```bash
cd dendritic/home-modules/pi-coding-agent/extensions/<name>
git fetch origin
git checkout <ref>          # tag, branch, or commit
cd ../../../../..           # back to NixConfig root
git add dendritic/home-modules/pi-coding-agent/extensions/<name>
git commit -m "bump <name> to <ref>"

# Re-run npm install if package.json/lock changed
cd dendritic/home-modules/pi-coding-agent/extensions/<name>
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

Themes vendored same way but land in `themes/` not `extensions/`:

```bash
git submodule add https://github.com/dracula/pi-coding-agent.git \
  dendritic/home-modules/pi-coding-agent/themes
# .gitmodules entry: [submodule "dracula/pi-coding-agent"]  (owner/repo, not path)
```

Symlinked to `~/.pi/agent/themes` via `mkOutOfStoreSymlink`. Select theme name in `~/.pi/agent/settings.json`.

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
| Add/update extension | `dendritic/home-modules/pi-coding-agent/extensions/<name>/` |
| Register submodule | `.gitmodules` + `git submodule add` |
| pi package overlay | `dendritic/overlays.nix` (pi-coding-agent build tweaks) |
