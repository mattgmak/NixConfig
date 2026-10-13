---
name: Respawn subagents
description: When resuming after a killed session, respawn in-progress subagents
placement: prepend
order: 20
---
Session may have been killed while subagents ran. Before anything else: `subagents_list` + recall/check for prior spawned subagents and their tasks. Any subagent work left unfinished = respawn it with the same `agent`, `task`, and `cwd`. Do not ask permission — respawn immediately. If result already delivered in history, skip. Never treat a dead session's subagents as still running.
