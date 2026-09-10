---
id: GCB-029
title: "Story 2 of the Measurement Epic (TKT-018) — physical validation of the GCB-028 pipeline response (gcb_max_reduce REG_STAGES=2)"
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

**Story 2 of EPIC `TKT-018` — the Measurement Epoch** (mandate: [[TKT-000]]).
[[GCB-027]] measured `gcb_max_reduce` at defaults (`REG_STAGES=0`) as a
**~1.67 ns combinational cone** (`WNS = −665.45 ps` @ a 1 ns target).
[[GCB-028]] responded by instantiating it with `REG_STAGES = 2` in the
requantize path (functionally proven +latency-only, `stall_count == 0`
unchanged end-to-end).

This ticket **physically validates that response**: push `gcb_max_reduce` with
**`REG_STAGES = 2`** through the *exact same* isolated OpenROAD / ASAP7 flow as
GCB-027 — same SDC, same 1 ns target, same default recipe, **zero tuning** — and
measure the delta. The output is an **experimental transfer function**:
architectural pipeline injection → physical consequence (WNS, TNS, area, cell
count, congestion, critical-path shape).

**We are NOT pursuing timing closure.** A residual negative WNS, or new
register-to-register paths that themselves violate, are *successful
measurements* — the raw physical truth of what 2 pipeline stages actually bought.

## Context & Constraints

* **Only difference from GCB-027:** the top-module parameter `REG_STAGES = 2`,
  applied via ORFS `VERILOG_TOP_PARAMS` (`chparam -set REG_STAGES 2` before
  synthesis). Same `gcb_max_reduce.sv` source (unchanged by GCB-028), same
  `sv2v` netlist, same `constraint.sdc` (1000 ps target, virtual-clock I/O),
  same `CORE_UTILIZATION` / `PLACE_DENSITY`, same platform. The comparison is
  apples-to-apples by construction.
* **Isolation ([[TKT-000]] toolchain split):** entire flow in the isolated P&R
  environment; no package manager against the RTL Baseline guest or
  `~/.venvs/cocotb19`; the `kepler-formal` CTS-LEC `LD_LIBRARY_PATH` runtime
  shim from GCB-027 is re-used (read-only); after the run, re-execute the RTL
  Baseline drift tripwire (`bash sim/lint.sh` + manifest diff) and record it
  clean.
* **Deliberately unoptimized ([[TKT-000]]):** default ORFS recipe, one config,
  one pass. No floorplan opt, no synth sweeps, no ECOs, no clock relaxation.
  `gcb_max_reduce.sv` frozen.
* ASAP7 / PDK material stays in the P&R env; nothing in an RTL repo.

## AI Orchestration Priorities — the Orange Target (PBG-O, [[TKT-000]])

Graded **Orange** — the deliverable is a measurement + a before/after transfer
function, not an in-spec artifact.

* **Orange (target):** a `report.json` + `floorplan.png` from one default
  ORFS / ASAP7 pass of `gcb_max_reduce` at `REG_STAGES=2`, and
  **`GCB-029-FINDINGS.md`** — a direct GCB-027-vs-GCB-029 table for:
  **cell area, cell count, WNS @ 1 ns, TNS, setup-violating path count,
  critical-path structure, routing congestion / DRC, power** — plus an analysis:
  did the pipeline break the 1.67 ns cone? what is the new worst path (still
  input→output combinational, or now register→register)? are there *new*
  timing paths the registers introduced?
* **A "bad" delta is a PASS.** If `REG_STAGES=2` only halves the cone (WNS still
  negative), that is the measured transfer function — recorded, interpreted, not
  fixed. If it fully closes, that is also a valid measurement.
* **Reject (Red):** editing `gcb_max_reduce.sv`; relaxing the 1 ns SDC;
  changing any floorplan/synth knob vs GCB-027; running P&R in the RTL Baseline
  env; committing PDK material to an RTL repo.
