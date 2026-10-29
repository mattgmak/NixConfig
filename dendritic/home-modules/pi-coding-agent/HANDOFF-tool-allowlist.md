# Handoff: tool-allowlist gaps

## Purpose of the extension

`extensions/tool-allowlist/index.ts` caps the tools each pi session declares.
It calls `pi.setActiveTools()` with only the `ALLOWED_TOOLS` names.
It re-applies on `session_start`, `session_tree`, `mcp_servers_change`, and
`before_agent_start`. The cap is global for the user. Interactive sessions and
subagents share it. A subagent profile cannot re-add a stripped tool.

## The problem

The list is a manual allowlist. A new or renamed tool stays invisible until
someone notices. Nothing fails loudly. The session just lacks the tool.

Omission history:

| Date | Commit | Missing tool |
|---|---|---|
| 2026-10-09 | `dfbbfe1` | list created. `ask_user_question` omitted from birth |
| 2026-10-23 | `04f3664` | `subagent_stop` added after a complaint |
| 2026-10-27 | `e3a7cc2` | `ctx_bg` added after a complaint |
| 2026-10-29 | this change | `ask_user_question` added |

## Open items

1. `ste_lint`: `AGENTS.md` tells agents to run it before every write. The tool
   is not in `ALLOWED_TOOLS`, so agents cannot call it. Decide: allow the tool,
   or drop the instruction and rely on the extension hook alone.
2. lean-ctx registers `ctx_edit`, `ctx_ls`, and `lean_ctx`. All three stay
   blocked. Confirm this is intent, not drift. `ctx_patch` replaces `ctx_edit`.
3. `pi-session-tools`: only `read_session` passes. Six siblings stay blocked.
   Confirm the choice.
4. `pi-web-access`: `web_search` passes. `web_fetch` and `web_enable` stay
   blocked. Confirm the choice.
5. Consider a startup check that logs registered-but-blocked tool names. One
   line per session start would end the silent-omission pattern.

## Deliberate blocks (keep)

- `read` and `bash`: lean-ctx `ctx_read` and `ctx_shell` replace them.
- All raw MCP tools: the single `mcp` gateway tool fronts every MCP server.
  This saves the most prompt tokens.
