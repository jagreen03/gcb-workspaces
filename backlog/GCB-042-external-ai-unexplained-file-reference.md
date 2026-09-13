---
id: GCB-042
title: "External AI response referenced two real, private-repo file names it was never given - provenance unresolved, filed for awareness"
date_created: 2026-09-13
status: open
telemetry_color: pending
tags:
  - backlog
  - research-operations
  - ai-trust
  - process
---

# Objective

Not an engineering defect and not itself a research question — a
process/trust observation, filed for the Architect's awareness per the
new research-triage workflow (`gcb-wiki/appendices/research-operations.md`),
not resolved unilaterally here.

## What happened, checked directly

The Architect pasted `gcb-lumen/EXTERNAL_AI_BRIEFING.md`'s condensed
prompt (the shorter, self-contained version meant for a plain AI chat
with no repo access) into an external AI chat and brought the response
back. The response recommended a real, workable approach (SAX +
assumed per-junction loss) — see `gcb-lumen/FINDINGS-2026-09-13.md` for
the full technical evaluation, which is not this ticket's subject.

**One specific detail in that response could not be explained from
what was actually given to it:** the response referenced two file
names — `k16_tile.py` and `mmi_power_tree.py` — as "the layout geometry
you already built." Checked directly: **both are real files** in
`gcb-pic-core` (a private repository). **Neither name appears anywhere
in the condensed prompt that was pasted** — no filenames, no directory
listing, no "K=16" framing was given to the external AI.

## Why this matters, stated plainly

`gcb-pic-core` is private. There is no known, legitimate path for a
public AI model to have training-data knowledge of its specific file
names. Two honest possibilities, genuinely not distinguishable from
this session alone:

1. **The Architect's actual conversation with the external AI included
   more context than what was quoted back** — e.g., the fuller
   `EXTERNAL_AI_BRIEFING.md` (which does name both files, in the real
   source code it quotes), or additional detail added manually. This
   would fully explain the reference and require no further action.
2. **Coincidental pattern-matching** — `mmi_power_tree.py` is a fairly
   guessable name given the prompt's own description ("MMI," "combiner
   tree"); `k16_tile.py` is a much less obviously-derivable guess with
   no clear basis in the given prompt.

**This ticket does not attempt to distinguish between these** — that
requires knowing exactly what was actually sent to the external AI, a
fact only the Architect has.

## What this is NOT

Not a claim that private repository content has leaked, or that any
external AI vendor has improper access to this program's repos. Not a
claim that the external AI's broader recommendation (evaluated
separately, and independently confirmed workable in
`gcb-lumen/FINDINGS-2026-09-13.md`) is untrustworthy. This is a single,
narrow, unexplained detail, recorded because this program's own
discipline is to record what doesn't add up rather than let it pass
silently.

## Suggested (not decided) next step

If this pattern recurs — an external AI referencing specifics it was
not given — it may be worth a standing practice of always pasting the
**full** `EXTERNAL_AI_BRIEFING.md` rather than a condensed prompt, so
there is never ambiguity about what context an external session
actually had. Not adopted here; the Architect's call.

## Out of scope

- The technical merit of the external AI's SAX recommendation — see
  `gcb-lumen/FINDINGS-2026-09-13.md`.
- Any change to how `EXTERNAL_AI_BRIEFING.md` files are written or used
  — a process change, not made unilaterally by a ticket filed the same
  day as the observation.

---
## Telemetry & Evaluation

No PBG grade — a finding reported for disposition, explicitly not a
build or a closed decision (same category as `GCB-041`).

**Final State:** `open | pending`. Filed for the Architect's review via
the first real run of the research-triage workflow
(`gcb-workspaces/reports/research_triage_log.md`, Pass 1).
