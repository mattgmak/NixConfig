---
name: pi
description: >
  Delegate coding work to pi. Use when a Hermes task needs NixConfig file
  edits, Nix module work, or a diff review. Runs `pi-local` in print mode and
  reads its stdout.
---

# pi (NixConfig coding worker)

Hermes owns delegation. One `pi-local` run does one task and answers in one turn. pi has no subagents and cannot ask questions back.

## Run it

    pi-local -p "<full brief>" > /tmp/pi-out.md 2>/tmp/pi-err.log

stdout holds the final text. stderr holds errors. A nonzero exit means the run failed. Write one complete brief, because pi cannot ask a follow-up in print mode. For a long brief, put the text in a file and pass it: `pi-local -p "$(cat brief.md)"`.

## Flags

| Flag | Use |
|---|---|
| `--append-system-prompt <file>` | Give pi a role file, for example a review brief |
| `--system-prompt <file>` | Replace the default coding prompt |
| `--model <provider/id>` | Pick a model. The default is `ramsay/halogen-flash-next-signal-abliterated` |
| `--no-session` | Skip session files for a throwaway run |
| `--resume <id>` | Continue an earlier session |
| `--tools read,bash,edit,write` | Narrow the tool set |
| `--exclude-tools <names>` | Drop single tools |

## Worktree rule

pi edits files only. It never deploys. Use the `deploy` skill for the switch. Run pi inside a worktrunk worktree and keep the main checkout clean:

    cd <worktree> && pi-local -p "<brief>"

## Check the result

1. Read stdout. It holds the answer or the change summary.
2. Run `git -C <worktree> diff --stat` to confirm the scope.
3. Report the diff. The user decides the deploy.

## Failures

| Symptom | Cause | Fix |
|---|---|---|
| `model not found` | llama-swap down or `models.json` missing | Check `curl http://127.0.0.1:9292/v1/models` |
| Empty stdout, exit above 0 | Error text went to stderr | Read the stderr file |
| `pi-local: not found` | Package missing from the service PATH | Check `services.hermes-agent.extraPackages` |
| Long stall | Local inference on a big prompt | Shorten the brief or narrow `--tools` |

## Limits

- No answer to `ask_user_question`: print mode has no UI to reply.
- No subagents: this pi has no `pi-interactive-subagents` extension.
- No MCP servers: the wrapper passes `--no-mcp`.
- One task per run. Start a second run for a second task.
