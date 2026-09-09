---
id: TKT-018
title: "EPIC — OpenROAD physical layout: push the verified SV-2017 logic to a 5nm-class GDSII"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - epic
  - eda
  - physical-design
  - gdsii
---

# Objective

Stand up the **physical-synthesis flow** that carries GreenCoyote-Bay's
lint-clean, Yosys-elaborated SV-2017 down to a manufacturable **5nm-class GDSII**
with a signed-off timing / area / power report. This Epic owns the system
boundary **RTL freeze set → Yosys synthesis → OpenROAD (floorplan, place, CTS,
route) → DRC / LVS signoff → GDSII + PPA report**, using an open 5nm-class
enablement (ASAP7 as the open stand-in for a 5nm node; the flow is
PDK-parameterised so a real 5nm PDK drops in later). It builds on the same
`sv2v`→Yosys front end already trusted for elaboration in `gcb-wiki/10`, and
spawns per-block sub-stories (SDC generation, floorplan config, CTS recipe, DRC
waiver policy, the PPA regression).

## "Product Ready for Presentation" — PBG analysis

* **Green (target) — the artifact that proves it demos.** A `make gds` that
  takes at least one already-verified block (`gcb_max_reduce` and
  `gcb_tensor_sram_controller` are the first candidates) through the *entire*
  OpenROAD flow and emits: `<block>.gds`, a `report.json` with `WNS ≥ 0` at a
  stated clock, cell area and estimated power, a clean DRC (or an explicit,
  reviewed waiver list), and a rendered die / floorplan PNG. A real GDSII of a
  real verified block, timing-closed, on screen, is the proof.

* **Blue (engineering) — the methodology that guarantees Green.** Pinned,
  container-free OpenROAD-flow-scripts (ORFS) with one config per block; SDC
  constraints **generated from the block's Cocotb clock definition** so timing
  intent has a single source; a regression that hard-fails on `WNS < 0`, on any
  un-waived DRC error, or on an LVS mismatch; the Yosys synthesis step reusing
  the exact front-end invocation from `gcb-wiki/10` so RTL trusted for
  elaboration is the same RTL trusted for layout; every sub-story adds its block
  to the regression matrix.

* **Purple (emergence) — Cyclopter / serendipitous reuse.** The floorplan /
  SDC generator is parameterised so **every future RTL sub-story auto-emits its
  physical config** — the compute tiles from TKT-017 and the transport blocks
  from TKT-019 enter the flow for free. PPA becomes a **new telemetry axis**:
  each block's `WNS`, area and power land as a provenance-tagged record the
  Cyclopter scavenger (TKT-013) ingests, so "is the chip presentation-ready"
  is a pgvector query over per-block PPA, not a spreadsheet. GDS artifacts
  render through the **TKT-001** DigitalJS / GDS-Lens pipeline, so the deck
  pulls schematic and chip-scale layout from one source.

## Context & Constraints

* **Current State:**
  * `gcb-wiki/10` defines the open-source EDA toolchain: Verilator-5 lint,
    Cocotb ≥ 1.9, `sv2v` → Yosys elaboration. Yosys `synth` + `stat` is already
    used (TKT-012, TKT-016) for cell-count / area arguments.
  * No place-and-route, no PDK, no GDSII exists in any repo. Area figures to
    date are gate-count estimates from `synth -flatten`, not routed.
  * OpenROAD / ORFS is not yet installed or pinned in the environment.
* **Constraint:** No RTL change to close timing — a block that will not meet a
  sane clock is a TKT-017 / TKT-019 RTL bug, filed back, not patched in the
  netlist. Flow scripts are pinned and container-free (matching the no-Docker
  environment). Open PDK only; any real-PDK material stays out of the repos.
  PBG / Cyclopter prompt-layer protocols stay out of the EDA repos
  (`gcb-wiki/04`). Each block is independently flow-green before it counts.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The Epic target is Green through Blue-grade engineering** — a pinned,
regressable flow that produces a real GDSII per block, not a one-off manual run.

* **Green (target):** `make gds` for ≥ 1 verified block → GDSII + timing-closed
  `report.json` + clean DRC + floorplan PNG; the flow regressable in CI.
* **Blue:** SDC-from-Cocotb single source, `WNS<0` / DRC / LVS as hard CI
  failures, Yosys front-end shared with `gcb-wiki/10`, per-block config, PPA
  telemetry to Cyclopter, GDS into the TKT-001 viewer.
* **Yellow (reject):** a hand-run OpenROAD GUI session screenshotted for the
  deck with no reproducible script; timing "closed" by relaxing the clock until
  `WNS ≥ 0` without recording the frequency.
* **Red (reject):** editing the gate netlist or inserting hand ECOs to hide an
  RTL timing bug; an unpinned flow that pulls `latest` ORFS each run.
* **Purple / Light-gray:** a full multi-block hierarchical SoC floorplan with
  power grid and package co-design is Purple / a later Epic; staying at
  `synth -stat` gate estimates (Light-gray) never produces a real layout for
  the presentation.

**Explicitly out of scope (separate tickets / Epics):**
1. RTL functional changes — those belong to TKT-017 / TKT-019.
2. A real (non-open) 5nm PDK and its NDA material.
3. Full-chip hierarchical assembly, power-grid / IR-drop signoff, packaging.
4. Analog / photonic layout (PIC) — that is `gcb-pic-core` / GDS Lens.
5. Tape-out logistics, mask data prep, foundry hand-off.

## The "Green" Target

1. Pinned ORFS (or equivalent OpenROAD driver) checked in under an EDA repo,
   container-free, with an open 5nm-class PDK wired in and a `README` naming the
   exact versions.
2. One config per target block; SDC generated from that block's Cocotb clock.
3. `make gds BLOCK=<name>` runs synth → floorplan → place → CTS → route → DRC →
   GDS for `gcb_max_reduce` and `gcb_tensor_sram_controller` at minimum.
4. `report.json` per block: clock period, `WNS`, `TNS`, cell area, instance
   count, estimated power; a `floorplan.png`.
5. A regression (`make ppa-check`) that exits non-zero on `WNS < 0`, any
   un-waived DRC violation, or LVS mismatch; waivers live in a reviewed file.
6. Per-block PPA emitted as a provenance-tagged record for Cyclopter ingest
   (read-only; not a write into `pbg_telemetry`).
7. GDS wired into the TKT-001 `build_visuals.py` / GDS-Lens path so it renders
   alongside the schematic. Diff confined to a new EDA-flow directory + configs
   + the wiki pointer; no RTL edit.

---
## Execution Log
*(To be populated during execution — spawns sub-stories TKT-018.x)*

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
