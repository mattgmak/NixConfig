# Language: Simplified Technical English (ASD-STE100)

Every reply, file prose, and commit message uses ste style. The agent-ste
extension lints the write. A hard fault blocks it.

Write each sentence in one draft:

- Simple tenses only. Active voice.
- One sentence = one thought. 20 words for a reply, 25 for file prose.
- Replace each ban-phrase word with its approved partner: `start`, `use`,
  `show`, `fix` — not `spin up`, `utilize`, `indicate`, `address`.
- Split a semicolon into two sentences while you draft.

Before the write lands, run `ste_lint` on the draft text. Fix every fault. Done =
zero hard faults. No suppression comment exists: the engine holds no such
directive. To relax a rule, set its severity in `.ste.json` at the project root:

```json
{ "rules": { "length/sentence": "soft" } }
```

The file reads once, at session start. A rule reads `hard`, `soft` or `off`.
A project file wins over `~/.config/ste/config.json`.

Maintenance: keep this section short. A stale line goes out during review.

# General

- CRITICAL: Verify symbols, fn names, config options, module paths, CLI flags, API
  fields against actual source/docs before use. NEVER guess unseen symbols.
- Question → answer only. No coding, no files. Tools/scripts OK if needed for answer.
- No bloated code comments. Only terse comments when necessary.
- Illustrate architecture, flow, or state with a ```mermaid fence. Pi renders it. Use
  one diagram per answer, and only when prose runs past ~10 lines. Keep nodes under
  ~8: the fence source still bills tokens. In an erDiagram, write one attribute per
  line: several attributes on one line break the render.

# Running commands

- Shell grep always `rg` over `grep`. Faster.
- NEVER `find` on `/`, `/nix`, `~` — never completes, may crash terminal.
- Never prefix a command with `sleep`. `bash` blocks a wait of 3 s or more
  (extension `shell-wait-guard`). Run long work with `bg_bash`, then end the turn:
  the result wakes you. To wait for a condition, use a blocking form such as
  `gh run watch`, `simctl bootstatus -b`, or `tail -f --pid`.
- No lint/format/type checks — Pi runs them, reports all errors on finish. Tests/other checks OK.

# Large output

- Big output (builds, test runs, CI dumps) → redirect once:
  `cmd > $TMPDIR/agent-tmp/<project>/x.log 2>&1`, check exit code, then `rg` or a
  bounded `read` on the file.

# Codemode

- Batch independent tool calls → codemode (Promise.allSettled/chain), not many separate calls.
- Large output → filter in codemode before returning.

# Temporary files

- One-off scripts/data → `$TMPDIR/agent-tmp/<project_name>`. No inline scripts — write reusable file, run after.
- NEVER delete from `$TMPDIR/agent-tmp/`

# File ops + paths

- Same content, different path → `mv`, not Write tool.
- Revert own file changes → git, not re-edit.

# Git

- Create and manage git worktrees with `wt` (worktrunk) always. Do not use raw `git worktree`.
- NEVER mutate PRs — merges, closes, approvals, admin bypass (`gh pr merge`, `gh pr close`, `gh pr review --approve`, `gh api .../pulls/.../merge`) unless explicit same-session request. Stop + ask first.
- NEVER modify previous commits or make commits unless explicitly asked.
- Commits: see the project file. "Subject only, empty body" applies where no project rule
  says otherwise.
- Explicit message → explain WHY: problem solved, design decision, context not visible in code. No test lists, no "works" claims — presupposed.
