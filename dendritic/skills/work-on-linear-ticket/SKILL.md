---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> [implementation notes] e.g. mattmak/prd-239-dashboard-banner-add-url configurable openLink on press"
---

# Work on Linear Ticket

Create a worktree for a Linear-linked branch, fetch the issue, and launch Pi in a new session with a work prompt.

## Invocation

Requires a branch name in Linear's git-branch format. Optional text after the branch name is treated as implementation direction for the Pi prompt.

```
mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

The slug after `/` embeds the issue id (`prd-239` → `PRD-239`).

## Workflow

### 0. Preflight (shell allowlist)

Use `mcp_pi_shell` (or `mcp_pi_ctx_shell`) for all shell commands — native Shell may be unavailable.

`wt`, `sesh`, `tmux`, and `jq` are pre-allowed in the managed lean-ctx config (`home-modules/pi-coding-agent/lean-ctx/config.toml`). Agents **cannot** run `lean-ctx allow` to widen the shell allowlist — that is denied by pi-permission-system.

If a command returns `[BLOCKED — DO NOT RETRY]`, stop and ask the user to add the binary to `lean-ctx/config.toml` (then `/reload` or restart Pi). Do not retry blindly.

### 1. Parse the branch name

Split the user input: first token = branch name; remainder (if any) = optional implementation notes.

From the branch name, extract the Linear issue identifier:

- Match `([a-z]+)-(\d+)` in the branch slug (the part after `/`)
- Uppercase the team prefix → `PRD-239`

If no match, stop and ask the user for a valid branch name or issue id.

### 2. Fetch the Linear issue

In parallel with verifying the git repo (`git rev-parse --show-toplevel`), call Linear MCP `get_issue` with the extracted id (e.g. `PRD-239`).

Read title, description, status, labels, and any linked PRs. This becomes the work context.

### 3. Create the worktree

Run from the **current working directory** (must be inside the target git repo):

```bash
wt switch -b @ -c <branch_name>
```

If that fails because the branch already exists, fall back to:

```bash
wt switch <branch_name>
```

Capture stdout/stderr. Parse the worktree path from text output (do **not** use `--format json` — not supported by current `wt`):

- Primary pattern: `worktree @ <path>` (full absolute path)
- Fallback: `@ <path>` at end of a success line

Example line:

```
✓ Created branch mattmak/prd-239-... from staging and worktree @ /Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url
```

Confirm with `test -d <path>` before continuing.

### 4. Build the initial Pi prompt

Compose a single-quoted prompt for Pi. Include:

- Issue id and title
- Description / acceptance criteria from Linear
- **Implementation notes** from the user (if provided after the branch name)
- Instruction to explore the codebase, implement the fix, and run relevant tests
- Any linked PR context (if attached on the issue)

Keep it concise — Pi will fetch more context itself.

Example shape:

```
Work on Linear issue PRD-239: Dashboard -> Banner -> Add URL.

Can add URL for the banner?

Implement a configurable on-press open link URL for the dashboard banner. When users tap/press the banner, it should open the configured URL.

Explore the codebase, implement a fix, and verify with tests. Start by understanding how the dashboard banner is configured and rendered.
```

### 5. Launch the session (detached)

**Do not run `sesh connect`** — it always `switch-client`s when `$TMUX` is set and will yank you out of your current session.

Create the tmux session in the background instead (same mechanics sesh uses internally: `new-session -d`, then `send-keys`).

```bash
# 1) Reuse an existing tmux session already rooted at this worktree
session=$(sesh list -j | jq -r --arg p "$worktree_path" '.[] | select(.Path == $p and .Src == "tmux") | .Name' | head -1)

# 2) Otherwise derive the sesh-style git name (matches gitName + convertToValidName)
if [ -z "$session" ]; then
  main_root=$(git -C "$worktree_path" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  rel="${worktree_path#$main_root}"
  repo_parts=$(printf '%s' "$main_root" | tr '/' '\n' | tail -2 | paste -sd/ -)
  session=$(printf '%s%s' "$repo_parts" "$rel" | tr '.:' '__' | tr ' ' '_')
fi

# 3) Create detached session + start pi (skip -c if session already exists — same as sesh)
if tmux has-session -t "=$session" 2>/dev/null; then
  : # session already running at this worktree
else
  tmux new-session -d -s "$session" -c "$worktree_path"
  tmux send-keys -t "=$session" "pi '<initial_prompt>'" Enter
fi
```

Use the parsed worktree path. Escape any single quotes inside the prompt (`'\''`).

`tmux new-session -d` returns immediately and leaves your current tmux client untouched. Only treat non-zero exit or stderr as failure.

### 6. Report back

Give the user a short summary:

| Field | Value |
|-------|-------|
| Issue | `PRD-239` + title + Linear URL |
| Status | from Linear |
| Worktree | absolute path |
| Branch | branch name |
| Tmux session | session name (attach later with `sesh connect <worktree_path>` or `tmux attach -t <session>`) |

Confirm the Pi session was launched in the background. If launch failed, include the detached-launch commands as a copy-paste fallback.

## Error handling

| Failure | Action |
|---------|--------|
| Command blocked by shell allowlist | Ask user to add the binary to `home-modules/pi-coding-agent/lean-ctx/config.toml`; do **not** run `lean-ctx allow` |
| Not in a git repo | Tell user to `cd` into the repo first |
| Linear issue not found | Show extracted id; ask user to confirm |
| `wt switch` fails | Show stderr; suggest `wt list` to inspect existing worktrees |
| Cannot parse worktree path | Parse `worktree @ <path>` from stdout; or ask user for the path |
| `tmux` / `jq` / detached launch fails | Show stderr; give worktree path + session name + manual attach command |

## Example

```
/work-on-linear-ticket mattmak/prd-239-dashboard-banner-add-url do a configurable on press openLink url
```

1. Uses `wt` / `sesh` / `tmux` / `jq` (in managed lean-ctx allowlist)
2. Extracts `PRD-239`; notes → "do a configurable on press openLink url"
3. Fetches issue from Linear (in parallel with `git rev-parse`)
4. Runs `wt switch -b @ -c mattmak/prd-239-dashboard-banner-add-url`
5. Parses worktree path (e.g. `/Volumes/.../mono.mattmak-prd-239-dashboard-banner-add-url`)
6. Creates a detached tmux session and starts `pi 'Work on PRD-239: ...'` (does **not** switch your current session)
7. Reports issue link, worktree path, branch, and tmux session name
