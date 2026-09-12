---
id: TKT-018
title: "EPIC — OpenROAD physical layout (MEASUREMENT EPOCH): extract silicon feedback on gcb_max_reduce before optical scale-up"
date_created: 2026-09-09
status: done
telemetry_color: blue
telemetry:
  spec: 0.8
  quality: 0.6
  emergence: 0.0
tags:
  - backlog
  - epic
  - eda
  - physical-design
  - gdsii
  - measurement-epoch
---

# Objective

> **Rescoped 2026-09-10 by [[TKT-000]] (Orange Team epoch guidance —
> "Physical Reality First").** This Epic is now a **Measurement Epoch**, not a
> tape-out effort. Its job is to confront the functionally-verified RTL
> (TKT-001…017: bit-exact math, 0 stalls, peak MAC rate) with physical reality
> and read the numbers *before* [[TKT-019]] commits optical-transport decisions
> (wavelength count, serialization width, PHY area) that depend on how much
> digital area / power / timing headroom actually exists.

**Deliverable of the epoch:** a single **deliberately unoptimized** pass of the
smallest fully-verified macro — **`gcb_max_reduce`** (TKT-016) — through the
default OpenROAD-flow-scripts / ASAP7 flow, producing:

* cell area + instance count,
* `WNS` / `TNS` at a stated clock,
* estimated power,
* routing congestion / utilization,
* DRC violation classes,
* `report.json` + `floorplan.png`,
* **a written interpretation** feeding TKT-019 and any
  architecture-from-measurement tickets.

A negative slack, a congested route, an oversized macro are **successful
measurements**, not failures (TKT-000). A timing-closed, DRC-clean GDSII is
**explicitly not required** for this epoch — no floorplan hand-optimization, no
timing-driven synth sweeps, no congestion ECOs, no clock relaxation to fake
`WNS ≥ 0`. Default recipe, one block, once.

The full **physical-synthesis flow** still described below — Yosys synthesis →
OpenROAD (floorplan, place, CTS, route) → DRC / LVS → GDSII + PPA report,
ASAP7-parameterised so a real 5nm PDK drops in later — is the *vehicle* for the
measurement, and remains the shape of the eventual tape-out Epic; but a
**manufacturable 5nm-class GDSII with a signed-off report is deferred** to a
later Epic planned *from* this one's numbers. It builds on the same `sv2v`→Yosys
front end trusted for elaboration in `gcb-wiki/10`, run in the **isolated P&R
environment** the [[TKT-000]] toolchain split defines (never in the locked RTL
Baseline), and spawns per-block sub-stories (SDC generation, floorplan config,
CTS recipe, DRC waiver policy, the PPA regression) as the measurement widens
past `gcb_max_reduce`.

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
## Execution Log — closed 2026-09-12, status corrected from a stale blank

**This epic's own stated "Deliverable of the epoch" was already fully
satisfied** — not by `TKT-018.x` sub-stories as this ticket's own text
anticipated, but by the `GCB-027` → `GCB-033` chain (the `GCB-###`
namespace cutover, `GCB-026`, happened the day after this epic opened, so
the sub-stories landed under that prefix instead). Confirmed by direct
inspection of the isolated P&R environment
(`~/eda/OpenROAD-flow-scripts/flow/{results,logs,reports}/asap7/gcb_max_reduce/`)
before writing this, not assumed from the tickets' own text alone:

* A **complete, real flow run** exists: `6_final.gds`, `6_final.def`,
  `6_final.v`, `6_final.spef`, and `6_report.json` all present, `
  finish__flow__errors__count: 0`.
* **`GCB-032`'s own claimed numbers match the actual report file exactly**:
  `WNS/TNS = 0.00 ps`, `0` setup/hold violations, `fmax = 1.519 GHz`,
  `372` sequential cells, `9.37 mW` total power (`0.00936753` in the raw
  report) — cross-checked, not re-typed from the ticket.
  `docs/PPA_burndown.md` (`gcb-wdm-transceiver`) already carries the full
  `GCB-027→032` transfer-function table; `GCB-033` (done|green) already
  retired `SYNTH_RETIME_MODULES` for this block and promoted the mid-tree
  RTL pipeline as the standing closure path.
* **What this means for this epic specifically**: the narrow "Measurement
  Epoch" objective this ticket opened with — confront verified RTL with
  physical reality, read the numbers, feed them to `TKT-019` *before*
  wavelength-count/PHY-area decisions were made — is done, and was done
  well before `TKT-019` itself reached its own current state this session.
  This ticket's own frontmatter was simply never updated to reflect that;
  corrected here.

**What remains explicitly open — this is NOT a full "Green" closure**:

1. Only **one** block (`gcb_max_reduce`) has gone through the flow — the
   Green Target's own item 3 names `gcb_tensor_sram_controller` as a
   second minimum block; not attempted.
2. **38 max-slew DRVs remain** on `gcb_max_reduce` (`GCB-032`/`GCB-033`'s
   own acknowledged open item, a `SKIP_LAST_GASP=0` slew-repair pass) —
   "clean DRC" in the Green bar's detailed-route sense is met (0 DRC
   violations), but this DRV item is not closed.
3. **No CI regression** (`make ppa-check` hard-failing on `WNS<0`/DRC/LVS)
   exists — the run was a manual, out-of-band invocation in the isolated
   P&R environment, not a regressable flow.
4. **SDC is hand-written**, not generated from the block's own Cocotb
   clock definition (the Blue-grade single-source requirement).
5. **No confirmed Cyclopter PPA ingest or `TKT-001` GDS-viewer wiring** —
   not checked in this pass; likely also not done.
6. The toolchain itself (`~/eda/OpenROAD-flow-scripts`) is **not checked
   into any `gcb-*` repo** — by design, per `TKT-021`'s own "changes no
   RTL and no repo code" framing — so the Green bar's "pinned... checked
   in under an EDA repo" item is not literally met either, though the
   tool is genuinely present, working, and version-identifiable
   (`openroad -version` → `26Q3-1953-gc6c0900a16`).

**Disposition**: closing this epic's own narrow, explicitly-stated
Measurement-Epoch deliverable as done (items 1-6 above are real, separate,
follow-on engineering work — a CI/regression/multi-block/Cyclopter-wiring
effort in their own right, not a continuation of "did the measurement
happen"). A future ticket should own items 1-6 if the full tape-out-grade
Green flow is still wanted; this epic does not claim to have done that
work.

---
## Telemetry & Evaluation

**Final State:** `done` (Measurement Epoch deliverable only — see the 6
explicitly-open items above, not claimed as closed by this telemetry).
**Color:** `blue` — solid, validated engineering (a real, working,
version-pinned toolchain; a real ASAP7 config; a real, cross-checked,
timing-closed physical measurement feeding `TKT-019`), but not `green`
(no CI regression, single block only, DRVs open, SDC not single-sourced).
**Vector summary:** spec 0.8 (the stated Measurement-Epoch deliverable is
fully met; the separate, broader "Green Target" 7-item checklist is not —
hence < 1.0), quality 0.6 (the underlying `GCB-027`→`033` work is itself
rigorous and cross-checked, but this epic's OWN ticket sat with a stale,
blank Execution Log until this correction — a real process gap, not
excused by the sub-work's own quality), emergence 0.0 (no new
architectural surface; this is a ledger-accuracy correction over
already-completed work, not new capability).
