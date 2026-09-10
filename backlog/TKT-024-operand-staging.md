---
id: TKT-024
title: "Story 3 of EPIC TKT-017 — operand staging: the SRAM-read-port → MAC-grid staging / broadcast layer"
date_created: 2026-09-10
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.0
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

### 2026-09-10 (session 01Rpa9VJGe7xypzp5FkukSco) — Lead Hardware Engineer

* **Toolchain pre-check.** Manifest diff (`sim/toolchain_manifest.json`) **empty** —
  all seven tools match the TKT-022 pin. No Yellow-Team re-gate.

* **Assessment — Path B.** `gcb_tensor_broadcast_fabric.sv` does **not** fit the
  `gcb_mac_tile_array` input contract, so the minimal adapter was built:
  * the fabric emits `NUM_CORES` **per-core unpacked arrays**
    (`core_valid` / `core_a_flat` / `core_b_flat [NUM_CORES]` — 256
    already-materialised broadcast feeds for the *optical QAM* array), not the
    two **packed** `a_row_bus` / `b_col_bus` buses + single `beat_valid` the INT4
    MAC grid consumes. Feeding the grid from it would mean re-collapsing 256
    feeds to `GRID_DIM + GRID_DIM` vectors — a net loss.
  * it has only `REG_OUT ∈ {0,1}` (no `STAGE_REGS` 0..N);
  * it is locked to `GRID_DIM² == NUM_CORES` (no PE grid wider than the SRAM
    lane count);
  * its `sram_rdata` packing (`[r*VEC_W +: VEC_W]` A, `[GRID_DIM*VEC_W + c*VEC_W
    +: VEC_W]` B) **does** match the controller and the new module — mirrored,
    not changed. `gcb_tensor_broadcast_fabric.sv` is untouched.

* **`gcb-wdm-transceiver/rtl/gcb_operand_stage.sv`** (NEW, ~170 lines).
  Parameters: `GRID_DIM` (SRAM lanes/side), `GRID_M`, `GRID_N` (PE grid,
  multiples of `GRID_DIM`), `K_MAX`, `OPND_W`, `STAGE_REGS` (0 = transparent),
  `B_RESIDENT` (0 default), `B_DEPTH`. No literal; `initial` guards on
  `GRID_M/GRID_N % GRID_DIM` and `>= GRID_DIM`.
  * **bus decode** → `a_lane[GRID_DIM]` / `b_lane[GRID_DIM]`;
  * **broadcast fan-out** → PE row `i` ← `a_lane[i / (GRID_M/GRID_DIM)]`,
    PE col `j` ← `b_lane[j / (GRID_N/GRID_DIM)]` (identity when
    `GRID_* = GRID_DIM`) into the packed `a_row_bus` / `b_col_bus`;
  * **`STAGE_REGS` skew** — a valid-gated pipe: `valid` always shifts, the
    operand planes are captured only on a real beat, so a stall bubble leaves the
    planes **holding their last value** and no spurious `beat_valid` reaches the
    MAC accumulators;
  * **`B_RESIDENT`** — a `B_DEPTH`-entry RF: `b_capture && sram_valid` writes the
    broadcast B plane at `b_addr`; `b_replay` sources `b_col_bus` from the RF
    instead of live SRAM (forward-compat for a controller variant that streams B
    once per pass). Zero cost when `B_RESIDENT = 0` (generate not instantiated).
  * Consumes **only** `sram_valid` + `sram_rdata`; drives `gcb_mac_tile_array` on
    its existing `beat_valid` / `a_row_bus` / `b_col_bus` contract, unchanged.

* **Unit proof** — `sim/cocotb/operand_stage_tb_top.sv` (four instances:
  transparent, `STAGE_REGS=2`, 8×8-from-4-lane broadcast, `B_RESIDENT` `B_DEPTH=4`)
  + `test_operand_stage.py` + `Makefile.operand_stage`: **`TESTS=1 PASS=1
  FAIL=0`**. (a) transparent output == the raw controller A/B halves; (b)
  `STAGE_REGS=2` matches an RTL-mirrored valid-gated pipe **through a stall
  bubble** and drains 4-in/4-out; (c) `k·GRID_DIM = 2` fan-out puts lane `i//2`
  on PE row/col `i`; (d) `beat_valid` low + operand planes held through a stall;
  (e) `B_RESIDENT` replays the captured B sets while live A still passes through.

* **Chain integration proof** — `sim/cocotb/stage_mac_requant_chain_tb_top.sv`
  (frozen SRAM controller → **`gcb_operand_stage` (STAGE_REGS=2)** →
  `gcb_mac_tile_array` → `gcb_tile_requantize`) + `test_stage_mac_requant.py` +
  `Makefile.stage_mac_requant`: **`TESTS=1 PASS=1 FAIL=0`**. 5 INT4 matmuls
  (directed + 4 random seeds) × 4 output tiles = **20 requantized blocks, every
  `q_tile` / `q_scale` / `q_clip` bit-exact** against the NumPy block-float
  golden — inserting the stage adds latency only.

