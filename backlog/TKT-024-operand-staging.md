---
id: TKT-024
title: "Story 3 of EPIC TKT-017 — operand staging: the SRAM-read-port → MAC-grid staging / broadcast layer"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - compute
  - dataflow
  - epic-tkt-017
---

# Objective

**Story 3 of EPIC TKT-017** (Compute execution units). Insert the **operand-staging
layer** between the frozen `gcb_tensor_sram_controller` read port and the TKT-022
`gcb_mac_tile_array`, replacing the direct bus wire that TKT-022's bring-up TB
used. The staging layer owns everything on the boundary
**SRAM read port → operand staging → MAC grid** that is not the SRAM and not the
PE array:

1. **Bus decode.** Turn the controller's raw
   `sram_rdata [2*GRID_DIM*VEC_W]` bus (`{ A[GRID_DIM] rows, B[GRID_DIM] cols }`,
   each a `K_MAX`-deep INT4 vector) into a *named* operand interface the MAC grid
   consumes — so the grid, and future grid variants, stop hard-coding the
   controller's packing.
2. **Deterministic input skew (`STAGE_REGS`).** 0..N registered stages on the
   operand planes and `valid` to close timing between the SRAM macro read and the
   PE array, with `valid` tracked exactly and a clean drain. `STAGE_REGS = 0` is
   transparent — beat-for-beat identical to TKT-022's direct wire.
3. **Broadcast fan-out.** When the PE grid dims are integer multiples of the
   SRAM lane count (`GRID_M`, `GRID_N` = k·`GRID_DIM`), replicate each A row-lane
   across `GRID_M/GRID_DIM` PE rows and each B col-lane across `GRID_N/GRID_DIM`
   PE cols (weight-/activation-stationary reuse). `GRID_M = GRID_N = GRID_DIM` is
   identity fan-out.
4. **Stall-clean gating.** While `sram_valid` is low (controller stalled on a
   prefetch miss) the staged `valid` is low and the operand planes hold — no
   spurious beat reaches the MAC accumulators, which would corrupt a running
   dot product.
5. **Forward-compatible B-resident replay (`B_RESIDENT`, default off).** Capture
   each `(n_sub, k_step)` B column the first time it is seen in a pass and replay
   it on later A bands, so a future controller variant that streams B once per
   pass (rather than re-presenting it every beat) still feeds the grid.

**First execution step is an assessment,** not a green-field build: the existing
`gcb_tensor_broadcast_fabric.sv` is the operand distributor the controller header
says the two modules are "meant to be wired straight together". If its operand
output already matches the `gcb_mac_tile_array` input contract
(`beat_valid` / `a_row_bus` / `b_col_bus`), integrate it **unmodified** as the
staging layer. If it does not fit (different packing, different valid semantics,
no `STAGE_REGS`, no broadcast for k·`GRID_DIM`), build the minimal
`gcb-wdm-transceiver/rtl/gcb_operand_stage.sv` adapter that does — and record the
gap. Either outcome must be functionally identical end-to-end.

## Context & Constraints

* **Current State:**
  * TKT-022's `gcb_mac_tile_array` consumes `beat_valid` + `a_row_bus`
    (`GRID_M*VEC_W`) + `b_col_bus` (`GRID_N*VEC_W`) and its bring-up TB wired
    those **straight** off `gcb_tensor_sram_controller.sram_valid` /
    `sram_rdata[0 +: HALF]` / `sram_rdata[HALF +: HALF]`. That only works while
    `GRID_M = GRID_N = GRID_DIM` and imposes no timing decoupling.
  * `gcb_tensor_broadcast_fabric.sv` exists (with `tb/tb_gcb_tensor_broadcast_fabric.sv`)
    as the intended operand distributor; the controller header states it drives
    the fabric's `sram_valid` / `sram_rdata` port directly, "same width, same
    `{B,A}` packing".
  * TKT-023's `gcb_tile_requantize` sits downstream of the MAC array; its input
    contract (`acc_tile` / `tile_valid`) is unaffected by anything upstream of
    the grid.
  * `gcb-wiki/05` (photonic memory dataflow, weight-/output-stationary
    sequencing) and `gcb-wiki/06` (70B tile shapes) define the reuse geometry
    the fan-out has to serve.
