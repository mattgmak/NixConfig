## Lane watch

One `ctx_bg` job watches each open lane. Name the job `lane-watch #<pr>`.

```text
ctx_bg {
  name:    "lane-watch #152",
  command: "bash ~/NixConfig/dendritic/skills/master-orchestrator/watch-lane.sh 152 DrPOM-Medical/tcm 3000",
  wake_on: "^(FOUND|CONFLICT|MERGED|CLOSED) ",
  timeout_ms: 3300000
}
```

The script prints one state line first, then exits. Read the line and act.

| Line | Meaning | Action |
|---|---|---|
| `STANDING n` | unresolved threads at start | sweep them before you trust a clean gate |
| `FOUND n` | new unresolved CodeRabbit threads | send each thread to its lane: file, line, fault, fix |
| `CIFAIL` | a check turned to `fail`, or a watched pull request starts red | read the failing job, give its lane the error line |
| `CONFLICT` | `mergeable` reads CONFLICTING | send the rebase steps |
| `MERGED` | the pull request merged | unstack, sweep, set the ticket to Done |
| `CLOSED` | closed with no merge | ask the user |
| `RATE_LIMIT` | CodeRabbit reports a limit | note the limit. The watch keeps looking for `MERGED` and `CONFLICT`. The line does not wake you |
| `TIMEOUT` | no new state inside the window | report the pull request at the gate |

Every state exits 0, because a merge is the result and not a fault. Only an unreadable pull request exits 1 with an `ERROR` line.

Rules:

- Start one watch when the first lane opens a pull request, and add each later number to the list.
- A merged pull request leaves the list. Start the job again with the rest.
- Restart the watch after each lane push that resolves threads.
- Read the three gate states by hand after a wake. The line is a trigger, not a verdict.
- Never poll by hand, never sleep, never tail a log. The job holds the loop.
- A `MERGED` line starts the cleanup turn. Unstack the pull requests above it, remove the worktree, kill the lane session, and set the ticket to Done.
- The script window is 3000 s and `timeout_ms` is 3300000. The job limit of 60 minutes kills a longer window, so keep the window under it.
- A job that exits 124 hit its job limit. Start the watch again with a fresh window.
- A job id can expire and leave its process running. Before a restart, clear the process and check the count.
- Clear a watcher with a bracket pattern: `pkill -f 'watch-lanes[.]sh'`. A plain pattern matches the command line of the shell that runs it, and the shell then kills itself with exit 143.
- The shell policy denies a pipe to `xargs`. Kill with `pkill` alone, and read the count with `pgrep -cf 'watch-lanes[.]sh'`.
- A lost job reports `not found or expired` and holds no result. Read the three gate states by hand, then start a fresh watch with `unique: true`.
- `ctx_bg` reuses the id of an identical command. So an expiry message can name an earlier instance. Run `status` on the id before a restart, and pass `unique: true` on a start so each watch holds its own id.

`watch-coderabbit.sh` stays for a CodeRabbit-only watch. `watch-lane.sh <pr>` covers one pull request. `watch-lanes.sh` covers the whole wave with one job.
