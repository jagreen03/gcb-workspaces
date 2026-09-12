---
id: TKT-026
title: "Phase-I bench photocurrent budget — unblocks TIA gain selection"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - hardware
  - phase-1-bench
  - photonics
  - analog
---

# Objective

`gcb-spec/task3_physical_bom.md` §3.2 left the Phase-I bench's matched
transimpedance amplifiers' gain setting uncalculated: "depends on the
unresolved photocurrent budget above." This ticket closes that budget —
not as a simulation exercise, but as the one concrete number (or narrow
range) needed before a TIA can actually be selected and quoted.

**Mode:** build, refine, build, refine. The deliverable is a number the
Architect can hand to a TIA datasheet, not a falsification campaign.

## Task

Compute the expected photocurrent range at each tap (Tap 0 reference, Tap
K result) from the chain already specified in `task3_physical_bom.md`:

1. Candidate laser output power (§1 — pin a specific power bin once a
   laser candidate is actually chosen; the BOM currently leaves this
   `[CANDIDATE — parametric fit]`, un-pinned).
2. Insertion-loss budget through §1 (isolator) and §2 (PM splitters, the
   8×8 mesh bench-coupling emulation network) — dB-by-dB, reference vs.
   result leg separately since they are not guaranteed equal.
3. Candidate photodiode responsivity (§3.1, A/W at 1310 nm) for the
   chosen candidate part.
4. Resulting photocurrent range at each tap, worst-case and nominal.
5. The TIA transimpedance gain (Ω) that maps that photocurrent range onto
   the ~1.5 V full-scale target (`02_receiver_architecture.md`), for the
   §3.2 candidate TIA (or whatever part this calculation shows is actually
   needed — the candidate may need to change once a real number exists).

## Deliverable

A short calc (spreadsheet or a documented Python script, either is fine)
producing: the photocurrent range at each tap, the selected gain-setting
resistor value, and an updated `task3_physical_bom.md` §3.2 with the gain
setting no longer marked "not yet calculated."

## Out of scope

- Re-litigating §1/§2's own `[TBD]` items (laser, isolator, modulator,
  splitters) — this ticket takes whatever candidates are on file as inputs;
  if none exist yet for a given stage, use a documented placeholder loss
  figure and flag it, don't block on it.
- Any RTL change. This is a physical-layer bench calculation only.

## Telemetry

No PBG grade — this is a build-prerequisite calculation ticket, not a
verified RTL deliverable.

**Status:** `open | pending`.
