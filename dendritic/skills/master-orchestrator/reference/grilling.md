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

## A lane asks the user

A `peer` lane calls `ask_user_question` when a decision blocks its ticket. It does not wait for the orchestrator to relay the question.

| Case | Who asks |
|---|---|
| work cannot continue on two readings of the ticket | the lane |
| a contract band, cap or gate would change | the lane, then the orchestrator records the ruling |
| a costly or irreversible step is next | the lane, then it stops until the answer arrives |
| a fact sits in the code | nobody asks. A scout reads it |

The skill keeps one shape: the orchestrator never grills in its own session. It spawns a `peer` for a grill round, and a running lane may grill on its own.