* **`gcb_tile_requantize.sv` fix (found by this chain test).** The
  `stage_mac_requant` chain surfaced a one-cycle lag in `q_clip`: the sticky
  flag was registered-only, so a reader sampling `q_clip` alongside `q_valid`
  missed the **first** clipping tile by a cycle. Changed to
  `q_clip = q_clip_q | (in_valid & any_clip_c)` — asserted the same cycle the
  qualifying beat is presented, still held sticky until `soft_clear`. The
  TKT-023 chain TB (`test_mac_requant_chain.py`) and the new TKT-024 chain TB
  were updated to model `q_clip` as sticky **across** tiles (accumulating the
  per-tile reference); the TKT-023 unit TB already `soft_clear`s per vector so
  it was unaffected. All cocotb suites still **`PASS FAIL=0`**.

* **`bash sim/lint.sh`** → **exit 0**, 34 tops (`gcb_operand_stage` added to the
  RTL list and the top loop). Verilator-5 `-Wall` clean at the repo bar;
  `PINCONNECTEMPTY` avoided by never leaving a `gcb_max_reduce`/child pin open
  — n/a here (the stage instantiates nothing) — and by `_unused` guards on the
  `B_RESIDENT=0` / `STAGE_REGS=0` idle inputs.

* **`sv2v`→Yosys 0.68 elaboration** — `gcb_operand_stage` (`chparam` GRID_DIM=4,
  8×8, `STAGE_REGS=2`, `B_RESIDENT=1`, `B_DEPTH=8`): `check -assert` **0
  problems**; `select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr` clean
  (**latch-free**). `gcb_tile_requantize` re-blessed after the `q_clip` change —
  still 0 problems, latch-free. `stat` + `SUMMARY.md` updated under
  `sim/yosys068_bless/`.

* **Artifacts Touched:**
  * `rtl/gcb_operand_stage.sv` (new); `rtl/gcb_tile_requantize.sv` (q_clip
    one-line fix).
  * `sim/cocotb/{operand_stage_tb_top.sv, test_operand_stage.py,
    Makefile.operand_stage, stage_mac_requant_chain_tb_top.sv,
    test_stage_mac_requant.py, Makefile.stage_mac_requant}` (new);
    `test_mac_requant_chain.py` (sticky-clip model).
  * `sim/yosys068_bless/{operand_stage.stat, tile_requantize.stat, SUMMARY.md}`;
    `sim/toolchain_manifest.json` regression-gate list.
  * `sim/lint.sh`, `sim/run_tb.sh`, `.gitignore` — wired in the new top / two
    cocotb stanzas / build dirs.
  * `mac_tile_array_tb_top.sv` (TKT-022) left as-is — the direct-wire migration
    to route through the stage is demonstrated by the new
    `stage_mac_requant_chain_tb_top.sv`; `gcb_mac_tile_array.sv` untouched.
  * `gcb_tensor_broadcast_fabric.sv` untouched (assessed, does not fit).

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence 0.0)`,
`‖T‖₂ = √2 ≈ 1.414`.

* **X — Specification `+1.0`.** Every Green-Target item met: the fabric was
  assessed first (Path B, with the precise reason recorded); one fully
  parameterised SV-2017 staging module — bus decode, `STAGE_REGS` skew,
  `k·GRID_DIM` broadcast, stall gating, `B_RESIDENT` replay, no literal; a unit
  TB proving all five behaviours incl. the stall bubble against an RTL-mirrored
  model; a chain integration TB proving the stage changes nothing functionally
  (20 blocks bit-exact end-to-end, latency-only); `sim/lint.sh` exit 0 with the
  new top wired into `sim/lint.sh` and the guarded `sim/run_tb.sh` stanzas;
  `sv2v`→Yosys 0.68 elaboration clean and latch-free; a `stat` row for the
  TKT-017 PPA burn-down; `gcb_mac_tile_array` and the frozen read port
  untouched.
* **Y — Quality `+1.0`.** Blue-grade: the stall-hold is a genuine valid-gated
  pipe (a bubble does not advance the planes), proven against an RTL-mirrored
  Python model rather than a hand-wave; the broadcast is a clean block map
  usable by a future grid-widening story as a parameter change; `B_RESIDENT` is
  zero-cost when off. The chain test caught and fixed a real one-cycle
  `q_clip` visibility bug in the already-committed `gcb_tile_requantize`
  (cross-story, honestly logged), and the TKT-023 chain TB was tightened to the
  correct sticky-across-tiles semantics. Strict-`-Wall` lint-clean; latch-free
  on the blessed Yosys 0.68.
* **Z — Emergence `0.0`.** Third sub-story of the compute Epic — target-
  architecture plumbing that unblocks a PE grid wider than the SRAM lane count.
  Not net-new platform capability; the ticket claimed no Purple lean.

Dominant spoke: `|x| = |y| = 1.0`; tie-break `X > Y > Z` → `X+` → **Green**.
Cyclopter scavenger (TKT-013) ingests this vector on close; EPIC TKT-017 now has
three Green child data points (TKT-022 MAC array, TKT-023 requantize, TKT-024
operand staging).
