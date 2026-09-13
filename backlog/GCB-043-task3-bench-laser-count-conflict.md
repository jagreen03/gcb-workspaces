---
id: GCB-043
title: "Task-3 Phase-I bench: two real gcb-spec documents disagree on laser count - N independent diodes vs. one diode split via a PM splitter, for the same bench"
date_created: 2026-09-13
status: open
telemetry_color: pending
tags:
  - backlog
  - optics
  - architecture-conflict
  - research-operations
  - gcb-lambda
---

# Objective

A real architecture conflict between two `gcb-spec` documents, found by
`gcb-lambda` (an isolated research repo, see
`gcb-wiki/appendices/research-operations.md`) while reconciling
`gcb-wiki/16_hardware_parts_systems_specification.md` Part 9's
previously-blanket "laser bank has zero spec" claim. Filed for
Architect disposition, not resolved here — same category as `TKT-031`
(TIA vs. switched-charge-integrator).

## What was found, checked directly at every step

1. **Both documents describe the same bench, not two different
   experiments.** `gcb-spec/bench_emulation_parameters.md`'s own scope
   line: *"Component breakdown for the discrete-component 8-input
   optical reduction cell (Phase I **Task 3** / Objective O3)."*
   `gcb-spec/task3_physical_bom.md`'s own title: *"**Task 3** —
   Phase-I Guaranteed Bench (COTS) Physical Bill of Materials."*
   `gcb-wiki/02_receiver_architecture.md`'s "Phase I — Guaranteed
   Bench" section states one combined purpose for this bench — proving
   *both* "the optical-summation **and** ratiometric-cancellation
   physics" — not two separate tests.
2. **`bench_emulation_parameters.md` §2.1–2.2** specifies **4
   (minimum) to 8 (target) separate** O-band (~1310 nm) DFB-or-
   Fabry–Pérot laser diodes, **one per leaf channel**, each directly,
   individually intensity-modulated (8-bit/256-level) by its own DAC
   channel, each independently TEC-stabilized.
3. **`task3_physical_bom.md` §1–§2** specifies exactly **one** O-band
   (1310 nm) CW DFB laser (`GCB-LSR-01` `[CANDIDATE]`) through **one**
   linear VOA (`GCB-VOA-01` `[CANDIDATE]`, decided over an LiNbO₃ MZ
   modulator per `TKT-028` — that decision is not in question here),
   then split via a **1×8 PM fiber splitter** (`GCB-SPLT-1X8` `[TBD]`)
   into one reference leg and up to seven result-combination legs.
   Section 1's own heading is "Laser Source**s** & Modulation" (plural)
   but specifies exactly one laser — not a typo caught elsewhere in the
   document, worth noting as its own small inconsistency.
4. **Not a WDM disagreement.** `task3_physical_bom.md` §2 calls its
   splitter network an "8×8 unitary-mesh bench coupling emulation" —
   explicitly labeled a passive, single-wavelength COTS-splitter
   proxy, not a real wavelength-division-multiplexed claim. `TKT-033`'s
   original finding (no real WDM anywhere in `gcb-spec`) still stands;
   this ticket is narrowly about laser *count*, nothing else.

## Why this matters, stated plainly

The two architectures have genuinely different engineering
consequences, not interchangeable implementation details:

| | N independent diodes (`bench_emulation_parameters.md`) | One diode + splitter (`task3_physical_bom.md`) |
|---|---|---|
| Per-channel power matching | Needs active calibration across N separately-sourced diodes (±5% target, per-channel gain-trim) | Splitter ratios fixed at manufacture; simpler matching, but... |
| Failure mode | One diode failing affects one channel | The splitter/single laser is a single point of failure for every channel |
| Wavelength drift | N independent DFB/FP drift profiles (~0.1 nm/K each) to track | One drift profile, shared across all channels |
| Cost/complexity at scale | Scales linearly in diode count | Scales in splitter insertion-loss budget, not diode count |

Which one is actually correct for the Phase-I bench — and whether
either was a deliberate supersession of the other, or simply two
documents authored without cross-checking each other — is not
determinable from the documents alone.

## Out of scope

- Re-opening `TKT-028`'s VOA-over-MZ modulator decision — unaffected
  either way.
- Scoping the Phase-II (64-channel) laser/modulator design — that
  remains genuinely unscoped regardless of how this resolves, and is
  `gcb-lambda`'s separate, second deliverable.
- Building or procuring anything — both documents' candidate parts
  remain `[CANDIDATE]`/`[TBD]`, unpurchased, unbuilt.

## Suggested (not decided) next step

Check which document is more recent and whether either was written
with deliberate knowledge of the other (commit history / authorship
context the Architect may have that this ticket doesn't). If neither
supersedes the other, the Architect picks one architecture and the
other document gets corrected to match — a documentation fix once a
real decision exists, not before.

---
## Telemetry & Evaluation

No PBG grade — a real architecture conflict reported for disposition,
not a closed decision (same category as `TKT-031` before its own
resolution, and `GCB-041`).

**Final State:** `open | pending`. `gcb-wiki/16`'s Part 9 entry and
summary table corrected the same day to reflect real Phase-I content
existing (rather than the prior blanket "zero spec" claim) while
explicitly deferring this specific conflict to this ticket.
