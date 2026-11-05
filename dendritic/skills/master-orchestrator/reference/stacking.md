### Stack a dependent branch

A lower pull request waits at the gate. A higher ticket needs its code. Stack the higher branch on the lower branch head. Do not hold the higher lane.

```bash
git fetch origin <lower-branch>
git -C <worktree> reset --hard origin/<lower-branch>
gh pr create --base <lower-branch> --head <higher-branch> --title "<ticket id>: <title>"
```

Name the chain in Linear on both tickets. Write the chain bottom first, for example `#152 <- #160`.

Rules:

- One dependency level per stack. A three-deep chain waits for a user word.
- A reviewer reads the diff against the lower branch. Call that verdict provisional.
- Only the bottom pull request names `mattmak/meal-plan-agent` as its base.

### Unstack after a merge

The lower pull request lands. Retarget and rebase the higher branch in the same turn.

The `MERGED` line from the lane watch starts this step. Do not wait for a lane report.

```bash
git fetch origin
git -C <worktree> rebase origin/mattmak/meal-plan-agent
git -C <worktree> push --force-with-lease
gh pr edit <pr> --base mattmak/meal-plan-agent
```

Then run the lane gates, spawn a fresh review on the new diff, and read all three gate states. A provisional verdict does not carry.

### Fix a conflict

1. Read both sides. Name the fact each side adds.
2. Keep the union. Never take one side blind, and never drop another ticket's work.
3. Where the two sides disagree on a rule, stop and escalate. A conflict is not a licence to change a contract.
4. Run the gates after the resolve.
5. Force-push with `--force-with-lease`.
