# GCB-027 — FINDINGS: first physical measurement of `gcb_max_reduce`

**EPIC TKT-018 (Measurement Epoch) · Story 1 · per [[TKT-000]] "Physical Reality First"**
Physical Design Engineer + Orange Team Auditor · 2026-09-10 ·
session `01Rpa9VJGe7xypzp5FkukSco`

Raw, **deliberately unoptimized** OpenROAD-flow-scripts / ASAP7 pass of the
TKT-016 `gcb_max_reduce` macro. Not a signed-off result — a measurement.
Structured data: `gcb-workspaces/eda/GCB-027/report.json`. Curated reports +
layout PNGs: `gcb-workspaces/eda/GCB-027/`. Full artifacts
(`6_final.{gds,def,v,spef}`, 11 MB GDS) left in the **isolated P&R environment**
at `~/eda/OpenROAD-flow-scripts/flow/results/asap7/gcb_max_reduce/base/`.

## Setup

| | |
|---|---|
| Design | `gcb_max_reduce` at default params — `WIDTH=16 N_ELEMENTS=64 MODE=MAX OUTPUT=BOTH SIGNED_CMP=1 TIE_LOW=1 REG_STAGES=0` → **purely combinational** tournament tree |
| Source | RTL-Baseline `sv2v 0.0.12` output of `gcb_max_reduce.sv`, handed to the P&R env at a **file boundary** (`~/eda/…/flow/designs/src/gcb_max_reduce/gcb_max_reduce.v`). Nothing written under `gcb-wdm-transceiver`. |
| Platform | `asap7` (educational 7/5nm-class; 4× DBU upscale) |
| Tools | ORFS local build (TKT-021); OpenROAD `26Q3-1953-gc6c0900a16`; **ORFS-bundled Yosys 0.68+** (isolated from the RTL Baseline's system Yosys); KLayout 0.30.12 |
| Recipe | **default ORFS, zero tuning** — no floorplan opt, no timing-driven synth sweeps, no ECOs, no clock relaxation |
| Constraint | stated target **1000 ps** clock; I/O delay 20 %; `clk`/`rst_n` drive nothing (REG_STAGES=0) so the timed paths are `vec_flat → max_val/max_idx` against a virtual clock |
| Stages | synth → floorplan → place → CTS → route → fillcell → **finish** (all completed) |

## The measurements

### Area — NOT the bottleneck
| metric | value |
|---|---|
| Synth cell area (Yosys, ASAP7-mapped) | **618.75 µm²**, **6 240 cells**, **0 % sequential** |
| Post-route design area (w/ buffers + fill) | **901 µm²**, **59 % utilization** |
| Filler / decap instances | 8 838 |
| Cell mix tell | **1 008 `HAxp5` half-adders**, 897 `INVx1`, 623 `OA21x2`, 601 `AO21x1`, 412 `AND2x2` |

619 µm² is tiny. Even at 59 % utilization the placed block is trivially small for
ASAP7. **Not area-bound.**

### Timing — the bottleneck
| metric | value (against the 1000 ps target) |
|---|---|
| **WNS** (worst negative slack) | **−665.45 ps** |
| **TNS** (total negative slack) | **−14 420.39 ps** |
| Setup-violating paths | **22** |
| Hold violations | **0** |
| Implied min period | **≈ 1 665 ps** → **≈ 600 MHz** (ASAP7-scaled) |
| Met target? | **NO** |

The worst path runs `vec_flat → max_val` as a **~1.67 ns combinational cone**: a
compare-select chain through all `⌈log2 64⌉ = 6` tournament levels, **interleaved
with `HAxp5` index arithmetic** — `OUTPUT="BOTH"` propagates the winning *index*
alongside the *value* at every level, and the 1 008 half-adders are that index
datapath. `max_slew` / `max_fanout` / `max_cap` violations: **0** — it is not a
drive/electrical problem, it is raw logic depth.

### Power
| metric | value |
|---|---|
| Total | **22.0 mW** (100 % combinational; 0 sequential, 0 clock) |
| Internal / switching / leakage | 12.2 mW / 9.85 mW / 0.62 µW |

Against ORFS's default (high) switching-activity assumption for a combinational
block — an upper-ish estimate, not a datasheet number.

### Routing / DRC — NOT the bottleneck
| metric | value |
|---|---|
| **Detailed-route DRC violations** | **0** (`5_route_drc.rpt` is 0 bytes) |
| Antenna violations | **0 net, 0 pin** |
| Detailed route | converged, 64-iter budget, 127 s |
| Wirelength / vias | 24 841 µm / 84 742 vias, layers **M2–M7** (M8/M9 unused) |
| Congestion | route converged with no overflow at 59 % util |

Clean route, half the metal stack unused. **Not routing-bound.**

## Orange Team interpretation

**`gcb_max_reduce` is TIMING-BOUND, and only timing-bound.**

* Not area-bound (619 µm²), not routing-bound (0 DRC, 0 antennas, M8/M9 free),
  not electrical (0 slew/cap/fanout). The single physical fact this pass
  extracts is **logic depth**: a `N=64`, `OUTPUT="BOTH"` tournament reduce is a
  ~1.67 ns cone in ASAP7 and **cannot** be dropped single-cycle into anything
  faster than ~600 MHz.

* **This falsifies a standing assumption.** `gcb_max_reduce` was verified and
  reused (TKT-016, then 3 sites: QAM slice, softmax `x − max(x)`, GCB-era
  requantize scale) as a `REG_STAGES=0` combinational primitive. Functionally
  correct — but physically it is a multi-cycle block. The `4096 MAC/cycle`
  compute result (EPIC TKT-017) never touched `gcb_max_reduce` on its critical
  path; the moment it does (the requantize hand-off), the datapath clock is
  capped by this cone unless it is pipelined.

* **Architecture-from-measurement hypotheses to file as `GCB-###` tickets:**
  1. Instantiate `gcb_max_reduce` with **`REG_STAGES ≥ 2`** everywhere it sits
     on a timed path — the parameter already exists (TKT-016), synthesis
     retiming distributes the registers into the tree. All 3 consumers tolerate
     latency.
  2. The **`OUTPUT="BOTH"` index datapath is half the cost** (1 008 HAx). Sites
     that only need the *value* (softmax `x − max(x)`, requantize scale) should
     instantiate `OUTPUT="VALUE"` — measure the WNS delta.
  3. **TKT-019 optical serialization must budget `gcb_max_reduce` as a 2–3 cycle
     pipelined block**, not a single-cycle one, when sizing the QAM-slice path.
  4. A `N`-radix or 4-ary tournament variant (fewer levels, wider compares) is a
     candidate if 2 doesn't buy enough — a later trade study, not now.

* Area and power are a **non-issue** at this size; no action.

## Infrastructure findings (Orange Team Auditor)

1. **ORFS `make -j 2` races from cold.** `make DESIGN_CONFIG=… -j 2` with no
   prior `synth` failed at `1_2_yosys.sdc` / `2_1_floorplan.sdc` ("No rule to
   make target") — recursive-make + generated-includes + parallelism.
   **Workaround:** `make … synth` serially first, then `make … -j 2`. The
   `-j 2` throttle is for the OpenROAD *build*; the flow's own peak is
   single-threaded route at **1.84 GB** — comfortable on the 8 GB host.

2. **`kepler-formal` (ORFS CTS logical-equivalence check) is broken by the same
   TKT-021 drift that hit the RTL baseline.** It is linked against
   `libpython3.12.so.1.0`, which the shared-guest Python 3.12 → 3.14 move
   removed:
   `error while loading shared libraries: libpython3.12.so.1.0: cannot open shared object file`.
   **Worked around** with `LD_LIBRARY_PATH` → the uv-managed CPython 3.12.14
   runtime lib (`~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib`).
   This is a **read-only** shim inside the P&R env — it installs nothing and
   does **not** touch `~/.venvs/cocotb19`. **A real fix is a P&R-environment
   ticket:** rebuild `kepler-formal` against 3.14, or bundle its 3.12 runtime.
   → This is itself an Orange-style finding: TKT-021's un-isolated drift reached
   *both* sides of the split. [[TKT-000]]'s isolation mandate is retroactively
   validated — and the P&R env still needs its own hardening pass.

## Task 3 — RTL Baseline drift tripwire (post-P&R)

**PASS. The OpenROAD/ASAP7 run did not corrupt the RTL Baseline.**

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** — Verilator 5.032, sv2v 0.0.12, Yosys 0.68, node v22.22.1, venv Python 3.12.14, cocotb 1.9.2, numpy 2.5.3 all unchanged |
| `~/.venvs/cocotb19` | intact (cocotb 1.9.2 / numpy 2.5.3) |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb smoke (TKT-020 R1 `Makefile.sram_partial`) | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`**, `%Error TKT-020/R1` fires |

ORFS ran entirely on its **own bundled Yosys/OpenROAD**, no package manager, no
`PATH` overlap with the RTL Baseline. The only cross-touch was the read-only
`LD_LIBRARY_PATH` shim in finding 2. The [[TKT-000]] toolchain split held.

## Reproduce

Isolated P&R env: `~/eda/OpenROAD-flow-scripts`
```
sv2v gcb-wdm-transceiver/rtl/gcb_max_reduce.sv > flow/designs/src/gcb_max_reduce/gcb_max_reduce.v
# config: gcb-workspaces/eda/GCB-027/config/{config.mk,constraint.sdc}
cd flow && source ../env.sh
export LD_LIBRARY_PATH=~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib:$LD_LIBRARY_PATH
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk synth      # serial first
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk -j 2       # to finish
```
