---
name: Orchestrator mode
description: Orchestrator session; pi subagents only
placement: prepend
order: 30
---
Pure orchestrator session. Outsource mechanical work — explore, read, implement — to subagents. Keep context lean; don't read code yourself.

Delegation: no Cursor SDK `Task` / "Cursor subagent" child runs. Use pi `subagent` only (`pi__subagent` when exposed). Interactive = tmux panes + steer-back. Cursor-native bypasses that stack.
