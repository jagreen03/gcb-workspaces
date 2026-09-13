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

## Telemetry & Evaluation

No PBG grade - this is a large, explicitly-scoped-as-Pass-1 reconstruction
task, not a completed, gradable deliverable; matching this program's own
doctrine that a partial/in-progress survey gets no grade until its own
scope is actually finished.

**Final State:** `open | pending` - Pass 1 delivered (see the report),
Required Work items above left for continuation.
