---
id: TKT-034
title: "RESOLVED: gcb-pic-core's multiply operation is real and grounded - in gcb-photonic-qam-v2/intent.md + gcb-wdm-transceiver RTL, not gcb-spec, not gcb-wiki-only"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.9
  quality: 0.85
  emergence: 0.8
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

---
## Resolution (2026-09-12, same day, continuing the directed open-ended
backlog work)

**Answer: (b), refined - `gcb-pic-core`'s A+B/A-B multiply is real and
grounded, but in a different real program than `gcb-spec`, not in
`gcb-wiki` alone.**

`gcb-photonic-qam-v2/intent.md` (Required-work item 1's own "read the
actual documents" instruction, followed through) states, almost
verbatim: *"square-law photodiodes extract the cross-term
|A+B|^2-|A-B|^2 = 4Re(AB*). This is the physical basis of the MAC."* -
the same physics as `gcb-pic-core`'s own `balanced_homodyne_cell()`,
word for word. Its own "Software Tiling Constraint" section derives
`K <= 16` for this exact mechanism from a balanced-homodyne SNR/phase-
noise budget (DPI-C co-simulation, `model/RESULTS.md`). Separately,
`gcb-wdm-transceiver/rtl/gcb_dwdm_pkg.sv` has `K_MAX = 16`, real
synthesizable RTL, commented *"a HARD cross-architecture invariant."*
Both `gcb-pic-core` and `gcb-analog-rx` self-describe, in their own
README headers, as part of **"the GCB Photonic QAM Accelerator"** - a
real, named second program.

**This is NOT the same finding as (c)** - the multiply operation is not
ungrounded. It is grounded in this second program's own real design
documents and RTL (`gcb-photonic-qam-v2/intent.md`, `gcb-wdm-
transceiver`'s RTL), which `gcb-pic-core`'s README should have cited
directly instead of routing through `gcb-wiki`. `gcb-spec`'s own
`mmi_tree_model.py` (option (a)/(b) in the original framing) is
confirmed NOT this mechanism - plain power-summing, no differential
detection anywhere in its derivation, belonging to a different,
separate program ("GCB/ODIN_Bridge," the Vortex-TCU-fed FPGA pilot).

**Consequence, recorded on `TKT-030`, not here**: this corrects an
intervening claim from earlier the same day (that `gcb-pic-core`'s
K=16 mapped to `gcb-spec`'s `L_CONTRACT=16`) - that was a hastier,
less-specific match made before this ticket's own investigation ran.
The real topology `gcb-pic-core` needs, per this grounding: 16 separate
multiply cells feeding two power-summing trees feeding one shared
photodetector pair - not yet built, tracked on `TKT-030`.

## Telemetry & Evaluation

Spec 0.9 - answered the exact question this ticket posed (is the
multiply operation `gcb-spec`-grounded, or `gcb-wiki`-only), with a
real third answer neither original option anticipated cleanly. Quality
0.85 - backed by a direct, word-for-word mechanism match and a real RTL
constant, not inference from naming alone; not 1.0 because the
corrected topology itself is not yet built. Emergence 0.8 - this
surfaced a materially important correction to the SAME DAY's own prior
work (the `L_CONTRACT=16` claim), caught and fixed within the same
session rather than left standing - a genuinely higher-value outcome
than the original narrow question.

**Final State:** `done | blue` - the grounding question is answered;
the resulting corrected-topology build is tracked as follow-on work on
`TKT-030`, not reopened here.
