---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Use the `ask_user_question` tool for every grilling question. Concretely:

- One question per `ask_user_question` call — walk the decision tree one branch at a time, waiting for the answer before descending further.
- Each question needs 2–4 options. Put your recommended answer first, with "(Recommended)" appended to its label, and write each option's description to explain what choosing it means or its trade-offs.
- The tool always appends a "Type something." row, so the user can give a custom answer that doesn't fit your options — don't add your own "Other" row.
- When the user's answer opens a new sub-decision, follow up with another `ask_user_question` call resolving that branch before moving on.
- Only fall back to plain prose questions if `ask_user_question` is unavailable or the user prefers free-form conversation.

If a question can be answered by exploring the codebase, explore the codebase instead.