* **Constraint:**
  * The frozen `gcb_tensor_sram_controller` read-port packing and
    `gcb_max_reduce` are **not touched**. The `gcb_mac_tile_array` and
    `gcb_tile_requantize` operand contracts are **treated as stable** — the
    staging layer *drives* the MAC array's existing `beat_valid` / `a_row_bus` /
    `b_col_bus` inputs; no port change to the grid.
  * `gcb_tensor_broadcast_fabric.sv` is **assessed and integrated**, not
    rewritten. A real bug found in it is filed back as its own ticket, not
    patched here.
  * One hand-written file at most — `gcb-wdm-transceiver/rtl/gcb_operand_stage.sv`
    — and only if the fabric does not already fit. Pure **SV-2017**, fully
    parameterised (`GRID_DIM`, `GRID_M`, `GRID_N`, `K_MAX`, `OPND_W`,
    `STAGE_REGS`, `B_RESIDENT`), no literal.
  * Verilator-5 `sim/lint.sh`-clean; Cocotb ≥ 1.9 on the **pinned** toolchain
    (`~/.venvs/cocotb19`, `sim/toolchain_manifest.json`); `sv2v`→Yosys **0.68**
    elaboration clean and latch-free against `sim/yosys068_bless/`.
  * PBG / Cyclopter prompt-layer protocol stays out of the RTL repo
    (`gcb-wiki/04`).

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-024 is Green, through Blue-grade engineering** — the
smallest staging layer that decouples the MAC grid from the controller's raw bus
and enables a grid wider than the SRAM lane count, proven to change nothing
functionally.

* **Green (target):** the staging layer (the existing
  `gcb_tensor_broadcast_fabric` integrated unmodified, **or** a minimal
  `gcb_operand_stage.sv` adapter if it does not fit), plus a Cocotb unit TB
  proving: (a) `STAGE_REGS = 0` is beat-for-beat identical to the raw controller
  bus; (b) `STAGE_REGS = n` delays `valid` + operands by exactly `n` with a
  clean drain; (c) broadcast fan-out replicates the correct lanes for
  `GRID_M, GRID_N = k·GRID_DIM`; (d) a low-`sram_valid` stall drives zero beats
  downstream while the operand planes hold; (e) `B_RESIDENT` replays the
  captured B set bit-exact. Plus a **chain integration TB**: frozen controller →
  staging → `gcb_mac_tile_array` → `gcb_tile_requantize` on real INT4 tiles,
  `q_tile` still bit-exact vs the NumPy golden — inserting the stage adds only
  latency at `STAGE_REGS > 0`, nothing else. `bash sim/lint.sh` exit 0 with any
  new top wired into `sim/lint.sh` and the guarded `sim/run_tb.sh` stanza;
  `sv2v`→Yosys 0.68 elaboration clean and latch-free at a `chparam` bring-up
  geometry; a `stat` row (cells, fan-out cost) for the TKT-017 PPA burn-down.
* **Blue:** a frozen reference the later end-to-end TB reuses; the fabric
  integrated as a pure instantiation with no glue, or the adapter shaped so a
  future grid-widening story is a parameter change; the TKT-022
  `mac_tile_array_tb_top` direct wire migrated to route through the stage (MAC
  RTL untouched); a one-line pointer added to `gcb-wiki/05`.
* **Yellow (reject):** a stage that only works at `GRID_M = GRID_N = GRID_DIM`
  (no broadcast) and calls it done — it does not unblock a wider grid, which is
  the whole point; or a stage that passes beats through during a controller
  stall, silently corrupting the running dot product.
* **Red (reject):** editing the frozen controller read-port packing or the
  `gcb_mac_tile_array` / `gcb_tile_requantize` operand contract to "make the
  wiring easier"; fusing staging into the MAC array and destroying the
  unit-testable seam TKT-022/023 established; rewriting
  `gcb_tensor_broadcast_fabric` in place instead of filing a bug.
