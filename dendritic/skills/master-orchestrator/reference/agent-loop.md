## Agent loop

One wave spent 39 gate runs, 24 turns, and 8 steers on one ticket. This file holds the loop that stops that. `SKILL.md` links here from sections 4, 6 and 16.

### Report contract

A lane replies once per phase, in three lines. Detail goes into a report file.

Phases: `plan`, `code`, `gate`, `evidence`, `pr`. A phase change earns one reply. A command result inside a phase earns none.

`scripts/lane-report.sh <lane> <phase> "<summary>"` opens the file and prints the three-line shape:

```text
1. <what changed, one line>
2. head <sha>, gates: <name exit> <name exit> ...
3. next: <one step>, or done
```

Six fields go in the file, never in the chat:

| Field | Content |
|---|---|
| Head | the sha the facts describe |
| Changed files | count, plus any file a reviewer must read |
| Gate exits | one line per gate, from the cache |
| Evidence | artifact name, screen, and the one line each proves |
| Blockers | a named fault with the file and the line |
| Next step | one action |

The master reads the file only when a fact is missing from the three lines. A lane that pastes a diff or a file body into the reply wastes both contexts.

### Gate cache

Run the gate block once per head. Then read it.

`scripts/gate-cache.sh` runs `check-types`, `biome` on the changed files, and one test command. It writes `/tmp/agent-tmp/<project>/gates/<head>.json`. A second call at the same head prints the cache and runs nothing. `--read` prints the cache alone. `--force` runs again.

Rules:

- A lane runs the cache once, at the head it reports.
- A lane that changes a file gets a new head, so it runs once more.
- `ci` runs once, at the final head, and no other turn.
- The master reads the cache instead of asking for an exit code.

### Steer budget

One steer per phase. A lane that misses the report contract gets one steer with the exact remaining steps and the three-line shape.

A second miss means the lane is wrong for the work. Stop it, save the tree, and spawn a fresh lane with a narrower brief.

Two lanes hit the 120-minute exit limit in one wave. A lane that runs past 60 minutes gets a narrowed brief, not a nudge.

### Token rules

| Side | Rule |
|---|---|
| Master | read no project source. Send a code question to a scout with the file and the question |
| Master | name the base and the head once. A brief carries no second copy |
| Lane | batch independent reads and searches in one `codemode` call |
| Lane | keep image bytes out of context. Measure with `magick`, `md5sum`, `identify` |
| Lane | paste 3 lines, and put 6 fields in the report file |
| Both | quote the failing line alone, not the command output block |

### Surfaces

| Profile | Surfaces | Use |
|---|---|---|
| `peer` | `window`, `new-session` | a ticket that opens a pull request |
| `worker` | `pane`, `window` | small work with no pull request |
| `code-reviewer` | `window` | one branch review |

A `worker` cannot take `new-session`, so a call with it fails before the lane starts.

### Failure protocol

| Fault | Action |
|---|---|
| provider error, or an operation aborts | stop the lane, report the error, start no blind retry |
| 120-minute exit limit | read the tree state, then respawn with a narrower brief |
| a lane that idles between turns | give one foreground command that blocks, and forbid a reply before it returns |
| a lane that reports a fact it did not read | ask for the command and its exit code, and run the cheap check yourself |

### Cheapest checks

Three facts cost one command each. Each one caught a false claim in one wave:

```bash
git -C <worktree> rev-parse --short HEAD
git -C <worktree> status --porcelain
gh pr view <n> --json headRefOid,mergeStateStatus --jq '.headRefOid[0:8], .mergeStateStatus'
```
