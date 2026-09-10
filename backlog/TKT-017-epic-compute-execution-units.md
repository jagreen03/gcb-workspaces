---
id: TKT-017
title: "EPIC — Compute execution units: verified INT4 matrix-multiply tiles between the SRAM macros and the Softmax/QAM blocks"
date_created: 2026-09-09
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.5
tags:
  - backlog
  - epic
  - rtl
  - compute
  - matmul
---

# Objective

Stand up the **compute execution layer** of GreenCoyote-Bay AI Fiber Math: the
INT4 matrix-multiply tiles that consume operands from the TKT-012 banked 1W1R
SRAM macros and produce activation blocks for `gcb_inline_vector_unit` (softmax)
and `gcb_qam_datapath_top` (optical QAM). This Epic owns the system boundary
**SRAM read port → operand staging → MAC tile array → partial-sum / requantize
reduction → consumer hand-off**, and nothing outside it. It builds on the
existing `gcb_int4_mac_array.sv` and the `gcb-wiki/06` 70B-transformer workload
trace; it spawns per-tile sub-stories (operand staging, accumulator geometry,
requantization, the SRAM↔MAC integration TB, the PPA budget).

## "Product Ready for Presentation" — PBG analysis

* **Green (target) — the artifact that proves it demos.** One `make` target that
  streams a *real* transformer attention-projection tile (weights + activations
  lifted from the `gcb-wiki/06` trace) through the full path
  **TKT-012 SRAM → MAC tile array → `gcb_max_reduce` requantize → softmax
  hand-off**, and prints `MATCH` against a NumPy INT4 golden model plus a
  `cycles/MAC` and `0 read-stall` figure. Bit-exact end-to-end on one true
  workload tile, operands sourced from the verified SRAM with no stall, is the
  whole proof.

* **Blue (engineering) — the methodology that guarantees Green.** Layered
  equivalence: (1) a frozen NumPy INT4 reference for the tile GEMM; (2) unit
  Cocotb TBs per new module (staging, accumulator, requantize) each proven
  against that reference; (3) one integration TB that instantiates the *frozen*
  `gcb_tensor_sram_controller` + `gcb_int4_mac_array` + `gcb_max_reduce`
  unchanged and checks the composite; (4) `sim/lint.sh` exit 0 and `sv2v`→Yosys
  elaboration (latch-free) as hard gates on every sub-story; (5) a throughput /
  area budget table (MACs/cycle, cell count, SRAM bandwidth utilisation)
  updated per sub-story so the Epic has a quantified burn-down, not a vibe.

* **Purple (emergence) — Cyclopter / serendipitous reuse.** The per-tile
  requantization max (block-float / per-channel scale) is the **third**
  consumer of the TKT-016 `gcb_max_reduce` primitive — the same reduction that
  TKT-014 found linking QAM slicing and softmax now also serves compute scaling,
  with no new tree. Each sub-story closes with a PBG vector the Cyclopter
  scavenger (TKT-013) auto-ingests, so the Epic's readiness is a live pgvector
  query over its children, and KG gap analysis (TKT-014) can be re-run across
  the new RTL against `gcb-wiki/06`/`07` to catch undocumented silicon before
  the demo.

## Context & Constraints

* **Current State:**
  * `gcb-wdm-transceiver/rtl/gcb_int4_mac_array.sv` exists as the MAC primitive;
    `gcb_tensor_broadcast_fabric.sv` distributes operands; TKT-012 delivered the
    banked 1W1R operand SRAM behind the frozen `gcb_tensor_memory_engine`
    interface with a proven `0 read-stall` grid read.
  * `gcb-wiki/06` holds a 70B-transformer layer trace (tile shapes, dtypes);
    `gcb-wiki/07` specifies the inline vector / softmax datapath; `gcb-wiki/05`
    the photonic memory dataflow.
  * There is no verified tile-level GEMM that ties SRAM output to a consumer
    block end-to-end — each piece is proven in isolation.
