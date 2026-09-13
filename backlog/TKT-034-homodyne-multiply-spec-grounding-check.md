---
id: TKT-034
title: "Check whether gcb-pic-core's core multiply operation (A+B/A-B homodyne, Invariant #6) is gcb-spec-grounded, or gcb-wiki-only like TKT-033's K=16 framing was"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - silicon
  - photonics
  - architecture-conflict
---

# Objective

Flagged as a side-finding while resolving `TKT-033` (channel spacing) -
**not investigated, not resolved, a placeholder intake only.**

`TKT-033` found that `gcb-pic-core`'s "K=16" framing had zero grounding
in `gcb-spec` - it traced entirely to `gcb-wiki` (a derived, non-
authoritative human view), cited by `gcb-pic-core`'s own README instead
of `gcb-spec` directly. The same grep pattern, applied to this repo's own
**core Role description** - not just the K=16 channel count, but the
actual multiply operation itself - raises the same question:

`gcb-pic-core/README.md`'s "Role" section states: *"Compute the
balanced-homodyne matrix multiplication in the analog optical domain via
the coherent interference of light. Operands A and B are mixed in
directional couplers (A+B, A-B); square-law photodiodes extract
|A+B|^2-|A-B|^2=4 Re(AB*) (see gcb-wiki, intent Invariant #6)."`

A grep of `gcb-spec`'s actual working-tree text for "Invariant #6,"
"A+B," "balanced photodiode," or "homodyne" returns **zero matches in
readable content** (one hit landed inside a compressed `.git/objects`
blob, not a real source file - not evidence of anything). This does NOT
yet prove the multiply operation is ungrounded the same way K=16 was -
only that the same quick check that caught K=16's problem also turns up
nothing here, and deserves the same real investigation `TKT-033` did
before concluding anything.

## Required work (next iteration, not this one)

1. Read `gcb-spec`'s actual Task 1/Task 3 documents
   (`gcb-rtl/sim/mmi_tree_model.py`, `gcb-spec/bench_emulation_parameters.md`,
   `gcb-spec/task3_physical_bom.md`) in full for what they actually say
   the optical operation computes - not just grep for exact phrases.
   `mmi_tree_model.py`'s own header describes an **8:1 power-summing
   reduction cell**, not an A+B/A-B differential-homodyne multiply - these
   may be two genuinely different operations in the real architecture
   (a separate multiply stage feeding a separate summing/reduction
   stage), or `gcb-pic-core`'s own framing may be describing something
   `gcb-spec` never actually specifies.
2. Determine whether `balanced_homodyne_cell()`'s A+B/A-B differential
   detection is: (a) `gcb-spec`-grounded under different terminology than
   this repo's own README uses, (b) a real but entirely separate
   component from the Task 1 reduction model (plausible - multiply and
   sum could be different physical stages), or (c) ungrounded the same
   way K=16 was.
3. If (c): correct `gcb-pic-core/README.md`'s "Role" section and
   determine what, if anything, changes about `balanced_homodyne_cell()`
   (`layout_homodyne.py`) itself - a potentially much bigger correction
   than `TKT-033`'s, since that file is this repo's original, longest-
   standing component, not new work from this session.

## Out of scope

- Any code change to `layout_homodyne.py` - this ticket is intake/survey
  only, matching `TKT-032`'s own precedent for a bounded first pass.
- `TKT-019.19` and anything in that neighborhood - unrelated.

## Telemetry & Evaluation

No PBG grade - this is an intake placeholder, not a completed survey
(matching `TKT-032`'s own original shape before its survey was done).

**Final State:** `open | pending` - flagged, not investigated.
