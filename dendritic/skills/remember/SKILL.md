---
name: remember
description: >
  Persist facts, preferences, decisions, and project conventions into Engram's cross-session memory.
  Use when the user says "remember this", "note that", "save this for later", states a preference, makes a decision, clarifies a constraint, corrects you about the project, or shares any durable information worth persisting across sessions.
---

# Remember

Store conversation-derived facts into Engram so they survive session restarts and compaction.

## When to trigger

Trigger auto (no need to ask user):

- User states preference: "I prefer X over Y", "my style is Z"
- User makes decision: "let's use X", "we decided Y"
- User shares project knowledge: "this project uses X auth", "the convention is Y"
- User corrects you about the project: "actually we use X, not Y"
- User says anything flag-worthy: "important: ...", "keep in mind ...", "note that ..."

Also trigger on explicit commands:

- "remember this", "remember that", "note this", "save this"
- "don't forget ..."
- "store that somewhere"

## Types

Pick the closest Engram `type`:

| Type | What goes there |
|------|----------------|
| `pattern` | Coding style, naming, formatting rules, project idioms |
| `architecture` | System design, module boundaries, data flow |
| `decision` | API contracts, library choices, auth approach, error shapes |
| `config` | CI/CD, infra, env config, deployment setup |
| `preference` | Personal or team preferences that outlast one task |
| `discovery` | Non-obvious codebase facts, gotchas, edge cases |
| `learning` | General lessons worth recalling later |

Use `scope: project` (default) for repo-specific facts. Use `scope: personal` for user-specific preferences that should follow them across projects.

## How to store

Use the `mem_save` MCP tool:

```
mem_save(
  title: "Prefer function components over class components",
  type: "pattern",
  scope: "project",
  topic_key: "conventions/react-components",
  content: """
**What**: Use function components with React Query for data fetching.
**Why**: User stated this as the project convention.
**Where**: Frontend components generally.
**Learned**: No class components; no Jest.
"""
)
```

Before saving evolving topics, get a stable key:

```
mem_suggest_topic_key(type: "pattern", title: "React component convention")
```

Reuse the same `topic_key` when updating an existing topic (upsert). Use `mem_update` when you already know the observation ID.

If `mem_save` returns `judgment_required: true`, inspect `candidates[]` and call `mem_judge` for each pending relation.

Fallback (if MCP tool unavailable):

```bash
engram save "<title>" "<content>" --type <type> [--scope project|personal] [--topic <topic_key>]
```

## What to capture

Include enough context so the fact is useful on its own. Use the **What / Why / Where / Learned** structure:

- **Preference**: what, why (if stated)
- **Decision**: what was chosen, alternatives considered (if stated), rationale
- **Constraint**: specific bounds or rules
- **Correction**: what was wrong, what the right answer is

OK:

```
title: "Testing stack preference"
topic_key: "conventions/testing"
content:
  **What**: Vitest for unit tests, Playwright for e2e.
  **Why**: User preference; no Jest.
  **Where**: Test setup across the repo.
  **Learned**: Prefer integration-style tests over pure unit tests.
```

Not OK:

```
title: "testing"
content: "uses vitest"
```

## Recalling later

When the user asks to remember/recall something already saved:

1. `mem_context` — recent session history (fast)
2. `mem_search` — FTS5 keyword search if not found
3. `mem_get_observation` — full content for a match
