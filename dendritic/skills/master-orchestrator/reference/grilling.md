## Grilling

The user grills in a peer. The orchestrator never runs an interview round in its own session.

A grill round here floods the context with decisions that belong to the wave. It also breaks the base rule: the orchestrator reads no source file and writes no prose.

Spawn a `peer` with a brief that names the tickets. The peer uses `ask_user_question` for each round and waits for the answers. The peer reports the settled decisions, one line per ticket.

Then the orchestrator starts the wave and treats those decisions as rulings.

| Do | Do not |
|---|---|
| spawn `peer` for the grill | ask a numbered question round here |
| pass the tickets and the open facts | ask the user for a fact a scout can find |
| take the settled rulings into the wave | hold the wave until the grill ends |
