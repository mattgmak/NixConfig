## Lane watch

One `ctx_bg` job watches the whole wave, by branch name. Start it in the same turn as the first lane spawn, not when the first pull request opens. A branch with no pull request yet prints `PR_OPEN` when the request appears, so the watch covers the wait before it.

```text
ctx_bg {
  name:      "watch wave",
  command:   "bash ~/.pi/agent/skills/master-orchestrator/scripts/watch-wave.sh <branch> [<branch> ...] --window 3000",
  wake_on:   "^(PR_OPEN|CLEAN|STATE|CIFAIL|MERGED|CLOSED) ",
  timeout_ms: 3300000
}
```

The script owns its own deadline, so it exits before the job limit. A window of 3000 s ends the loop at 2880 s and prints `TIMEOUT`. Pass a window below `timeout_ms` minus a 120 s margin.

| Line | Meaning | Action |
|---|---|---|
| `PR_OPEN n` | the lane opened the pull request, or the watch restarted | read the three gate states |
| `CLEAN n` | `mergeable` reads CLEAN | read the checks by hand before you trust it |
| `STATE n DIRTY` | a conflict, a behind branch, or branch protection | give the lane the rebase steps |
| `CIFAIL n` | a check reads `fail` | give the lane the error line |
| `MERGED n` | the user merged | clean up, then unstack the requests above it |
| `CLOSED n` | closed with no merge | ask the user |
| `TIMEOUT` | no change inside the window | report the pull request at the gate |

### One job per pull request

The default is one job per branch, because the jobs widget then shows each pull request on its own row. Each job carries one branch name.

| Case | Jobs |
|---|---|
| one pull request | one job, named `watch <ticket> #<pr>` |
| three requests from one wave | three jobs, one branch each |
| a short wave you watch by hand | one job with a branch list |

The job ends itself with `DONE every branch merged or closed` when `--all-merged` is set. Cancel a job whose request closed with no merge, then ask the user.

Give each start its own `unique: true`, and pass `cwd`. A start that takes the session cwd fails once its worktree leaves the disk.

Rules:

- One job per branch. Never run two jobs for one branch.
- Restart the watch in the same turn as any lane push, with `unique: true`.
- Never poll by hand, never sleep, never tail a log.
- A job that dies at exit 124 outran its limit. The script now cannot, so an exit 124 means an older script ran.
- Read the three gate states by hand after a wake. The line is a trigger, not a verdict.

Rules:

- Start one watch when the first lane opens a pull request, and add each later number to the list.
- A merged pull request leaves the list. Start the job again with the rest.
- Restart the watch after each lane push that resolves threads.
- Read the three gate states by hand after a wake. The line is a trigger, not a verdict.
- Never poll by hand, never sleep, never tail a log. The job holds the loop.
- A `MERGED` line starts the cleanup turn. Unstack the pull requests above it, remove the worktree, kill the lane session, and set the ticket to Done.
- The script window is 3000 s and `timeout_ms` is 3300000. The job limit of 60 minutes kills a longer window, so keep the window under it. Keep a 60 s margin between the loop and `timeout_ms`. A loop of 120 ticks at 60 s runs 7200 s, so the job dies at the limit with exit 124. A job that exits 124 ran its loop past `timeout_ms`, so shorten the loop, not the margin.
- A job that exits 124 hit its job limit. Start the watch again with a fresh window.
- A job id can expire and leave its process running. Before a restart, clear the process and check the count.
- Clear a watcher with a bracket pattern: `pkill -f 'watch-lanes[.]sh'`. A plain pattern matches the command line of the shell that runs it, and the shell then kills itself with exit 143.
- The shell policy denies a pipe to `xargs`. Kill with `pkill` alone, and read the count with `pgrep -cf 'watch-lanes[.]sh'`.
- A lost job reports `not found or expired` and holds no result. Read the three gate states by hand, then start a fresh watch with `unique: true`.
- `ctx_bg` reuses the id of an identical command. So an expiry message can name an earlier instance. Run `status` on the id before a restart, and pass `unique: true` on a start so each watch holds its own id.

`watch-coderabbit.sh` stays for a CodeRabbit-only watch. `watch-lane.sh <pr>` covers one pull request. `watch-lanes.sh` covers the whole wave with one job.
