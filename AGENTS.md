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
- **Hermes skills**: plain file `dendritic/nixos-modules/hermes-skills/<name>/SKILL.md`, registered in `hermes.nix` `hermesHomeFiles`. Never a symlink, never under `dendritic/skills/`.
- `pi-ext-deps-install` installs vendor extension deps; skips non-extension repos (themes/skills/zen/tools) + special-cases `lean-ctx`, `pi-packages`, `fgladisch/pi-extensions`, `engram`, `pi-cursor-sdk` (`npm ci --ignore-scripts` + `build.mjs` → `dist/`).
- **System switch/rebuild**: always defer to user to manually do switch/rebuild via `nh` for the current machine.
- **Change stays invisible until you bump the pin**: an eval reads a source through its pinned reference — a submodule pointer, a `flake.lock` input, a `url = "git+file:..."` entry. Fix every layer in order: commit and push the source repo, then `nix flake update <input>`, then commit `flake.lock`. Symptom: the new option or attribute "does not exist" while the file on disk shows the change.

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

## Repo locations

`/home/agent/NixConfig` is the source of truth on Ramsay. Other paths reach it, and none hold a second copy.

| Path | Form | Owner |
| --- | --- | --- |
| `/home/agent/NixConfig` | the checkout | `agent:users`, group-writable, setgid, `core.sharedRepository = group` |
| `/root/NixConfig` | symlink | tmpfiles |
| `/var/lib/hermes/NixConfig` | symlink | tmpfiles |
| Goofeus `/root/NixConfig` | symlink to the built source store path | `scripts/deploy-goofeus.sh` |
| MacMini `/Users/mattgmak/NixConfig` | own checkout | macOS, separate |

`NH_OS_FLAKE=/root/NixConfig` now resolves to the agent checkout, so `nh` as root and `nh` as agent build the same tree.

1. One working directory holds one branch. Two people or two agents need two worktrees. One index serves the whole checkout, so `git add -N` by one user changes what another user builds.
2. The old root and hermes clones must go before the switch: `systemd.tmpfiles` cannot replace a directory with a symlink.
3. `hermes` joins group `users` for traversal. `programs.git.config.safe.directory = "*"` replaces the per-script `-c safe.directory=` flags.

## Worktree workflow

The user starts every pi session, either `pi` or `pi-local`. The agent never starts a session. Every new implementation runs in a fresh worktree. Run `wt switch --create <branch>` from the repo root. Use worktrunk (`wt`) only, never raw `git worktree`. Do not edit the `main` checkout in place.

The agent manages worktrees only: create one per task, keep the branch clean, and remove it after the merge. `wt` names each worktree `<repo>.<branch>` beside the repo, so every worktree inherits the shared group of `/home/agent`.

Shell integration is off on this host, so `wt switch` cannot change your working directory. Read the path, then `cd`:

```sh
wt switch --create fix-ramsay-agenix   # branch + worktree, based on the default branch
wt list --format json | jq -r '.[] | select(.branch=="fix-ramsay-agenix") | .path'
cd <path>
git submodule update --init            # the flake fetches every submodule
```

A fresh worktree has empty submodule directories, so every nix eval fails until you run `git submodule update --init` there. The main checkout holds the submodule git dirs, so the update needs no download.

A worktree is a separate flake ref. Nix copies its tree once and reuses that copy for every eval in the branch. Sandbox logs stay per session. Two agents work at the same time without touching each other's tree. `main` moves only when the approval script merges, so the shared checkout never holds a half-finished commit.

`scripts/host-sandbox.sh` resolves the flake with `git rev-parse --show-toplevel`, so it verifies the worktree you are in. Pass `--flake <path>` to point at another checkout.

### Change workflow

No PRs. `wt merge` squashes the branch and fast-forwards `main`, so `main` moves only in step 9.

| Step | Owner | Command |
| --- | --- | --- |
| 1. Create worktree | agent | `wt switch --create <branch>` |
| 2. Edit the config | agent | — |
| 3. Track new files | agent | `git add -N <file>` |
| 4. Verify | agent | `bash scripts/host-sandbox.sh <host> --tier build` |
| 5. Fix and repeat | agent | rerun until exit 0 |
| 6. Commit | agent | `git commit -m "<subject>"` |
| 7. Open the approval pane | agent | `tmux split-window -h -P -F '#{pane_id}'`, then `send-keys` the command with no Enter |
| 8. Approve | user | press Enter in the pane |
| 9. Merge and push | script | `wt -C <worktree> merge main`, then `git push origin main` |
| 10. Deploy | script | `sudo ramsay-deploy-approve`, `sudo ramsay-deploy-switch`, then `scripts/deploy-goofeus.sh` for Goofeus |
| 11. Verify the live host | agent | pi gets the prompt the script sends into its pane |
| 12. Close | script | `tmux kill-pane` on its own pane |

`scripts/approve-and-deploy.sh <branch> --caller <pane-id>` runs steps 9-12. A failed step stops the run and keeps the pane open. Test it with `--dry-run`.

## Sandbox verification

Verify a host config before `nh` installs it. Never verify by switching the machine you are on.

```sh
bash scripts/host-sandbox.sh ramsay --tier eval   # eval errors and option warnings
bash scripts/host-sandbox.sh ramsay               # eval, then build the closure nh installs
bash scripts/host-sandbox.sh --all --tier eval    # every host in one pass
bash scripts/host-sandbox.sh macmini              # darwin from Linux: module check only
bash scripts/host-sandbox.sh ramsay --tier vm     # build the QEMU image; --vm-boot boots it
```

| Tier | What it checks | Cost |
| --- | --- | --- |
| `eval` | Nix eval errors, option warnings, undeclared option names | 38 s for the first host of a tree, then cached |
| `build` | Every compile error in the closure `nh os switch` installs | instant when cached, else the full build |
| `vm` | Activation and boot failures a build cannot see | image build, then a headless QEMU boot with `--vm-boot` |
| `checks` | `nix flake check` on `dendritic/checks.nix`: host toplevels, VM images, the Ramsay VM test | seconds when cached, else the full eval |

Rules:

1. After any `.nix` edit, run the `eval` tier for the host you changed. Run `git add -N <file>` on new files first, because a git-mode flake hides untracked files.
2. Run the `build` tier before you propose a switch.
3. Run the `vm` tier when the change touches services, units, or activation scripts.
4. Exit code 0 means every check passed. `--json` prints one object per check. Logs stay in `${TMPDIR:-/tmp}/agent-tmp/NixConfig/<host>.<tier>.log`.
5. The script never activates a config and never runs `nh`. The user runs the switch (System switch/rebuild).
6. An off-platform host gets a weaker check. `macmini` on Linux checks the module set only, because nix cannot build `aarch64-darwin` there.

## Commit convention

- **Subject only** — one line, no body, no trailers (`Co-authored-by`, `Signed-off-by`, etc.) unless user explicitly requests one
- **Never** pass `git commit --trailer` or append attribution trailers for Cursor, agents, or tooling — not default, not "helpful"
- Use plain `git commit -m "$(cat <<'EOF' … EOF)"` — subject line only inside the heredoc
- Imperative mood, capitalize first word (e.g. `Generate pi themes from Stylix palette.`)

## Comments

- Fewest possible. Non-obvious *why* only — never *what*, no commented-out code, section banners, or change notes.
