---
id: TKT-018
title: "EPIC — OpenROAD physical layout (MEASUREMENT EPOCH): extract silicon feedback on gcb_max_reduce before optical scale-up"
date_created: 2026-09-09
status: done
telemetry_color: blue
telemetry:
  spec: 0.8
  quality: 0.65
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
2. ~~38 max-slew DRVs remain...~~ **CLOSED, 2026-09-12 — see "Max-slew DRV
   disposition" below.** Two genuine remediation attempts were made and
   both failed to move the count; the root cause was identified and the
   remaining 38 DRVs are formally classified as an accepted, non-blocking
   control-net artifact rather than left as an open action item.
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

### Max-slew DRV disposition (2026-09-12)

**Two config-only remediation attempts were made, in the isolated P&R
environment, against the real flow — not theorized about:**

1. **`SKIP_LAST_GASP=0`** (the exact follow-on `GCB-032`/`GCB-033` already
   named as the candidate). Full clean re-run (`make clean_all && make`,
   ~2.5 min). Result: **38 violations, unchanged**; every other PPA figure
   (WNS/TNS/fmax/power/area/instance count) bit-identical to the baseline
   run. Root cause found by reading `flow/scripts/util.tcl` directly
   rather than guessing further: `SKIP_LAST_GASP` only threads into
   `repair_timing_helper` (setup/hold repair) — it has **no connection at
   all** to `repair_design_helper`, the separate OpenROAD command that
   actually owns max_slew/max_cap/max_fanout DRC repair. The prior
   `GCB-032`/`GCB-033` note naming this as the candidate fix was itself
   mistaken.
2. **`SLEW_MARGIN=15`**, the flag `repair_design_helper` *does* actually
   read (confirmed from the same source read, not guessed). Re-run from a
   clean `resize` stage onward. Result: **38 violations, unchanged** again,
   every other figure again bit-identical.

**Root cause, as far as this investigation can establish it**: all 38
violating pins are the asynchronous `RESETN` input of flip-flops in
`g_reg_out.bnk_val[*]`/`bnk_idx[*]` — i.e., every single violation sits on
the reset tree, none on any clock or data path. OpenROAD's standard
`repair_design` buffering pass is built around the combinational/data
timing graph; it did not touch this net under either setting tried, which
is consistent with async set/reset nets commonly sitting outside a
resizer's default buffering scope (clock-tree-style buffering is a
separate, dedicated step this flow does not invoke for non-clock nets).
Actually fixing it would most likely need either a dedicated reset-tree
buffering step (not confirmed to exist in this ORFS build) or restructuring
the reset fanout in the RTL itself.

**Disposition (direct Architect steer, 2026-09-12): the 38 remaining DRVs
are formally classified as a non-critical control-net artifact, not
pursued further.** Basis: (a) confined entirely to the async reset tree —
zero occurrences on any clock or data path; (b) the flow's own STA run
shows zero resulting setup or hold violations at either corner checked
(`setup_violation_count = 0`, `hold_violation_count = 0`,
`WNS/TNS = 0.00 ps`, `fmax = 1.519 GHz` — all unchanged by either repair
attempt); (c) an RTL-level reset-fanout refactor is explicitly out of
scope for this measurement-epoch ticket (TKT-018's own "no RTL change to
close timing" constraint) and is not opened as a rabbit hole here. This is
a disposition **decision**, not a claim that the underlying slew
characteristic is irrelevant to a real silicon pass — `PROVEN — DIGITAL
SIMULATION (ORFS/OpenROAD flow), TESTED CONDITIONS` covers exactly what
was measured (zero STA timing impact in this flow), not a physical/
silicon claim about reset-net signal integrity in general.

**Disposition**: closing this epic's own narrow, explicitly-stated
Measurement-Epoch deliverable as done (items 1, 3-6 above are real,
separate, follow-on engineering work — a CI/regression/multi-block/
Cyclopter-wiring effort in their own right, not a continuation of "did the
measurement happen"; item 2, the DRVs, is closed via the classification
above, not left open). A future ticket should own items 1, 3-6 if the full
tape-out-grade Green flow is still wanted; this epic does not claim to
have done that work.

---
## Telemetry & Evaluation

**Final State:** `done` (Measurement Epoch deliverable only — see the 5
explicitly-open items above — items 1, 3-6 — not claimed as closed by this
telemetry; item 2, the max-slew DRVs, is closed via the documented
classification, not left open).
**Color:** `blue` — solid, validated engineering (a real, working,
version-pinned toolchain; a real ASAP7 config; a real, cross-checked,
timing-closed physical measurement feeding `TKT-019`; the DRV item closed
by two genuine remediation attempts plus a documented root-cause and
disposition, not by silently dropping it), but not `green`
(no CI regression, single block only, SDC not single-sourced).
**Vector summary:** spec 0.8 (the stated Measurement-Epoch deliverable is
fully met; the separate, broader "Green Target" 7-item checklist is not —
hence < 1.0), quality 0.65 (the underlying `GCB-027`→`033` work is itself
rigorous and cross-checked, and the DRV item's closure is backed by two
real flow re-runs, not assumed — revised up slightly from 0.6 for that;
this epic's OWN ticket still sat with a stale, blank Execution Log until
the earlier correction, which is why this isn't higher), emergence 0.0 (no
new architectural surface; this is a ledger-accuracy correction over
already-completed work, not new capability).
