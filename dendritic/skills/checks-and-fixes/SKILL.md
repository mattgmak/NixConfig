---
name: checks-and-fixes
description: >
  Run lint, typecheck, and tests per the repo's AGENTS.md. Fix failures scoped to
  current working changes (staged/unstaged or branch diff). Audit scoped files against
  AGENTS.md conventions (conditional-render style, React Compiler rules, db access
  patterns). Use when user asks to run checks, fix lint or type errors, get tests green,
  verify before commit or PR, or invokes /checks-and-fixes.
argument-hint: "[base ref e.g. main, or omit for unstaged+staged only]"
---

# Checks and Fixes

Run quality gates. Fix what **your working changes** broke. Don't chase unrelated pre-existing failures.

## Scope rule (critical)

**Working changes** = files touched by current task:

| User / context | Scope command |
|----------------|---------------|
| Default (no base ref) | `git diff --name-only` + `git diff --cached --name-only` (union) |
| Branch vs base (e.g. `main`) | `git diff --name-only <base>...HEAD` |
| Explicit file list from user | That list only |

- **Fix** failure when file in working-change set, or failure clearly caused by your edit (e.g. new import unused in file you changed).
- **Don't fix** failures outside scope → list under "Pre-existing (out of scope)"; stop if checks can't pass without broad refactors.
- No "clean up" of unrelated code. No drive-by refactors. No repo-wide lint sweeps.

## Workflow

### 1. Orient from AGENTS.md

From git root (`git rev-parse --show-toplevel`):

1. Read `./AGENTS.md` (repo root). Missing → check cwd; some monorepos document checks per package. Monorepos often have per-area docs (`apps/*/AGENTS.md`, `packages/*/AGENTS.md`, `CODING_STANDARDS.md`) — read one covering scoped files.
2. Extract:
   - **Check commands** — `pnpm run check`, `lint`, `test`, package-scoped scripts, `cargo test`, etc.
   - **Caveats** — "run from repo root", `pnpm --filter`, never `cd`, prefer `direnv exec`, use `tsgo` over `tsc`.
   - **Anti-rules** — e.g. AGENTS.md may say Pi auto-runs lint on turn end; **this skill explicitly runs checks now** because user asked for full gate.
   - **Conventions / pitfalls** — style + API rules scoped files must follow. Common ones to audit:
     - React Compiler enabled → no `useMemo` / `useCallback` added
     - Conditional render: `{cond && <X />}` not `{cond ? <X /> : null}` when else branch is null
     - `useEffect` dep rules + project's sanctioned ignore-comment pattern
     - DB/ORM access patterns (e.g. explicit table name as first arg to `ctx.db.get/patch/delete`)
     - Naming, import style, file structure rules in docs

No commands in AGENTS.md → discover from `package.json` / `Makefile` / `justfile` scripts (`check`, `lint`, `test`, `typecheck`, `build`).

Binaries missing from PATH → `direnv exec . <cmd>`.

### 2. Pin working-change scope

Run scope command from table above. Keep file list for triage.

Optional arg: user passes base ref (`main`, `origin/main`, tag) → three-dot diff against `HEAD`.

### 3. Run checks (in order)

**types → lint → tests** unless AGENTS.md orders differently or bundles them (e.g. `pnpm run check`).

- Prefer project-documented commands over guessing.
- Prefer `tsgo` over `tsc` when both exist.
- Edited files: `lens_diagnostics` / `lsp_diagnostics` supplement CLI checks — but still run repo's canonical commands before declaring success.
- No piping through `tail`/`head` (masks exit status). Run unpiped.

Record pass/fail per gate.

### 4. Audit conventions in scope

Each file in working-change set → check vs conventions from step 1 (`{cond && <X />}` over `{cond ? <X /> : null}`, no `useMemo`/`useCallback` under React Compiler, table-name-first DB calls). Violations = in-scope failures: fix like any gate failure, re-verify with repo lint/types. Use `rg` for targeted patterns (`\?.*: null`, `useMemo|useCallback`, `ctx\.db\.(get|patch|delete)\(`) — not repo-wide sweep. Files outside working-change set violating conventions = pre-existing; list, don't edit.

### 5. Triage failures

Per failure:

1. File (or direct cause) in working-change set?
2. **Yes** → fix minimally (match repo style; no semantic changes unless required to fix types/tests).
3. **No** → add to "Pre-existing (out of scope)"; don't edit that file.

Lint-only fixes in scope: prefer real fixes over blanket `eslint-disable`. No removing defensive checks or altering control flow to silence lint.

### 6. Re-run until green or blocked

After each fix batch → re-run failing gate(s). Stop when:

- All gates pass, or
- Remaining failures out of scope (report + ask user), or
- Same error repeats after two different approaches (report blocker).

### 7. Report

```markdown
## Checks and fixes

**Scope:** <N> files — <how scoped>
**AGENTS.md:** <commands used>

| Gate | Result |
|------|--------|
| Types | pass / fail |
| Lint | pass / fail |
| Tests | pass / fail |
| Conventions | pass / fail |

### Fixed (in scope)
- `path` — <what> (incl. convention violations, e.g. "ternary → `&&` conditional render")

### Pre-existing (out of scope)
- `path` — <error summary> (not fixed)

### Blocked
- <only if you could not get in-scope work green>
```

## Guardrails

- **Minimal diffs** — fix only what failures require; no drive-by refactors.
- **No commit** unless user asked.
- **No `--no-verify`** to bypass a gate that actually failed — only when AGENTS.md documents hook-install failures.
- **Monorepos** — package-scoped commands from AGENTS.md (`pnpm --filter`, `cargo -p`, etc.); run from documented root.
- **Background agents** — delegating fixes? Include scope file list + "no semantic changes" in prompt.

## Quick example

```
/checks-and-fixes main
```

1. Read `AGENTS.md` → `pnpm run check` = lint + types; `pnpm test` for tests; conventions noted from AGENTS.md.
2. Scope: `git diff --name-only main...HEAD`.
3. Run checks + audit conventions in scoped files; fix errors and violations only in scoped files.
4. Re-run until pass or out-of-scope list is only remainder.
