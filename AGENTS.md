# Vendoring convention

Third-party repos = git submodules. All under root `vendor/` — nothing else.

## Skill authoring

Skills in `dendritic/skills/` (and any agent-written skill docs) are **caveman coded**: terse prose, no filler/hedging/articles. Keep all technical substance exact — commands, paths, code blocks, tables, frontmatter verbatim. Multi-step sequences stay unambiguous: don't compress away required order, warnings, or critical nuance.

```
vendor/<Owner>/<repo>/
```

- `<Owner>` — GitHub owner dir, URL casing (`mattgmak`, `MattDevy`, `Gentleman-Programming`)
- `<repo>` — bare repo name (`pi-lens`, `pi-extensions`, `zen-wireframe-2`)

Rules:

- **No vendor dirs outside `vendor/`** — extensions, themes, skills, zen, tools all share it. Never `vendor/` under `dendritic/...`.
- **`.gitmodules` name = `owner/repo`** from git URL, not checkout path (`[submodule "mattgmak/pi-lens"]`).
- **Pi extensions**: thin loader dir `dendritic/home-modules/pi-coding-agent/extensions/<name>/` — `package.json` (`pi.extensions: ["./index.ts"]`, optional `pi.skills`) + `index.ts` re-export `../vendor/<Owner>/<repo>/…`. Pi resolves loader imports against live `~/.pi/agent/extensions/<name>/` — depth fixed at 1 up, lands on `extensions/vendor` compat symlink → repo root `vendor/`. Submodule never inside `extensions/`.
- **Themes**: symlink `…/themes/<name>.json` → `../../../../vendor/<Owner>/<repo>/…`.
- **Skills**: symlink `dendritic/skills/<name>` → `../../vendor/<owner>/<repo>/…`.
- `pi-npm-i` installs vendor extension deps; skips non-extension repos (themes/skills/zen/tools) + special-cases `lean-ctx`, `pi-packages`, `fgladisch/pi-extensions`, `engram`, `pi-cursor-sdk` (`npm ci --ignore-scripts` + `build.mjs` → `dist/`).

New vendored repo: `git submodule add <url> vendor/<owner>/<repo>`, rename `.gitmodules` name → `owner/repo` if git used path. Full workflow + fork handling: `dendritic/skills/pi-setup/REFERENCE.md`.

## Commit convention

- **Subject only** — one line, no body unless explicitly requested
- Imperative mood, capitalize first word (e.g. `Generate pi themes from Stylix palette.`)
