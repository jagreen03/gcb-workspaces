# Research Triage Log

Append-only, one entry per harvest pass — same pattern as
`spike_loop_summary.md`. Each entry: what was harvested, how it was
classified, what priority it got, and what was drafted from it (a new
research prompt, a new ticket, or neither). See
`gcb-wiki/appendices/research-operations.md` for the roles, the
priority scale, and the full workflow this log is the record of.

Nothing in this log is final. A drafted ticket sits `open` until the
PI (the Architect) reviews it, same as every other ticket in this
program's backlog.

---

## Pass 1 — 2026-09-13 — `gcb-lumen`

**Harvested:** `gcb-lumen/FINDINGS-2026-09-13.md` (an external AI's
SAX-based recommendation, checked and partly executed the same day)
and `gcb-lumen/ai-agents/ORANGE_TEAM.md`'s `MEASUREMENT STATE — V2`.

**Classification, three separate threads inside one finding:**

1. **The real per-junction insertion-loss number** — **needs more
   research.** The core blocking question is unchanged; only the
   framework for computing a system-level answer from it is now real.
   **Priority: P1** — blocks the fan-in decision (`optical.cell.fanin`
   in `DECISION_LEDGER.md`), which nothing is actively demanding
   *today*, but which the program's own docs already flag as the next
   real step once a loss number exists.
   **Drafted:** a refined next-research prompt, appended to
   `gcb-lumen/ai-agents/ORANGE_TEAM.md`, that assumes the SAX
   framework as given (no need to re-justify the toolchain choice) and
   asks specifically for a real, non-assumed loss number via a
   `femwell`-extension or a cited literature/vendor figure.
2. **The SAX-framework feasibility question** — **resolved.**
   Confirmed real and working by actually building and running it.
   No further action; already reflected in `gcb-lumen`'s own state.
3. **The unexplained file-name reference** (`k16_tile.py` /
   `mmi_power_tree.py` named by an external AI that was never given
   those names, against a private repo) — **ticket-worthy.** Not an
   engineering defect and not itself research — a process/trust
   observation about external-AI tool use that the PI should see and
   decide whether to act on (e.g., always paste the *full* briefing
   rather than a condensed one, to remove the ambiguity going
   forward). **Priority: P2** — nothing depends on resolving it today,
   but it's a real, recorded gap in this program's own AI-trust
   discipline.
   **Drafted:** `GCB-042` (see `gcb-workspaces/backlog/GCB-042-external-ai-unexplained-file-reference.md`).

**Roles exercised this pass:** the Architect (PI) brought the external
AI's response back — Research Scientist role, informally, by initiating
contact with an external AI. This session then acted as External
Reviewer (checked the response's claims against the real repo) and, in
writing this log entry, as Triage Coordinator. First real run of all
three non-PI roles in one pass, not yet split across separate sessions
or people — that's the next thing to actually try, not simulated here.
