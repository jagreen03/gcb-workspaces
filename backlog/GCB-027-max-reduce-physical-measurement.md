---
id: GCB-027
title: "Story 1 of the Measurement Epic (TKT-018) — gcb_max_reduce through the isolated OpenROAD / ASAP7 flow"
date_created: 2026-09-10
status: done
telemetry_color: orange
telemetry:
  pbg_o: orange
  disposition: physical-falsifiability
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

### 2026-09-10 (session 01Rpa9VJGe7xypzp5FkukSco) — Physical Design Engineer + Orange Team Auditor

Full detail + all numbers: **[[GCB-027-FINDINGS]]**. Artifacts:
`gcb-workspaces/eda/GCB-027/` (`report.json`, `floorplan.png`, `congestion.png`,
`layout_all.png`, `config/`, `reports/`); `6_final.{gds,def,v,spef}` left in the
isolated P&R env (`~/eda/OpenROAD-flow-scripts/flow/results/asap7/gcb_max_reduce/base/`).

* **Config.** `DESIGN_NAME=gcb_max_reduce`, `PLATFORM=asap7`, source =
  RTL-Baseline `sv2v` output handed over at a file boundary (nothing written
  under `gcb-wdm-transceiver`). Stated target **1000 ps**; default ORFS recipe,
  **zero tuning**. Ran `-j 2` per the mandate (after `make synth` serially — see
  finding 1).
* **Flow completed** synth → floorplan → place → CTS → route → fillcell →
  **finish**. `6_final.gds` (11 MB) produced.
* **The measurement (unoptimized, ASAP7, 1000 ps target):**
  * **Area — not the bottleneck.** Synth **618.75 µm², 6 240 cells, 0 %
    sequential**; post-route 901 µm² @ **59 % utilization**.
  * **Timing — the bottleneck. `WNS = −665.45 ps`, `TNS = −14 420.39 ps`,
    22 setup-violating paths, 0 hold.** Implied min period ≈ **1 665 ps
    (≈ 600 MHz** ASAP7-scaled**)** — the target is **missed**. Worst path is a
    ~1.67 ns combinational cone: compare-select through 6 tournament levels
    interleaved with `OUTPUT="BOTH"` index arithmetic (**1 008 `HAxp5`**
    half-adders). 0 slew/cap/fanout violations — pure logic depth.
  * **Power** 22.0 mW, 100 % combinational (ORFS default activity — upper-ish).
  * **Routing — not the bottleneck. 0 detailed-route DRC violations**
    (`5_route_drc.rpt` = 0 bytes), **0 antenna** net/pin, route converged,
    24 841 µm wirelength, M2–M7 only (M8/M9 free).
* **Orange Team verdict: TIMING-BOUND, and only timing-bound.** This
  **falsifies** the standing "drop-in single-cycle" assumption for
  `gcb_max_reduce` — functionally a verified `REG_STAGES=0` primitive, but
  physically a ~1.67 ns cone. Hypotheses filed in [[GCB-027-FINDINGS]]:
  (1) `REG_STAGES ≥ 2` on every timed instantiation (retiming distributes it);
  (2) `OUTPUT="VALUE"` where the index is unused (~half the cost);
  (3) TKT-019 must budget the QAM-slice max-reduce as a 2–3 cycle pipelined
  block; (4) a 4-ary tournament variant is a later trade study.
* **Infrastructure findings:** (1) ORFS `make -j 2` races from cold — `make
  synth` serially first. (2) **`kepler-formal` (ORFS CTS LEC) is broken by the
  same TKT-021 Python 3.12→3.14 drift** (linked against
  `libpython3.12.so.1.0`); worked around with a **read-only** `LD_LIBRARY_PATH`
  → the uv-managed CPython 3.12.14 runtime lib — no install, `~/.venvs/cocotb19`
  untouched. A real fix is a P&R-environment hardening ticket. → TKT-021's
  un-isolated drift reached *both* sides of the split; [[TKT-000]]'s isolation
  mandate is retroactively validated and the P&R env still needs its own pin.

### Task 3 — RTL Baseline drift tripwire (post-P&R) — **PASS**

The OpenROAD/ASAP7 run **did not corrupt the RTL Baseline**:

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** (Verilator 5.032 / sv2v 0.0.12 / Yosys 0.68 / node v22.22.1 / venv Python 3.12.14 / cocotb 1.9.2 / numpy 2.5.3 — all unchanged) |
| `~/.venvs/cocotb19` | intact |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb smoke — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`**, `%Error TKT-020/R1` fires |

ORFS ran on its own bundled Yosys/OpenROAD, no package manager, no `PATH`
overlap. Only cross-touch: the read-only `LD_LIBRARY_PATH` shim above. The
[[TKT-000]] toolchain split held.

### Artifacts touched

* `gcb-workspaces/eda/GCB-027/` (new) — `report.json`, `floorplan.png` +
  `congestion.png` + `layout_all.png` (ORFS `.webp` → PNG via Pillow),
  `config/{config.mk,constraint.sdc}`, `reports/` (synth_stat, 6_finish,
  5_route_drc, 5_global_route, 4_cts_final, 2_floorplan_final, 3_resizer).
* `gcb-workspaces/backlog/GCB-027-FINDINGS.md` (new).
* **Nothing** in `gcb-rtl` / `gcb-wdm-transceiver`; `gcb_max_reduce.sv`
  untouched; no ASAP7/PDK material in any RTL repo. The ORFS design config
  (`flow/designs/{asap7,src}/gcb_max_reduce/`) and full outputs live in the
  isolated P&R env, out of git.

---
## Telemetry & Evaluation

**Final State:** `orange`

**Vector Summary:** `PBG-O = orange` (Physical Falsifiability) — **SATISFIED**.

Per [[TKT-000]], Orange is a disposition orthogonal to the R³ PBG axes: *has the
artifact been confronted with physical reality, and can it be falsified by it?*

* **The pass extracted a falsifiable measurement that contradicts an
  architectural assumption** — `gcb_max_reduce` at `WNS = −665 ps` against a
  1 ns target is a multi-cycle block, not the single-cycle combinational
  primitive it has been reused as. That negative number is a **positive Orange
  result** — the silicon feedback the datapath planning has never had.
* The R³ axes are **deliberately not optimized** (a manufacturable timing-closed
  GDSII was explicitly *not* the goal). For the record only, not the grade:
  X ≈ 0 (no spec closed), Y ≈ +0.5 (the *measurement process* was clean —
  default recipe, honest numbers, RTL frozen, tripwire green), Z = 0.
* **What makes this a *valid* Orange measurement** and not a botched run: the
  flow used no tuning, `gcb_max_reduce.sv` was not touched, the target clock was
  stated up front and not relaxed to the result, and the RTL Baseline tripwire
  came back clean.

Cyclopter scavenger (TKT-013) ingests this as the first `orange`-graded child of
EPIC TKT-018 — the seed of the architecture-from-measurement cluster.