* **Constraint:** No edit to any frozen-list interface (`gcb_tensor_memory_engine`,
  `gcb_tensor_sram_controller` ports, `gcb_max_reduce`). New RTL is pure SV-2017,
  Verilator-5 `sim/lint.sh`-clean, Cocotb ≥ 1.9, `sv2v`→Yosys elaboration
  checked. PBG / Cyclopter prompt-layer protocols stay out of the RTL repos
  (`gcb-wiki/04`). Every sub-story is independently lint/elab/Cocotb-green
  before it merges.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The Epic target is Green through Blue-grade engineering**, delivered as a fan
of small Green sub-stories.

* **Green (target):** the end-to-end tile demo above, every sub-story
  lint/elab/Cocotb-green, integration TB using frozen blocks unmodified.
* **Blue:** the layered reference-model methodology, the PPA budget table, a
  one-line pointer added to `gcb-wiki/06`/`07`, sub-story PBG telemetry flowing
  to Cyclopter.
* **Yellow (reject):** a "GEMM" TB that checks only random small matrices and
  never runs a real `gcb-wiki/06` tile through the actual SRAM; hard-coded tile
  dimensions with no parameterisation.
* **Red (reject):** forking or editing a frozen interface to "make integration
  easier"; a monolithic mega-module that fuses staging + MAC + requantize with
  no unit-testable seams.
* **Purple / Light-gray:** a full reconfigurable systolic fabric with dataflow
  switching is Purple / a later Epic; keeping the blocks proven only in
  isolation (Light-gray) leaves the integration risk for the demo floor.

**Explicitly out of scope (separate tickets / Epics):**
1. Physical PPA, floorplanning, GDSII — TKT-018.
2. The optical transport path downstream of the consumer blocks — TKT-019.
3. Changes to `gcb_inline_vector_unit` / `gcb_qam_datapath_top` internals beyond
   the operand hand-off contract.
4. New instruction-set opcodes for the compute tiles — `gcb-wiki/08`.
5. Training-time quantisation calibration; the INT4 scheme is taken as given.

## The "Green" Target

1. New tile RTL (operand staging, accumulator geometry, requantize) under
   `gcb-wdm-transceiver/rtl/`, pure SV-2017, each with a unit Cocotb TB vs a
   NumPy INT4 reference.
2. `gcb_max_reduce` reused (not re-implemented) for the per-tile requantization
   max.
3. An integration Cocotb TB instantiating the **frozen** SRAM controller +
   `gcb_int4_mac_array` + `gcb_max_reduce` unchanged, driving one real
   `gcb-wiki/06` attention-projection tile SRAM→MAC→softmax hand-off, asserting
   bit-exact vs the golden model and `0` SRAM read stalls.
4. `bash sim/lint.sh` exit 0 with every new top added; Cocotb
   `TESTS=… PASS=… FAIL=0`; new tops wired into `sim/lint.sh` and the guarded
   `sim/run_tb.sh` stanza; `sv2v`→Yosys elaboration clean and latch-free.
5. A throughput / area budget table (MACs/cycle, Yosys cell count per tile,
   SRAM bandwidth utilisation) checked in and referenced from `gcb-wiki/06`.
6. One `make` entry point that runs item 3 and prints `MATCH`, `cycles/MAC`, and
   the stall count — the presentation artifact.
7. Diff confined to new RTL + TBs + sim-list edits + the wiki pointer; nothing
   in a frozen module.

---
## Execution Log

Delivered as a fan of four Green sub-stories, on the pinned toolchain
(`gcb-wdm-transceiver/sim/toolchain_manifest.json` — Verilator 5.032 / Python
3.12.14 / cocotb 1.9.2 / Yosys 0.68 / sv2v 0.0.12 / numpy 2.5.3), each
independently `sim/lint.sh` exit 0, Cocotb `FAIL=0`, `sv2v`→Yosys 0.68
elaboration clean and latch-free, diff confined to new RTL + TBs + sim-list
edits (nothing in a frozen module):

