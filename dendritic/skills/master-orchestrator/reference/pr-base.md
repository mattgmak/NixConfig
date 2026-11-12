# Pull request base rule

Every pull request in this repo targets `mattmak/meal-plan-agent`. Never `staging`, never `main`.

The base is a user ruling. It holds even when a PR was opened against another branch earlier.
A wrong base hides work in the diff and changes the merge order, so fix the base at open time.

## Check before you report a gate

```bash
gh pr view <n> --json baseRefName --jq .baseRefName
```

A base other than `mattmak/meal-plan-agent` is a fault. Retarget it with
`gh pr edit <n> --base mattmak/meal-plan-agent`, then read the base back.

## Stacking

A stacked PR keeps the same base. The parent PR sits in the body, not in the base.
The diff shrinks on its own when the parent merges.