* **Purple / Light-gray:** a full reconfigurable dataflow-switching operand
  network (weight- ↔ output-stationary at runtime) is Purple and a later Epic.
  Leaving `gcb_mac_tile_array` hard-wired to the raw controller bus
  (Light-gray) permanently caps the PE grid at the SRAM lane count.

**Explicitly out of scope (sibling TKT-017 sub-stories / other Epics):**
1. Actually widening `gcb_mac_tile_array` past `GRID_DIM` — the stage makes it
   *possible*; doing it (and its PPA) is a later sub-story.
2. A runtime dataflow-mode switch (output-stationary) — Purple / later Epic.
3. The frozen `gcb_tensor_sram_controller` / operand-SRAM internals and the
   read-port packing.
4. Any functional change to `gcb_tensor_broadcast_fabric.sv` beyond fixing a
   defect discovered during the assessment (which is filed as its own ticket).
5. Physical PPA / floorplan / GDSII — TKT-018.

## The "Green" Target

1. The staging layer in place between `gcb_tensor_sram_controller` and
   `gcb_mac_tile_array`:
   * **Path A** — `gcb_tensor_broadcast_fabric.sv` instantiated **unmodified**,
     if its operand output already matches the MAC array input contract; the
     Execution Log records the pin-for-pin mapping.
   * **Path B** — `gcb-wdm-transceiver/rtl/gcb_operand_stage.sv` (new,
     SV-2017, parameterised: `GRID_DIM`, `GRID_M`, `GRID_N`, `K_MAX`, `OPND_W`,
     `STAGE_REGS` = 0 default, `B_RESIDENT` = 0 default; no literal), if the
     fabric does not fit; the Execution Log records exactly which assumption
     broke.
2. Cocotb unit TB (`test_operand_stage.py` + wrapper + Makefile) proving items
   (a)–(e) from the Green bullet: transparent-equality, `STAGE_REGS` delay +
   drain, `k·GRID_DIM` broadcast fan-out, stall → zero beats + planes hold,
   `B_RESIDENT` replay bit-exact.
3. Chain integration TB (`test_stage_mac_requant.py` or an extension of the
   TKT-023 chain): frozen controller → staging → `gcb_mac_tile_array` →
   `gcb_tile_requantize`, real INT4 matmul tiles, `q_tile` bit-exact vs the
   NumPy golden at `STAGE_REGS = 0`, and identical-but-delayed at
   `STAGE_REGS = 2`.
4. `bash sim/lint.sh` exit 0 with any new top added and wired into `sim/lint.sh`
   + the guarded `sim/run_tb.sh` stanza; Cocotb `TESTS=… PASS=… FAIL=0` on the
   pinned venv.
5. `sv2v … | yosys -p '…; hierarchy -check; proc; check -assert;
   select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr; stat'` at a `chparam`
   bring-up geometry — exit 0, latch-free; `stat` recorded next to
   `sim/yosys068_bless/`.
6. A `stat` MACs/cycle-context + cell + fan-out-cost row added to the TKT-017
   PPA burn-down table.
7. The TKT-022 `mac_tile_array_tb_top` direct controller-bus wire migrated to
   route through the staging layer; `gcb_mac_tile_array.sv` itself unchanged.
   Diff confined to the (optional) new RTL + TBs + sim-list edits + the
   `gcb-wiki/05` pointer. Nothing in a frozen module.

### Toolchain

Environment is **pinned** (`gcb-wdm-transceiver/sim/toolchain_manifest.json`:
Verilator 5.032 / Python 3.12.14 / cocotb 1.9.2 / Yosys 0.68 / sv2v 0.0.12 /
numpy 2.5.3; venv `~/.venvs/cocotb19`). Re-run the manifest diff before
execution; it should be **empty**. A reappearing delta re-triggers the TKT-022
Yellow-Team baseline regression (incl. the TKT-020 R1 `cov_violation = 1` trap)
as a gate.

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
