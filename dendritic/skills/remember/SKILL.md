---
name: remember
description: >
  Persist facts, preferences, decisions, and project conventions into lean-ctx's cross-session project knowledge base.
  Use when the user says "remember this", "note that", "save this for later", states a preference, makes a decision, clarifies a constraint, corrects you about the project, or shares any durable information worth persisting across sessions.
---

# Remember

Store conversation-derived facts into the project knowledge base so they survive session restarts.

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

## Categories

| Category | What goes there |
|----------|----------------|
| `conventions` | Coding style, naming, patterns, formatting rules, project idioms |
| `architecture` | System design, module boundaries, data flow |
| `api` | API contracts, endpoints, auth, error shapes |
| `testing` | Test strategy, preferred frameworks, fixtures |
| `deployment` | CI/CD, infra, env config |
| `dependencies` | Library choices, versions, rationale |

## How to store

Use `ctx_knowledge` MCP tool:

```
ctx_knowledge(
  action: "remember",
  category: "conventions",
  key: "component-pattern",
  value: "User prefers function components over class components. Uses React Query for data fetching.",
  confidence: 0.9
)
```

Fallback (if MCP tool unavailable):

```bash
lean-ctx knowledge remember <value> --category <cat> --key <key> [--confidence <0-1>]
```

## What to capture

Include enough context so the fact is useful on its own:

- **Preference**: what, why (if stated)
- **Decision**: what was chosen, alternatives considered (if stated), rationale
- **Constraint**: specific bounds or rules
- **Correction**: what was wrong, what the right answer is

OK:

```
key: "testing-preference"
value: "Uses Vitest for unit tests, Playwright for e2e. No Jest. Prefers integration-style tests over pure unit tests."
```

Not OK:

```
key: "testing"
value: "uses vitest"
```

## Confidence

| Value | When |
|-------|------|
| `0.9` | Explicit user statement, decision, or correction |
| `0.7` | Implied preference inferred from repeated behavior |
| `0.5` | Speculative — infer from a single mention |
| `0.3` | Guess — worth noting but low confidence |