* **Not this story (later `GCB-###`):** `REG_STAGES=3+` sweeps; achieving
  `WNS ≥ 0`; the `OUTPUT="VALUE"` area trade; a 4-ary tournament variant; SDC
  from Cocotb; the PPA regression.

## The "Orange" Target (acceptance)

1. ORFS run of `gcb_max_reduce` with `VERILOG_TOP_PARAMS = REG_STAGES 2`, same
   1 ns SDC, same recipe as GCB-027; config diff = that one line.
2. Flow completes (or fails at a named stage — recorded). `report.json` +
   `floorplan.png` into `gcb-workspaces/eda/GCB-029/`.
3. `GCB-029-FINDINGS.md` — the GCB-027 → GCB-029 transfer function table
   (area, cell count, WNS, TNS, congestion, DRC, power) + the critical-path
   analysis (broke the cone? new register paths?).
4. RTL Baseline drift tripwire re-run clean and recorded.
5. Diff confined to `gcb-workspaces/eda/GCB-029/` + `GCB-029-FINDINGS.md`.
   Nothing in `gcb-rtl` / `gcb-wdm-transceiver`; no PDK material in any RTL
   repo.

### Toolchain

RTL Baseline pin unchanged; P&R environment per [[TKT-000]].

---
## Execution Log

### 2026-09-10 (session 01Rpa9VJGe7xypzp5FkukSco) — Physical Design Engineer + Orange Team Auditor

Full detail + the machine-readable delta table: **[[GCB-029-FINDINGS]]** and
`gcb-workspaces/eda/GCB-029/report.json`. Layout PNGs + curated reports:
`gcb-workspaces/eda/GCB-029/`.

* **Setup.** Same `sv2v` netlist as GCB-027 (`gcb_max_reduce.sv` unchanged by
  GCB-028), same `constraint.sdc` (1000 ps, virtual-clock I/O), same
  `CORE_UTILIZATION=40 / PLACE_DENSITY=0.55`, same default recipe, no tuning.
  **Only config diff:** `export VERILOG_TOP_PARAMS = REG_STAGES 2` (ORFS
  `chparam -set REG_STAGES 2 gcb_max_reduce` before synth). Ran `make synth`
  serially then `make -j 2` (GCB-027 finding 1); `kepler-formal` CTS-LEC
  `LD_LIBRARY_PATH` → uv CPython 3.12.14 shim re-used (read-only).
* **Flow completed** synth → floorplan → place → CTS → route → fillcell →
  **finish**. `6_final.gds` produced. DRC report 0 bytes; 0 antennas.

* **Transfer function — GCB-027 (`REG_STAGES=0`) → GCB-029 (`REG_STAGES=2`):**

  | metric | GCB-027 | GCB-029 | Δ |
  |---|---:|---:|---:|
  | **WNS @ 1 ns** | −665.45 ps | **−442.09 ps** | **+223.36 ps (+33.6 %)** |
  | **TNS** | −14 420.39 ps | **−9 570.50 ps** | **+33.6 %** |
  | setup-violating paths | 22 | 22 | 0 |
  | synth cell area | 618.75 µm² | 621.41 µm² | +2.66 µm² (**+0.43 %**) |
  | sequential area | 0 | 17.44 µm² (2.81 %) | **+46 flops** (`DFFASRHQNx1`) |
  | post-route area | 901 µm² @ 59 % | 884 µm² @ 57 % | −17 µm² |
  | **total power** | 22.0 mW | **17.8 mW** | **−19.1 %** |
  | wirelength / vias | 24 841 µm / 84 742 | 24 927 µm / 83 025 | +86 µm / −1 717 |
  | DRC / antennas / layers | 0 / 0 / M2–M7 | 0 / 0 / M2–M7 | unchanged |

