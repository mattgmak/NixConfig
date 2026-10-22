# Vendoring convention

Third-party repos = git submodules. All under root `vendor/` — nothing else.

## Skill authoring

Skills in `dendritic/skills/` (and any agent-written skill docs) are **caveman coded**: terse prose, no filler/hedging/articles. Keep all technical substance exact — commands, paths, code blocks, tables, frontmatter verbatim. Multi-step sequences stay unambiguous: don't compress away required order, warnings, or critical nuance.

```
vendor/<Owner>/<repo>/
```

- `<Owner>` — GitHub owner dir, URL casing (`mattgmak`, `MattDevy`, `Gentleman-Programming`)
- `<repo>` — bare repo name (`lean-ctx`, `pi-extensions`, `zen-wireframe-2`)

Rules:

- **No vendor dirs outside `vendor/`** — extensions, themes, skills, zen, tools all share it. Never `vendor/` under `dendritic/...`.
- **`.gitmodules` name = `owner/repo`** from git URL, not checkout path (`[submodule "mattgmak/lean-ctx"]`).
- **Pi extensions**: thin loader dir `dendritic/home-modules/pi-coding-agent/extensions/<name>/` — `package.json` (`pi.extensions: ["./index.ts"]`, optional `pi.skills`) + `index.ts` re-export `../vendor/<Owner>/<repo>/…`. Pi resolves loader imports against live `~/.pi/agent/extensions/<name>/` — depth fixed at 1 up, lands on `extensions/vendor` compat symlink → repo root `vendor/`. Submodule never inside `extensions/`.
- **Themes**: symlink `…/themes/<name>.json` → `../../../../vendor/<Owner>/<repo>/…`.
- **Skills**: symlink `dendritic/skills/<name>` → `../../vendor/<owner>/<repo>/…`.
- `pi-ext-deps-install` installs vendor extension deps; skips non-extension repos (themes/skills/zen/tools) + special-cases `lean-ctx`, `pi-packages`, `fgladisch/pi-extensions`, `engram`, `pi-cursor-sdk` (`npm ci --ignore-scripts` + `build.mjs` → `dist/`).
- **System switch/rebuild**: always defer to user to manually do switch/rebuild via `nh` for the current machine.

New vendored repo: `git submodule add <url> vendor/<owner>/<repo>`, rename `.gitmodules` name → `owner/repo` if git used path. Full workflow + fork handling: `dendritic/skills/pi-setup/REFERENCE.md`.

## New packages

A package file lives in `dendritic/packages/` and uses the flake-parts module shape.
`import-tree` auto-imports the file as a module under `dendritic/`.
The file takes `{ ... }:` and defines `perSystem = { pkgs, ... }: { ... }`.
It registers the derivation under `perSystem` as `packages.<name>`.
Call `pkgs.callPackage` inline and keep the derivation logic in that one file.
Hosts reach the package through an overlay in `dendritic/overlays.nix` or through the consuming module.
Add the overlay to the `common-overlays` list.
A temporary pin carries a TODO that names the version which lets it return to nixpkgs.

## Flake sources

`nix store gc` deletes the flake input source trees. Nothing roots them by default,
because a source tree is neither a derivation nor an output. The
`home.activation.rootFlakeSources` entry in `dendritic/hosts/MacMini.nix` roots the
trees of the current lock. It calls `scripts/root-flake-sources.sh`, which makes
out-links under `$HOME/.local/state/flake-sources`. The nix daemon registers them
as root, so this needs no privilege. A big nixpkgs source tree costs about 5 GB.

## Flake evals

`builtins.getFlake "/Users/mattgmak/NixConfig"` reads the repo as a path flake. It copies the whole working tree, about 5 GB with submodules and node_modules. Every edit makes a new copy.

`nix flake metadata .` and `nix eval .#...` use git mode. That copy is 254 MB, and Nix shares it across evaluations.

Use the git form. An expression that needs `getFlake` names `git+file:///Users/mattgmak/NixConfig`.

A git-mode flake sees tracked files only. An untracked file stays invisible, so its module never loads. Run `git add -N <path>` after you create a file, before any eval or switch. This fault reached a switch on 2026-10-22 and failed it with `error: attribute 'uvBin' missing`.

Four path-flake evals cost 21 GB of store space on 2026-10-22.

## Commit convention

- **Subject only** — one line, no body, no trailers (`Co-authored-by`, `Signed-off-by`, etc.) unless user explicitly requests one
- **Never** pass `git commit --trailer` or append attribution trailers for Cursor, agents, or tooling — not default, not "helpful"
- Use plain `git commit -m "$(cat <<'EOF' … EOF)"` — subject line only inside the heredoc
- Imperative mood, capitalize first word (e.g. `Generate pi themes from Stylix palette.`)

## Comments

- Fewest possible. Non-obvious *why* only — never *what*, no commented-out code, section banners, or change notes.
