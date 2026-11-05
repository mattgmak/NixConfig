## PR checks and conflicts

A pull request at the gate holds three states. Read all three. A lane report is not one of them.

```bash
gh pr checks <pr>
gh pr view <pr> --json mergeable,mergeStateStatus
gh api graphql -f query='{repository(owner:"DrPOM-Medical",name:"tcm"){pullRequest(number:<pr>){reviewThreads(first:50){nodes{isResolved}}}}}' --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)]|length'
```

| Result | Action |
|---|---|
| a check reads `fail` | run `gh run view <run-id> --log-failed`, name the failing job and test, send it to the lane |
| `mergeable` reads CONFLICTING | send the rebase steps: fetch, rebase onto the base head, take the delete on a deleted file, force-push with `--force-with-lease`. A stacked branch rebases onto its new base, not onto the old lower branch |
| the thread count is above zero | run the CodeRabbit loop |
| all pass, MERGEABLE, zero threads | report the gate |
| the body holds no `## Evidence` or `## Verification` block, and the diff touches UI, Convex code, or app logic | send the evidence brief from section 16 |

Rules for a red check:

- A green local gate with a red CI run is a failed lane. Say so in the message.
- Send the failing job, the test name, and the run url. Never send the whole log.
- The `ci` check runs the turbo pipeline. Its error names a task, for example `tcm-app#test:unit`. Pass the task name to the lane.

Rules for a stale artifact or a moved base:

- Re-read all three states after every lane push. A fix can turn one green and another red.
- A generated artifact stale against new data fails a repo test. Tell the lane to run the generator that the test runs. Never edit the test.
- The base moves. A pull request that read MERGEABLE an hour ago can read CONFLICTING now.