* **Critical-path analysis.** The worst path is **still `input → max_val[*]`,
  combinational**, still 22 violators. `gcb_max_reduce`'s `REG_STAGES` is an
  **output** pipeline (`val_pipe[s] <= val_pipe[s-1]` — TKT-016), so the two
  new register→register segments carry **zero logic** and meet 1 ns trivially
  (`val_pipe[0]→val_pipe[1]` slack MET +29.98 ps; `vld_pipe→out_valid` MET;
  `rst_n` async-removal MET +178 ps). The +223 ps of WNS is a **resizing** gain
  from the cone terminating at a flop instead of a port — **not** a logic-depth
  gain. Default ORFS synth **does not run register retiming**, so the 46 flops
  stayed downstream of the whole reduce cone and the ~1.44 ns input-side segment
  is unbroken.
* **Verdict.** `+2 output pipeline stages` → −34 % WNS/TNS, −19 % power,
  +0.43 % area, congestion/DRC unchanged. **Timing NOT closed at 1 ns.** This
  **falsifies** the assumption (GCB-027 hypothesis 1 + the TKT-016 comment) that
  `REG_STAGES=2` alone closes 1 ns via retiming.
* **Hypotheses filed in [[GCB-029-FINDINGS]]:** (1) enable register retiming in
  a P&R-side synth sweep and re-measure — flow knob, not RTL; (2) a mid-tree
  pipelined `gcb_max_reduce` variant if retiming is not enough — RTL, own
  ticket; (3) `OUTPUT="VALUE"` (drop the 1 008-`HAxp5` index cone); (4) a
  `REG_STAGES=3/4` sweep.

### Task 4 — RTL Baseline drift tripwire (post-P&R) — **PASS**

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** (all 7 tools unchanged) |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`** |

ORFS on its own bundled Yosys/OpenROAD, no package manager; only cross-touch the
read-only `kepler-formal` `LD_LIBRARY_PATH` shim. The [[TKT-000]] split held.

### Artifacts touched

* `gcb-workspaces/eda/GCB-029/` (new) — `report.json`, `floorplan.png` +
  `congestion.png` + `worst_path.png`, `config/{config.mk,constraint.sdc}`,
  `reports/` (synth_stat, 6_finish, 5_route_drc, 5_global_route, 4_cts_final,
  2_floorplan_final, 3_resizer).
* `gcb-workspaces/backlog/GCB-029-FINDINGS.md` (new).
* **Nothing** in `gcb-rtl` / `gcb-wdm-transceiver`; `gcb_max_reduce.sv`
  untouched; no ASAP7/PDK material in any RTL repo. The ORFS design config
  (`flow/designs/asap7/gcb_max_reduce/config.mk` — now carrying
  `VERILOG_TOP_PARAMS`) and full outputs live in the isolated P&R env, out of
  git; GCB-027's config is preserved at `eda/GCB-027/config/`.

---
## Telemetry & Evaluation

**Final State:** `orange`

**Vector Summary:** `PBG-O = orange` (Physical Falsifiability) — **SATISFIED**.

Per [[TKT-000]], Orange grades whether the artifact has been confronted with
physical reality and can be falsified by it.

* **The pass produced a clean before/after transfer function** and **falsified a
  working assumption**: `REG_STAGES=2` alone does *not* close 1 ns, because
  `gcb_max_reduce`'s pipeline is output-only and default ORFS synth runs no
  retiming. `+2 stages` measured at **−34 % WNS/TNS, −19 % power, +0.43 % area**,
  timing still open. That contradiction is a **positive Orange result** — the
  quantified physical consequence the architecture had assumed rather than
  measured.
* R³ axes deliberately not optimized (timing closure was explicitly *not* the
  goal). For the record only: X ≈ 0, Y ≈ +0.5 (the measurement was clean — one
  parameter changed, same SDC, same recipe, RTL frozen, tripwire green), Z = 0.
* **What makes it a valid Orange measurement:** the config diff vs GCB-027 is a
  single line, the 1 ns SDC was not relaxed, no floorplan/synth knob was
  touched, and the RTL Baseline came back clean.

Cyclopter scavenger (TKT-013) ingests this as the second `orange` child of
EPIC TKT-018 — the pair `GCB-027 (baseline)` → `GCB-028 (green response)` →
`GCB-029 (validation: response measured, assumption falsified)` is the epoch's
measure → change → re-measure loop.
