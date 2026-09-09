---
id: TKT-017
title: "EPIC — Compute execution units: verified INT4 matrix-multiply tiles between the SRAM macros and the Softmax/QAM blocks"
date_created: 2026-09-09
status: open
telemetry_color: pending
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
*(To be populated during execution — spawns sub-stories TKT-017.x)*

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
