---
name: checks-and-fixes
description: >
  Runs lint, typecheck, and tests per the repo's AGENTS.md and fixes failures scoped to
  the current working changes (staged/unstaged or branch diff). Use when the user asks to
  run checks, fix lint or type errors, get tests green, verify before commit or PR, or
  invokes /checks-and-fixes.
argument-hint: "[base ref e.g. main, or omit for unstaged+staged only]"
---

# Checks and Fixes

Run the project's quality gates and fix what **your working changes** broke. Do not chase unrelated pre-existing failures.

## Scope rule (critical)

**Working changes** = files touched by the current task:

| User / context | Scope command |
|----------------|---------------|
| Default (no base ref) | `git diff --name-only` + `git diff --cached --name-only` (union) |
| Branch vs base (e.g. `main`) | `git diff --name-only <base>...HEAD` |
| Explicit file list from user | That list only |

- **Fix** a failure when the reported file is in the working-change set, or when the failure is clearly caused by your edit (e.g. new import unused in a file you changed).
- **Do not fix** failures in files outside scope — list them under "Pre-existing (out of scope)" and stop if checks cannot pass without broad refactors.
- Do not "clean up" unrelated code, drive-by refactors, or repo-wide lint sweeps.

## Workflow

### 1. Orient from AGENTS.md

From the git root (`git rev-parse --show-toplevel`):

1. Read `./AGENTS.md` (repo root). If missing, also check the cwd — some monorepos document checks per package.
2. Extract:
   - **Check commands** — `pnpm run check`, `lint`, `test`, package-scoped scripts, `cargo test`, etc.
   - **Caveats** — e.g. "run from repo root", `pnpm --filter`, never `cd`, prefer `direnv exec`, use `tsgo` over `tsc`.
   - **Anti-rules** — e.g. AGENTS.md may say Pi auto-runs lint on turn end; **this skill explicitly runs checks now** because the user asked for a full gate.

If AGENTS.md names no commands, discover from `package.json` / `Makefile` / `justfile` scripts (`check`, `lint`, `test`, `typecheck`, `build`).

Use `direnv exec . <cmd>` when binaries are missing from PATH.

### 2. Pin working-change scope

Run the scope command from the table above. Keep the file list for triage.

Optional argument: user passes a base ref (`main`, `origin/main`, tag) → use three-dot diff against `HEAD`.

### 3. Run checks (in order)

Run **types → lint → tests** unless AGENTS.md orders differently or bundles them (e.g. `pnpm run check`).

- Prefer project-documented commands over guessing.
- Prefer `tsgo` over `tsc` when both exist.
- For edited files, `lens_diagnostics` / `lsp_diagnostics` can supplement CLI checks — but still run the repo's canonical commands before declaring success.
- Do not pipe checks through `tail`/`head` (masks exit status). Run unpiped.

Record pass/fail per gate.

### 4. Triage failures

For each failure:

1. Is the file (or direct cause) in the working-change set?
2. **Yes** → fix minimally (match repo style; no semantic changes unless required to fix types/tests).
3. **No** → add to "Pre-existing (out of scope)"; do not edit that file.

Lint-only fixes in scope: prefer real fixes over blanket `eslint-disable`. No removing defensive checks or altering control flow to silence lint.

### 5. Re-run until green or blocked

After each fix batch, re-run the failing gate(s). Stop when:

- All gates pass, or
- Remaining failures are out of scope (report and ask user), or
- The same error repeats after two different approaches (report blocker).

### 6. Report

```markdown
## Checks and fixes

**Scope:** <N> files — <how scoped>
**AGENTS.md:** <commands used>

| Gate | Result |
|------|--------|
| Types | pass / fail |
| Lint | pass / fail |
| Tests | pass / fail |

### Fixed (in scope)
- `path` — <what>

### Pre-existing (out of scope)
- `path` — <error summary> (not fixed)

### Blocked
- <only if you could not get in-scope work green>
```

## Guardrails

- **Minimal diffs** — fix only what failures require; no drive-by refactors.
- **No commit** unless the user asked to commit.
- **No `--no-verify`** to bypass a gate that actually failed — only when AGENTS.md documents hook-install failures.
- **Monorepos** — use package-scoped commands from AGENTS.md (`pnpm --filter`, `cargo -p`, etc.); run from the documented root.
- **Background agents** — if delegating fixes, include the scope file list and "no semantic changes" in the prompt.

## Quick example

```
/checks-and-fixes main
```

1. Read `AGENTS.md` → `pnpm run check` = lint + types; `pnpm run test` for tests.
2. Scope: `git diff --name-only main...HEAD`.
3. Run checks; fix errors only in scoped files.
4. Re-run until pass or out-of-scope list is the only remainder.
