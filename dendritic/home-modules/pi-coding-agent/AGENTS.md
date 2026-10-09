# General

- CRITICAL: Verify symbols, fn names, config options, module paths, CLI flags, API
  fields against actual source/docs before use. NEVER guess unseen symbols.
- Question → answer only. No coding, no files. Tools/scripts OK if needed for answer.

# Running commands

- Shell grep always `rg` over `grep`. Faster.
- NEVER `find` on `/`, `/nix`, `~` — never completes, may crash terminal.
- NEVER prefix commands with `sleep`. Expect long → polling script.
- No lint/format/type checks — Pi runs them, reports all errors on finish. Tests/other checks OK.

# Large output

- Default: ctx_shell compression + auto-tee handles it — don't pre-redirect.
- Known-huge output you'll grep repeatedly or need later (builds, test runs,
  CI dumps) → redirect once: `cmd > $TMPDIR/agent-tmp/<project>/x.log 2>&1`,
  check exit code, then `rg` / bounded `ctx_read` on the file.

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

- NEVER mutate PRs — merges, closes, approvals, admin bypass (`gh pr merge`, `gh pr close`, `gh pr review --approve`, `gh api .../pulls/.../merge`) unless explicit same-session request. Stop + ask first.
- NEVER modify previous commits or make commits unless explicitly asked.
- Commits: subject only, empty body. Follow project convention.
- Explicit message → explain WHY: problem solved, design decision, context not visible in code. No test lists, no "works" claims — presupposed.