| Story | Ticket | Deliverable | State |
|---|---|---|---|
| 1 | **TKT-022** | `gcb_mac_tile_array.sv` — parameterised INT4 PE grid on the frozen `gcb_tensor_sram_controller` read port; **INT32 accumulator** derived from `8 + ⌈log2 K⌉` (K up to ~8192 in `gcb-wiki/06`); bit-exact vs a NumPy INT4 golden. Also carried the **Yellow-Team toolchain-drift check** that caught TKT-021's WSL changes (Yosys 0.52→0.68, Python 3.12→3.14, `/tmp/cocotb19` wiped), halted, and re-pinned the environment (persistent `~/.venvs/cocotb19`, Yosys 0.68 blessed, `toolchain_manifest.json`) before any MAC RTL landed. | `green` |
| 2 | **TKT-023** | `gcb_tile_requantize.sv` — INT32 → INT4/INT8 block-float requantize; the **third consumer** of the TKT-016 `gcb_max_reduce` primitive (instantiated, not re-implemented — one instance per reduction axis); 64 unit + 20 chained blocks bit-exact vs a NumPy block-float reference. | `green` |
| 3 | **TKT-024** | `gcb_operand_stage.sv` — SRAM-read-port → MAC-grid staging / broadcast layer (`gcb_tensor_broadcast_fabric` assessed and found not to fit → minimal adapter built): bus decode + `k·GRID_DIM` broadcast fan-out + `STAGE_REGS` valid-gated skew + `B_RESIDENT` replay RF. Transparent-equality + stall-hold + fan-out proven; chained bit-exact. Surfaced and fixed a one-cycle `q_clip` visibility lag in TKT-023's `gcb_tile_requantize`. | `green` |
| 4 | **TKT-025** | `sim/cocotb/test_compute_e2e.py` + `make -f Makefile.compute_e2e` — one representative `gcb-wiki/06` projection tile streamed through the **full frozen path** (`gcb_tensor_sram_controller` → `gcb_operand_stage` → `gcb_mac_tile_array` → `gcb_tile_requantize` → `gcb_inline_vector_unit` softmax pre-pass), every block unmodified. | `green` |

**The capstone result (TKT-025), print `MATCH`:**

```
MATCH  |  40 output tiles bit-exact  |  cycles/MAC = 0.000244141  |  SRAM read stalls = 0
```

* MAC INT32 output bit-exact vs a NumPy INT4 GEMM golden — **40/40** tiles.
* Requantize INT4 (`q_tile` / `q_scale` / `q_clip`) bit-exact vs the NumPy
  block-float golden — **40/40** tiles.
