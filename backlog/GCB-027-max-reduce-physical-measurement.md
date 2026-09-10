---
id: GCB-027
title: "Story 1 of the Measurement Epic (TKT-018) — gcb_max_reduce through the isolated OpenROAD / ASAP7 flow"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - eda
  - physical-design
  - measurement-epoch
  - openroad
  - asap7
  - orange
---

# Objective

**Story 1 of EPIC `TKT-018` — the Measurement Epoch** (mandate: [[TKT-000]],
"Physical Reality First"). Push the fully verified **`gcb_max_reduce`** macro
(TKT-016) through the **isolated** OpenROAD-flow-scripts / ASAP7 physical-design
flow — **deliberately unoptimized** — to extract the first physical
measurements of GreenCoyote-Bay's DSP logic: cell area, timing (`WNS` / `TNS`),
routing congestion, power, DRC classes.

The output that matters is the **`report.json` + `floorplan.png` + a written
interpretation**, not a clean GDSII. A negative slack or a congested route is a
**successful measurement**; it is the silicon feedback the architecture has
never had, and it gates the optical-transport decisions in `TKT-019`.

## Context & Constraints

* **The block.** `gcb_max_reduce.sv` (TKT-016): a parameterised comparator /
  tournament-reduce tree, Verilator-5 `sim/lint.sh`-clean, `sv2v` → Yosys 0.68
  elaborated and latch-free (golden: `gcb-wdm-transceiver/sim/yosys068_bless/
  max_reduce.stat` — 945 cells at `WIDTH=16 N_ELEMENTS=64`). The smallest
  fully-verified macro, and a **3-site shared primitive** (QAM slice, softmax
  `x − max(x)`, requantize block-float scale — GCB era / TKT-023) — so its PPA
  is load-bearing across the datapath, which is why it is measured first.
* **The tools.** OpenROAD + ORFS built from source in TKT-021
  (`build_openroad.sh --local`); KLayout **0.30.12**; **ASAP7** open PDK (the
  7nm / 5nm educational equivalent; the flow stays PDK-parameterised so a real
  node drops in later).
* **Isolation — non-negotiable ([[TKT-000]] toolchain split).**
  * The entire flow runs in the **isolated P&R environment**. It never runs
    `apt` / `pip` / `uv` against the RTL Baseline guest or `~/.venvs/cocotb19`.
  * The RTL / P&R boundary is a **file**: the P&R env consumes an elaborated
    netlist (ORFS Yosys synth from the frozen `gcb_max_reduce.sv`, or the
    `sv2v` → Yosys netlist), and emits reports. No shared tool binary, no shared
    `PATH`.
  * **Drift tripwire (standing gate, [[TKT-000]] invariant 2).** After the P&R
    run, re-execute the RTL Baseline: `bash sim/lint.sh` (exit 0) + the
    `sim/run_tb.sh` cocotb stanzas + a toolchain-manifest diff. A non-empty
    diff or a `FAIL ≠ 0` is a **blocker** — the P&R environment leaked. Record
    the tripwire result clean in the Execution Log.
  * **ASAP7 / any PDK material stays in the P&R environment** — never in
    `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host` (`gcb-wiki/04` + `10`).
* **Deliberately unoptimized ([[TKT-000]]).** Default ORFS recipe, one config,
  one pass. **No** floorplan hand-optimization, **no** timing-driven synth
  sweeps, **no** congestion ECOs, **no** clock relaxation to fake `WNS ≥ 0`.
  `gcb_max_reduce.sv` is frozen — not modified for any reason.
* **Geometry.** Start at the blessed bring-up config (`WIDTH=16
  N_ELEMENTS=64`); if the ASAP7 flow needs a different point, document the
  choice and why. State the target clock explicitly (pick one sane value, e.g.
  a 1–2 ns period, and *report the result*, do not tune the clock to the
  result).

## AI Orchestration Priorities — the Orange Target (PBG-O, [[TKT-000]])

This story is graded **Orange**, not Green. Its worth is a **measurement that
can contradict an architectural assumption** — not an in-spec artifact.

* **Orange (target):** one default ORFS / ASAP7 pass of `gcb_max_reduce`
  producing a `report.json` + `floorplan.png` + a written interpretation.
  The report carries: clock period + `WNS` + `TNS`; cell area (µm² and ASAP7
  track terms) + instance count; estimated power; place / route utilization +
  a congestion metric; DRC violation **count by class** (recorded, not
  resolved). The interpretation answers: does the comparator tree close timing
  at a sane clock, or not — and by how much? is it timing-bound,
  congestion-bound, or area-bound? what does that imply for the digital
  headroom `TKT-019` optical serialization can assume?
* **A "brutal" result is a PASS.** Negative `WNS`, high congestion, DRC errors
  — captured, interpreted, filed as architecture-change hypotheses, **not
  fixed**. A clean, timing-closed, DRC-free result is *also* a valid
  measurement — it vindicates the "ugly first pass" mandate cheaply.
* **Reject (Red):** editing `gcb_max_reduce.sv` to improve the numbers;
  relaxing the clock until `WNS ≥ 0` and reporting that without the frequency;
  running any P&R tool in the RTL Baseline environment; committing ASAP7
  material into an RTL repo; a hand-run OpenROAD GUI session with no
  reproducible config.
* **Not this story (later `TKT-018` `GCB-###` stories):** SDC-from-Cocotb single
  source; the PPA regression (`make ppa-check`); *achieving* timing closure;
  DRC waiver policy; a second block; `make gds` productionisation; wiring the
  GDS into the TKT-001 viewer. All deferred until the first numbers are in.

## The "Orange" Target (acceptance)

1. An ORFS config for `gcb_max_reduce` at a documented geometry and a stated
   target clock, checked into an EDA-flow location **outside `gcb-rtl` /
   `gcb-wdm-transceiver`** (a dedicated EDA repo / the P&R env's own tree —
   decide at execution).
2. One `make` run through synth → floorplan → place → CTS → route → (attempt)
   DRC → GDS. It **completes, or fails at a named stage** — either way the
   stage and the reason are recorded.
3. `report.json`: clock period, `WNS`, `TNS`, cell area (µm² + tracks),
   instance count, estimated power, utilization, congestion metric, DRC
   violation count by class.
4. `floorplan.png` (ORFS render or a KLayout 0.30.12 DEF render).
5. `GCB-027-FINDINGS.md` — the written interpretation: timing- vs congestion-
   vs area-bound; the headroom (or deficit) this implies for `TKT-019`; and any
   architecture-change hypotheses to file as their own `GCB-###` tickets.
6. The **RTL Baseline drift tripwire re-run clean** after the P&R pass,
   recorded: `sim/lint.sh` exit 0, cocotb `FAIL = 0`, manifest diff empty.
7. Diff confined to the new EDA-flow directory + `GCB-027-FINDINGS.md`. Nothing
   in `gcb-rtl` / `gcb-wdm-transceiver`; `gcb_max_reduce.sv` untouched; no PDK
   material in any RTL repo.

### Toolchain

RTL Baseline pin (`gcb-wdm-transceiver/sim/toolchain_manifest.json`) is
**unchanged** and is only *referenced* here as the frozen side of the split.
The P&R environment is the isolated side per [[TKT-000]].

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution — expected grade: `orange`, per [[TKT-000]].)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
