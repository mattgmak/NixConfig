---
name: work-on-linear-ticket
description: Spin up a worktree and Pi session for a Linear ticket from its git branch name. Use when user says "work on linear ticket", passes a branch like mattmak/prd-228-some-slug, or wants to start AFK work on a Linear issue.
argument-hint: "<branch-name> e.g. mattmak/prd-228-ai-chatbot-reached-limit-error-app-crash"
---

# Work on Linear Ticket

Create a worktree for a Linear-linked branch, fetch the issue, and launch Pi in a new session with a work prompt.

## Invocation

Requires a branch name argument in Linear's git-branch format:

```
mattmak/prd-228-ai-chatbot-reached-limit-error-app-crash
```

The slug after the `/` embeds the issue id (`prd-228` → `PRD-228`).

## Workflow

### 1. Parse the branch name

From the argument, extract the Linear issue identifier:

- Match `([a-z]+)-(\d+)` in the branch slug (the part after `/`)
- Uppercase the team prefix → `PRD-228`

If no match, stop and ask the user for a valid branch name or issue id.

### 2. Fetch the Linear issue

Use the Linear MCP `get_issue` tool with the extracted id (e.g. `PRD-228`).

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

Capture stdout/stderr. Parse the new worktree path from the output:

- Prefer `wt switch --format json` if you need reliable parsing — read `worktree_path` from the JSON
- Otherwise parse with the pattern `@ (?P<path>[^,\n]+)` (same as `gh-dash-pr-review.nu`)

Confirm the path exists before continuing.

### 4. Build the initial Pi prompt

Compose a single-quoted prompt for Pi. Include:

- Issue id and title
- Description / acceptance criteria from Linear
- Instruction to explore the codebase, implement the fix, and run relevant tests
- Any linked PR context (if attached on the issue)

Keep it concise — Pi will fetch more context itself.

Example shape:

```
Work on Linear issue PRD-228: AI Chatbot -> Reached Limit -> Error / App Crash.

<description from Linear>

Explore the codebase, implement a fix, and verify with tests. Start by understanding how rate limiting and error handling work in the chatbot flow.
```

### 5. Launch the session

```bash
sesh connect <worktree_path> -c "pi '<initial_prompt>'"
```

Use the parsed worktree path. Escape any single quotes inside the prompt (`'\''`).

Report back: issue id, worktree path, and that the Pi session was launched.

## Error handling

| Failure | Action |
|---------|--------|
| Not in a git repo | Tell user to `cd` into the repo first |
| Linear issue not found | Show extracted id; ask user to confirm |
| `wt switch` fails | Show stderr; suggest `wt list` to inspect existing worktrees |
| Cannot parse worktree path | Re-run with `--format json` or ask user for the path |
| `sesh connect` fails | Show stderr; give the worktree path so user can connect manually |

## Example

```
/work-on-linear-ticket mattmak/prd-228-ai-chatbot-reached-limit-error-app-crash
```

1. Extracts `PRD-228`
2. Fetches issue from Linear
3. Runs `wt switch -b @ -c mattmak/prd-228-ai-chatbot-reached-limit-error-app-crash`
4. Parses worktree path (e.g. `~/wt/mono/mattmak-prd-228-...`)
5. Runs `sesh connect ~/wt/mono/mattmak-prd-228-... -c "pi 'Work on PRD-228: ...'"`
