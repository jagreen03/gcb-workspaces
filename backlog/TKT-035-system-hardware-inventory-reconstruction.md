---
id: TKT-035
title: "System-wide hardware inventory reconstruction (Orange-Team evidence discipline) - Pass 1 delivered"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - architecture-conflict
  - system-inventory
---

# Objective

The Architect supplied a standing prompt
(`C:\Users\jagre\Downloads\GCB System Hardware Inventory — Gemini +
Orange-Team Prompt.md`) for a full system-level hardware-inventory
reconstruction of GreenCoyote-Bay/ODIN_Bridge, with strict evidence-
category discipline (EXPLICITLY IDENTIFIED / ARCHITECTURALLY REQUIRED /
IMPLEMENTED / TESTED / PHYSICALLY VALIDATED / INFERRED / UNKNOWN - never
collapsed) and an explicit instruction to never silently reconcile
contradictory documentation.

Checked against `TKT-034` first, per the Architect's instruction: **not
close.** `TKT-034` is a narrow single-component grounding check (is
`gcb-pic-core`'s multiply operation `gcb-spec`-grounded). This prompt is
a full, 11-section, program-wide reconstruction across every repo. Opened
as this new ticket instead.

**Treated the source prompt itself per this program's own standing
doctrine**: its title ("Gemini + Orange-Team Prompt") and its own "may be
passed to another LLM" framing mark it as AI-facing, not as evidence in
its own right. `gcb-wiki/15_hardware_inventory_and_testability.md` and
`/16_hardware_parts_systems_specification.md` appear to already be
output from a prior run of this same (or a closely related) prompt -
and this session already found real, ungrounded content in both
(`TKT-033`). This reconstruction was therefore done as a genuinely fresh
pass from repo/`gcb-spec` evidence directly, not as a touch-up of the
existing docs, and not trusting their prior content as a starting
baseline.

## Pass 1 scope and honesty note

**This is a first pass, not an exhaustive final deliverable** - flagged
explicitly per this program's own "don't overclaim completeness"
discipline. Depth varies by repo:

- **Deep** (direct evidence gathered/re-verified this session or this
  pass): `gcb-rtl`, `gcb-wdm-transceiver`, `gcb-host`, `gcb-analog-rx`,
  `gcb-pic-core`, `gcb-spec`, `gcb-photonic-qam-v2` (RTL-level).
- **Shallow** (top-level README/structure only, not read in depth this
  pass): `gcb-python-orchestrator`, `gcb-dashboard`, `vortex` (the
  vendored RISC-V GPGPU - likely required external compute
  infrastructure per the prompt's own System Boundary Check, not a
  GCB-authored part; not yet confirmed).

See `gcb-workspaces/reports/system_hardware_inventory_pass1.md` for the
full deliverable (master inventory, status matrix, contradiction
register, system boundary, functional-completeness gaps, dependency map).

## Key findings (headline, full detail in the report)

1. **Real, hard evidence upgrade found**: `gcb-rtl`'s `greencoyote_top`
   has an actual Vivado 2024.2 post-route checkpoint (`post_route.dcp`)
   targeting a real FPGA part (`xcu55c-fsvh2892-2L-e`, Alveo U55C, OOC
   mode) - all timing constraints met (WNS +0.261 ns), real utilization
   (602 LUT / 0.05%, 8 DSP48E2) and a vectorless power estimate (flagged
   "confidence Medium" in its own source, not overclaimed). This is a
   materially higher evidence tier than "RTL IMPLEMENTED/DIGITALLY
   SIMULATED" for this specific top - genuinely SYNTHESIZED + PLACED
   AND ROUTED for a named FPGA part, confirmed by `gcb-host`'s own driver
   opening an XRT IP of the identical name.
2. **Confirmed `gcb_wavelength_router.sv` has diverged** between
   `gcb-wdm-transceiver` (124 lines, `N_LAMBDA` parameterized toward a
   ~60lambda Mode B count) and `gcb-photonic-qam-v2` (99 lines, the
   original fixed-2-color version) - a real fork-divergence, exactly the
   "repository names that refer to different architectural generations"
   contradiction class the source prompt names.
3. **This divergence likely resolves part of `TKT-033`'s earlier
   puzzle**: `gcb-wiki/15`'s ~60lambda/50GHz-grid DWDM figures most
   plausibly describe `gcb-wdm-transceiver`'s own real, RTL-implemented,
   regression-tested wavelength router - NOT `gcb-pic-core`'s homodyne
   tile (which `TKT-033` already correctly found has zero WDM grounding
   in `gcb-spec`). Two genuinely separate, both-real optical subsystems,
   previously conflated by `gcb-wiki`'s own cross-references.

## Required work (next iteration, not this one)

1. Deepen the shallow-pass repos (`gcb-python-orchestrator`,
   `gcb-dashboard`, `vortex`'s actual GCB integration surface).
2. Complete the remaining prompt sections not fully built in Pass 1
   (Required Equipment Matrix, full DFT/test-structure matrix) - Pass 1
   covers these at the depth `gcb-wiki/15` already established, re-
   verified rather than redone from scratch line-by-line.
3. Confirm the Finding #3 hypothesis above (`gcb-wiki/15`'s 60lambda
   figures describing `gcb-wdm-transceiver`, not `gcb-pic-core`) directly
   with the Architect or by re-reading `gcb-wiki/15`'s own citations in
   full.

## Out of scope

- Redesigning anything - this is reconstruction/inventory only, per the
  source prompt's own explicit framing.
- `TKT-019.19` and anything in that neighborhood - unrelated.

---
## Resolution, simplified (2026-09-12, same day, directed follow-on:
"simplify this, /loop till you find the best solution... don't throw
the baby out with the bathwater")

**The simple answer**: Track A (`gcb-spec`'s 5 repos) is **Phase I** -
the real, already-synthesized, current system. The "Track B" repos are
mostly **Phase II** - the same program's forward roadmap, not a
competing architecture. Nothing gets deleted; the confusion was a
citation gap, not a real conflict.

**Implemented and verified, not just decided in prose**: `gcb-pic-core`
is CONFIRMED to fold into Track A - `gcb-spec/docs/optical_geometry_spec.md`
(LOCKED v1.0.0) sizes a Phase-II integrated array at exactly `L=16`
contraction lanes/channel/fire, single wavelength. That's the real
number behind `gcb-pic-core`'s "K=16" - the WDM label was wrong, the
number wasn't. `mmi_power_tree.py` now builds+verifies both the real
Phase-I (N=8) and Phase-II (N=16) targets, reproduced twice, committed
(`gcb-pic-core@79e9c58`, `87de269`, pushed). See `TKT-030`'s own
refinement note.

**Checked, not yet confirmed, for the other four "Track B" repos**:
- `gcb-python-orchestrator` - plausibly ALSO belongs to Track A (its own
  README describes a compiler for "the Photonic + Vortex hybrid fabric,"
  which is exactly Track A's real data path - Vortex TCU feeding an
  optical cascade). Likely just an uncited repo, not a separate track -
  not yet confirmed by reading its internals in depth.
- `gcb-analog-rx` - **CHECKED against `ADR-005` directly.** NOT the
  retired ΔΣ branch (no feedback-nulling loop, no decimated bitstream -
  clearly different). NOT the winning Single-Slope CIS either, exactly:
  shares the same passive-integration-onto-`C_int` front end, but uses a
  flash/comparator-bank ADC back-end instead of Single-Slope's ramp +
  shared Gray-counter TDC, and its modeled window (200 ps) doesn't match
  `ADR-005`'s locked window (256 ns) by over 1000x - built independently
  of `ADR-005`'s real numbers. A genuinely **third** Rx variant for the
  same role, not yet reconciled with the already-locked decision -
  flagged on `TKT-031` (the ticket that made the original Phase-I
  disposition without checking `ADR-005`), not silently resolved.
- `gcb-wdm-transceiver` - real, substantial, regression-tested DWDM
  RTL, but Track A is explicitly single-wavelength ("no channel mux").
  Most likely a genuinely separate subsystem (inter-chip/board optical
  TRANSPORT, a different layer than Track A's on-die compute cascade),
  not forced into Track A - this is the one repo where "separate but
  real" is the most likely honest answer, not a citation gap.
- `gcb-photonic-qam-v2` - complex-valued QAM optical compute; no Track A
  counterpart found. Most likely a separate, longer-horizon vision, same
  status as `gcb-wdm-transceiver`.

**Net result**: of five "Track B" repos, one (`gcb-pic-core`) is now
confirmed to be Track A's own Phase II; one (`gcb-analog-rx`) is
confirmed to be a genuinely separate, third Rx variant, not reconciled
with `ADR-005`'s already-locked decision (flagged on `TKT-031`); one
more (`gcb-python-orchestrator`) is a plausible Track-A match pending a
deeper read; two (`gcb-wdm-transceiver`, `gcb-photonic-qam-v2`) are most
likely genuinely separate, real subsystems (transport/longer-horizon
vision, not discarded). This is real progress on Contradiction Register
entry #1, not a full close - `gcb-python-orchestrator` is the one
remaining unchecked item.

## Telemetry & Evaluation

No PBG grade - this is a large, explicitly-scoped-as-Pass-1 reconstruction
task, not a completed, gradable deliverable; matching this program's own
doctrine that a partial/in-progress survey gets no grade until its own
scope is actually finished.

**Final State:** `open | pending` - Pass 1 delivered (see the report);
one of five Track-B repos (`gcb-pic-core`) now confirmed reconciled into
Track A, implemented and verified; the other four have a stated best
guess each, not yet confirmed. Required Work items above left for
continuation.