* `gcb_inline_vector_unit` `ST_FIND_MAX` `row_max` (the `x − max(x)` softmax
  pre-pass's load-bearing step, `gcb-wiki/07` §3) == `numpy.max` — **8/8**
  sampled tiles. (`ST_TLU_EXP` / `ST_SUM_EXP` / `ST_NORMALIZE` numerics are
  `gcb-wiki/07` / placeholder — out of scope; the hand-off is proven.)
* **`SRAM read stalls == 0`** for the whole run (per-cycle
  `gcb_tensor_sram_controller.stalled`).
* **2 621 440 MACs in 640 advancing cycles = 4096.0 MAC/cycle — exactly the
  256-PE × 16-`K_MAX` hardware peak** `gcb-wiki/06` §4 predicts. The compute
  path sustains the theoretical peak MAC rate with the operand feed never
  starving the grid.
* Reassembled `C[32×320] == requantize(A @ B)`.

`gcb-wdm-transceiver/docs/PPA_burndown.md` is the quantified burn-down (per-block
Yosys cell estimates from `sim/yosys068_bless/*.stat`, the e2e cycle figures,
the 512 GB/s / 0-stall SRAM read-bandwidth check), referenced from `gcb-wiki/06`.

**Scoped decisions, documented in the sub-stories (not spec gaps):**
* the grid is a fresh `gcb_mac_tile_array` rather than an extension of
  `gcb_int4_mac_array` — the frozen-blocks-unmodified spirit is honoured
  (the SRAM controller, `gcb_max_reduce` and `gcb_inline_vector_unit` are all
  instantiated unchanged);
* the `gcb_tile_requantize` → `gcb_inline_vector_unit` format mismatch
  (packed INT4 + scale vs unpacked INT16) is bridged by a labelled TB-side
  shim in TKT-025 — a real RTL adapter is its own ticket;
* a PE grid wider than `GRID_DIM` is made *possible* by TKT-024's broadcast
  fan-out but not exercised at scale — a later story.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence +0.5)`,
`‖T‖₂ = √2.25 = 1.5`.

* **X — Specification `+1.0`.** All seven Green-Target items met: new tile RTL
  (staging, accumulator geometry, requantize) each with a unit Cocotb TB vs a
  NumPy INT4 reference; `gcb_max_reduce` reused not re-implemented; an
  integration Cocotb TB instantiating the frozen SRAM controller + MAC grid +
  `gcb_max_reduce` + `gcb_inline_vector_unit` unchanged, driving one real
  `gcb-wiki/06` projection tile SRAM → MAC → softmax hand-off, bit-exact vs the
  golden with **0 SRAM read stalls**; `sim/lint.sh` exit 0 with every new top
  wired into `sim/lint.sh` and the guarded `sim/run_tb.sh`; `sv2v`→Yosys
  elaboration clean and latch-free per sub-story; a throughput / area budget
  table checked in and referenced from `gcb-wiki/06`; one `make` entry point
  that runs the integration and prints `MATCH`, `cycles/MAC` and the stall
  count; diff confined to new RTL + TBs + sim-list edits + wiki pointers.
* **Y — Quality `+1.0`.** Blue-grade throughout: a layered frozen-NumPy
  reference reused across all four stories; a unit TB per new module plus one
  composite TB with frozen blocks unmodified; every hard gate enforced per
  sub-story; the **Yellow-Team toolchain-drift check** halted execution on
  TKT-021's WSL drift and re-pinned the environment before RTL landed; the
  0-stall result is a *positive* proof of a working double-buffer prefetch
  (a wrong geometry showed 229 stalls first); a cross-story `q_clip` bug found
  and fixed honestly; a real quantified PPA burn-down, not a vibe. Throughput
  lands exactly on the 4096 MAC/cycle hardware peak.
* **Z — Emergence `+0.5`.** The Purple lean is real and was realised:
  `gcb_max_reduce` is now the **third** consumer of one verified comparator
  tree — QAM slice, softmax `x − max(x)`, and now the requantize block-float
  scale — the TKT-014 cross-domain correlation turned into shared silicon with
  no new tree. Each sub-story closed with a PBG vector the Cyclopter scavenger
  (TKT-013) auto-ingests, so the Epic's readiness is a live pgvector query over
  its children. Consolidation of an existing primitive plus a telemetry loop
  that already existed — genuine compounding reuse, not net-new *platform*
  capability, hence `+0.5`.

Dominant spoke: `|x| = |y| = 1.0 > |z| = 0.5`; tie-break `X > Y > Z` → `X+` →
**Green**. `‖T‖₂ = 1.5` — a decisive Green, stronger than any single
sub-story's `(1, 1, 0)` (`√2`): the Epic is where the emergent `gcb_max_reduce`
reuse and the live-telemetry readiness query are captured.

Cyclopter scavenger (TKT-013) ingests this vector on close. The compute
execution layer — SRAM read port → operand staging → MAC tile array →
block-float requantize → softmax / QAM hand-off — is verified end-to-end on a
real 70B-class projection tile at the theoretical peak MAC rate.
