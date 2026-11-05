## Sub-command: reflect

`/skill:master-orchestrator reflect` studies past subagent sessions and drafts skill changes. It starts no lane, opens no pull request, and touches no ticket.

Steps:

1. Spawn one `peer` on this repo. Give it the files to read: the most recent subagent sessions that this skill spawned. Default is 10 sessions. The user can name a count, a ticket or a date range.
2. Ask the peer for waste and for traps:
   - a lane that rebuilt a dev client
   - a lane that reported a gate it never ran
   - a brief that left a fact to guess
   - a watch that lapsed
   - a retry after a provider error
   - a proof no reviewer could read
   - a reviewer that mirrored the code under test
3. Ask for a table: finding, example, proposed change, target file, section. One example per finding, and it names the session file, the ticket and one short quote.
4. Send the user the table, one row per change. Wait for the word.
5. Apply only the approved rows. Write no line before that word.
6. Report each section you changed and each row you dropped, with its reason.

Rules:

- One finding needs one example. A change with no example stays a guess.
- A draft may touch `SKILL.md` and `reference/`. It touches no ticket and no code.
- The approval rule holds in every loop: `reflect`, `update`, and the fold of a single correction. Never write this skill before the user agrees.

## Sub-command: update

`/skill:master-orchestrator update` is a sub-command. It rewrites this file. It starts no lane, opens no pull request and touches no ticket.

Steps:

1. Read this file and the corrections from the last wave.
2. Fold each correction into the section it belongs to. Keep the section order and the voice.
3. Show the user the proposed change, section by section. Wait for approval.
4. Write the file after approval, and never before. This holds in every loop, including a mid-wave correction. Report each section you changed.
5. Leave a rule in place when the user rejects it, and say why it stays.

A wave session learns a new step, a new gate or a dead rule. Fold it into the file in the same turn. Do not hold a correction for the next update.

Ask the user first, every time.

Path: `dendritic/skills/master-orchestrator/SKILL.md`. Spawn a peer on `~/NixConfig` when the edit touches more than two sections.
