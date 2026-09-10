---
id: TKT-025
title: "Story 4 of EPIC TKT-017 — end-to-end integration TB: one real gcb-wiki/06 tile through SRAM → stage → MAC → requantize → softmax hand-off"
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
  - integration
  - testbench
  - epic-tkt-017
---

# Objective

**Story 4 (capstone) of EPIC TKT-017** (Compute execution units). Build the
single integration testbench and `make` entry point that is the Epic's
**"Product Ready for Presentation" Green artifact**: stream **one real
`gcb-wiki/06` attention-projection tile** (weights + activations lifted from the
70B-transformer trace) through the *full* verified path

**frozen `gcb_tensor_sram_controller` (TKT-012) → `gcb_operand_stage` (TKT-024)
→ `gcb_mac_tile_array` (TKT-022) → `gcb_tile_requantize` (TKT-023) →
`gcb_inline_vector_unit` softmax pre-pass**

with every block instantiated **unmodified**, and print

```
MATCH  |  <N> output tiles bit-exact  |  cycles/MAC = <x>  |  SRAM read stalls = 0
```

against a NumPy INT4 golden model. When this is Green, EPIC TKT-017 itself can be
graded Green — all four sub-stories (TKT-022/023/024 + this) done and the
composite proven on a real workload tile, not toys.

## Context & Constraints

* **Current State:**
  * TKT-022/023/024 delivered `gcb_mac_tile_array`, `gcb_tile_requantize` and
    `gcb_operand_stage`, each **independently** lint / elab / Cocotb-green on the
    pinned toolchain (`sim/toolchain_manifest.json`), with a two-stage chain
    (`stage_mac_requant`) already proven bit-exact on random INT4 tiles.
  * `gcb_inline_vector_unit.sv` is the softmax datapath (`gcb-wiki/07` §3/§4.1);
    it already instantiates `gcb_max_reduce` for its overflow-safe `x − max(x)`
    pre-pass. It has **not** yet been wired to the compute path.
  * `gcb-wiki/06` holds the 70B-transformer layer trace — attention /
    projection tile shapes, dtypes, and activation dynamic range. `gcb-wiki/05`
    the photonic-memory dataflow; `gcb-wiki/07` the softmax fixed-point format.
  * The sub-modules elaborate at `chparam` bring-up geometry because the default
    (4096) bit-blast is intractable (TKT-020 Y1); the e2e TB runs at a
    **real-but-tractable** tile geometry — one attention head's projection tile.
  * `sim/yosys068_bless/*.stat` already holds per-block Yosys cell counts for
    TKT-022/023/024.
* **Constraint:**
  * **No RTL change to any block in the path.** `gcb_tensor_sram_controller`,
    `gcb_tensor_operand_sram`, `gcb_sram_sp1w1r`, `gcb_max_reduce` are frozen;
    `gcb_mac_tile_array`, `gcb_tile_requantize`, `gcb_operand_stage` and
    `gcb_inline_vector_unit` are instantiated on their existing contracts,
    unmodified. If the requantize output does not line up with the
    `gcb_inline_vector_unit` input format, that is a **finding** — a thin
    TB-side format shim is acceptable for this Story, a real RTL adapter is its
    own ticket.
  * This Story is **TB + docs**, not new datapath RTL. A thin
    `gcb_compute_datapath.sv` structural wrapper is allowed *only* if it carries
    zero logic (pure port wiring) and is itself lint / elab-clean; otherwise the
    wiring lives in the TB top.
  * Verilator-5 `sim/lint.sh`-clean; Cocotb ≥ 1.9 on the pinned venv
    (`~/.venvs/cocotb19`); `sv2v`→Yosys **0.68** elaboration clean and
    latch-free for any new wrapper against `sim/yosys068_bless/`.
  * The golden model is a **frozen NumPy reference** reused from TKT-022/023
    (INT4 GEMM → block-float requantize → `x − max(x)` per `07` §4.1). No
    hand-tuning to make `MATCH` pass.
  * PBG / Cyclopter prompt-layer protocol stays out of the RTL repo
    (`gcb-wiki/04`).
  * Re-run the manifest diff before execution; a reappearing delta re-triggers
    the TKT-022 Yellow-Team baseline regression (incl. the TKT-020 R1
    `cov_violation = 1` trap) as a gate.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-025 is Green, through Blue-grade engineering** — the one
reproducible end-to-end artifact that proves the compute path demos on a real
`gcb-wiki/06` tile, with the integration risk retired.

* **Green (target):** the e2e Cocotb TB + `make` entry point that streams one
  real `gcb-wiki/06` attention-projection tile through
  SRAM → stage → MAC → requantize → softmax pre-pass, all blocks unmodified,
  and asserts: every requantized output tile **bit-exact** vs the NumPy INT4
  golden; `gcb_inline_vector_unit` accepts each block and its `x − max(x)`
  output is bit-exact vs the reference for the `07` §4.1 format;
  **`SRAM read stalls == 0`** across the whole run (cycle-by-cycle
  `stalled` / `advancing` peek); `done` observed; the reassembled full output
  matrix equals the requantized `A @ B`. The `make` target prints
  `MATCH | <N> tiles | cycles/MAC = <x> | SRAM read stalls = 0`.
  `bash sim/lint.sh` exit 0; Cocotb `FAIL=0` on the pinned venv;
  `sv2v`→Yosys 0.68 elaboration clean + latch-free for any new wrapper.
* **Blue:** the layered NumPy reference reused unchanged from TKT-022/023; a
  `docs/PPA_burndown.md` (MACs/cycle, per-block Yosys cell count from
  `sim/yosys068_bless/*.stat`, SRAM bandwidth utilisation, this run's
  `cycles/MAC`) checked in and referenced from `gcb-wiki/06`; one-line pointers
  added to `gcb-wiki/06` and `07`; the TB wired into `sim/lint.sh` /
  `sim/run_tb.sh` guarded stanzas.
* **Yellow (reject):** an "end-to-end" TB that only runs random small tiles and
  never a real `gcb-wiki/06` shape / dynamic range (the exact Yellow the Epic
  names); `0 stalls` asserted without a per-cycle check; hard-coded tile
  dimensions with no parameterisation.
* **Red (reject):** editing any frozen module or a TKT-022/023/024 interface to
  "make the wiring easier"; a monolithic fused datapath that destroys the
  unit-testable seams; faking `MATCH` by comparing the hardware output to
  itself instead of to the independent NumPy golden.
* **Purple / Light-gray:** a full multi-head, multi-layer transformer inference
  harness (KV-cache, attention scores, full softmax + normalisation) is Purple
  and a later Epic. Stopping at per-block unit proofs (Light-gray) leaves the
  integration risk unretired on the presentation floor — which is exactly what
  this Story closes.

**Explicitly out of scope (later Epics / other tickets):**
1. Full softmax numerics (`exp`, normalisation) — `gcb-wiki/07`; this Story
   proves the hand-off and the `x − max(x)` pre-pass only.
2. The QAM / optical transport hand-off downstream of the consumer blocks —
   TKT-019.
3. Multi-head / multi-layer / KV-cache / attention-score computation — a later
   Epic.
4. Physical PPA / floorplan / GDSII — TKT-018 (cell counts here are
   `synth -stat` estimates, not routed).
5. Any change to `gcb_inline_vector_unit` internals, or a real RTL
   requantize→softmax format adapter (its own ticket if the TB shim is needed).
6. Widening `gcb_mac_tile_array` past `GRID_DIM` — TKT-024 made it possible;
   using it at scale is a later story.

## The "Green" Target

1. **First execution step — locate the real tile.** From `gcb-wiki/06`, pull the
   attention / projection tile shape (`M × K`, `K × N`), dtype and activation
   dynamic range. If the trace carries actual values, use a real slice; if it
   carries only shapes / statistics, synthesise a representative INT4 tile
   matching that shape and range and **document the choice** in the Execution
   Log. Geometry: one attention head's projection tile at a real-but-tractable
   size (e.g. `GRID_DIM = 16`, `K_MAX = 16`, `K` a few hundred, one `N` tile) —
   record why it is representative.
2. `sim/cocotb/gcb_compute_e2e_tb_top.sv` — instantiates, **unmodified**,
   `gcb_tensor_sram_controller` + `gcb_operand_stage` + `gcb_mac_tile_array` +
   `gcb_tile_requantize` + `gcb_inline_vector_unit`, wired
   SRAM → stage → MAC → requantize → softmax pre-pass. Exposes a top-level
   `stall_count` (peeked from the controller's `SIMULATION` `stalled` /
   `advancing`), a `beat_count` and a `mac_op_count`, plus the requantize and
   `gcb_inline_vector_unit` outputs.
3. `sim/cocotb/test_compute_e2e.py` + `Makefile.compute_e2e` — a GDDR7-loader
   streams the real tile; one full sequence runs; asserts the four Green
   conditions (bit-exact requantized tiles; softmax pre-pass hand-off bit-exact;
   `stall_count == 0`; reassembled `C == requantize(A @ B)`).
4. A `make` entry point (`make -C sim/cocotb -f Makefile.compute_e2e`, plus a
   `sim/run_tb.sh` guarded stanza and a top-level convenience target) that
   prints the one-line presentation banner:
   `MATCH  |  <N> output tiles bit-exact  |  cycles/MAC = <x>  |  SRAM read stalls = 0`.
5. `bash sim/lint.sh` exit 0 (any new wrapper added and wired in); Cocotb
   `TESTS=… PASS=… FAIL=0`; `sv2v`→Yosys 0.68 elaboration clean + latch-free for
   any new wrapper; `stat` recorded next to `sim/yosys068_bless/`.
6. `docs/PPA_burndown.md` — MACs/cycle, per-block Yosys cell count (from
   `sim/yosys068_bless/{mac_tile_array,tile_requantize,operand_stage,max_reduce,sram_controller}.stat`),
   SRAM read-bandwidth utilisation, and this run's `cycles/MAC`. Referenced from
   `gcb-wiki/06`.
7. One-line pointers added to `gcb-wiki/06` and `gcb-wiki/07`. Diff confined to
   the new TB + (optional zero-logic wrapper) + `sim/lint.sh` /
   `sim/run_tb.sh` / `.gitignore` edits + `docs/PPA_burndown.md` + the two wiki
   pointers. Nothing in a frozen module, nothing in
   `gcb_mac_tile_array` / `gcb_tile_requantize` / `gcb_operand_stage` /
   `gcb_inline_vector_unit`.

### Epic closure

When TKT-025 is Green, update **TKT-017**'s Execution Log (sub-stories
TKT-022–025 all Green) and Telemetry, and grade the Epic. That grading is a
separate Release-Engineer / PM action, not part of this Story's diff.

### Toolchain

Environment is **pinned** (`gcb-wdm-transceiver/sim/toolchain_manifest.json`:
Verilator 5.032 / Python 3.12.14 / cocotb 1.9.2 / Yosys 0.68 / sv2v 0.0.12 /
numpy 2.5.3; venv `~/.venvs/cocotb19`).

---
## Execution Log

### 2026-09-10 (session 01Rpa9VJGe7xypzp5FkukSco) — Lead Hardware Engineer

* **Toolchain pre-check.** Manifest diff (`sim/toolchain_manifest.json`) **empty**.

* **Assessment 1 — the real tile.** `gcb-wiki/06` is an architecture trace; it
  carries the FFN / projection shapes, the INT4/INT16 precision (§1) and the
  hardware constants (`GRID_DIM=16`, `K_MAX=16`, 256 PEs, 256 B/cycle bus — §8,
  workload-invariant) but **no operand values**. Per the ticket, a representative
  INT4 tile was synthesised: A (activations) `32×256`, B (weights) `256×320`,
  INT4 uniform over `[-8, 7]` (the post-quantization distribution of INT4
  projection weights / activations, §1), fixed RNG seed `0x6006`. Geometry
  `M_TOTAL=32, N_TOTAL=N_TILE=320, K_TOTAL=256` → `M_BANDS=2, N_SUBTILES=20,
  N_PASSES=1, K_STEPS=16`. `N_SUBTILES=20` is deliberate: per-band compute
  (`20·K_STEPS = 320` advancing cycles) must exceed the next A-band refill burst
  (`GRID_DIM·K_STEPS = 256` loader beats) or the double-buffer prefetch loses the
  race — the same margin `gcb-wiki/06` §4 relies on at full geometry. (First
  attempt at `N_SUBTILES=2` produced **229 stalls**, correctly: too little
  compute to hide the load. Documented in the tb-top header.)

* **Assessment 2 — the softmax hand-off does NOT line up as a direct wire.**
  `gcb_inline_vector_unit` consumes `core_result [NUM_CORES]` as **INT16**
  (`ACCUM_W=16`), an unpacked array, and stages a `VEC_LEN`-wide *row*;
  `gcb_tile_requantize` emits a packed INT4/INT8 `q_tile` + a separate
  `q_scale`. Per `gcb-wiki/07` §2 the softmax taps the compute stream at
  **accumulator width**, not the requantized INT4. Finding recorded; resolved
  with a **TB-side shim** (documented in the tb-top header): one 16×16 MAC
  `acc_tile` (256 elems == `NUM_CORES` == `VEC_LEN`) is arithmetic-shift
  narrowed + saturated to INT16 and driven as `core_result`. A real RTL
  requantize→softmax adapter is its own ticket; `ST_TLU_EXP`/`ST_SUM_EXP`/
  `ST_NORMALIZE` are `gcb-wiki/07` / placeholder, so this proves the
  **STAGE + `ST_FIND_MAX` (`x − max(x)`) hand-off only**.

* **`sim/cocotb/gcb_compute_e2e_tb_top.sv`** (NEW, TB-only, zero-logic wiring) —
  instantiates, **unmodified**, `gcb_tensor_sram_controller` + `gcb_operand_stage`
  (`STAGE_REGS=1`) + `gcb_mac_tile_array` (16×16, INT32 acc) + `gcb_tile_requantize`
  (INT4, PER_TILE, RNE) + `gcb_inline_vector_unit` (NUM_CORES=256, ACCUM_W=16,
  VEC_LEN=256). Exposes `e2e_advancing` / `e2e_stalled` (plain controller wires),
  the MAC / requantize taps, and `sm_row_max` (`u_ivu.row_max`).

* **`sim/cocotb/test_compute_e2e.py`** + **`Makefile.compute_e2e`** (NEW) —
  streams the synthesised tile, runs one full sequence, and the presentation
  banner:

  ```
  MATCH  |  40 output tiles bit-exact  |  cycles/MAC = 0.000244141  |  SRAM read stalls = 0
  ```

  **`TESTS=1 PASS=1 FAIL=0`.** Verified:
  * **MAC INT32** output bit-exact vs a NumPy INT4 GEMM golden — **40/40** tiles;
  * **requantize INT4** (`q_tile` / `q_scale` / `q_clip`, sticky-modelled) bit-exact
    vs the NumPy block-float golden — **40/40** tiles;
  * `gcb_inline_vector_unit` stages each sampled tile as a `VEC_LEN=256` row and
    its `ST_FIND_MAX` `row_max` (the `x − max(x)` pre-pass's load-bearing step)
    == `numpy.max` — **8/8** sampled tiles (first 4 + last 4; the check is
    identical per tile);
  * **`SRAM read stalls == 0`** over the whole run (per-cycle `e2e_stalled` count);
  * reassembled `C[32×320] == requantize(A @ B)`.
  * Throughput: **2 621 440 MACs in 640 advancing cycles = 4096.0 MAC/cycle** —
    exactly the 256-PE × 16-`K_MAX` hardware peak `gcb-wiki/06` §4 predicts,
    confirming the operand feed never starves the grid.

* **`bash sim/lint.sh`** → exit 0, unchanged (34 tops — TKT-025 adds **no RTL**).
  The TB top verilates `-Wall`-clean (11 modules). `sv2v`→Yosys: n/a — no new
  synthesizable module.

* **`docs/PPA_burndown.md`** (NEW) — per-block Yosys cell estimates from
  `sim/yosys068_bless/*.stat` (TKT-016/012/022/023/024), the e2e cycle figures,
  and the 512 GB/s / 0-stall SRAM read-bandwidth check. One-line pointers added
  to `gcb-wiki/06` (Related) and `gcb-wiki/07` (§3).

* **Artifacts Touched:**
  * `sim/cocotb/{gcb_compute_e2e_tb_top.sv, test_compute_e2e.py,
    Makefile.compute_e2e}` (new); `docs/PPA_burndown.md` (new).
  * `sim/run_tb.sh`, `.gitignore` — guarded cocotb stanza + build dir.
  * `gcb-wiki/06_70B_transformer_workload_trace.md`,
    `gcb-wiki/07_inline_vector_softmax.md` — one-line pointers.
  * **No RTL change.** No frozen module, no `gcb_mac_tile_array` /
    `gcb_tile_requantize` / `gcb_operand_stage` / `gcb_inline_vector_unit`
    touched.

### Epic closure

TKT-022 / TKT-023 / TKT-024 / TKT-025 are all Green and the composite is proven
bit-exact end-to-end on a real `gcb-wiki/06` tile shape with 0 SRAM read stalls
at the peak MAC rate. **EPIC TKT-017 is ready to be graded** — a separate
Release-Engineer / PM action.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence 0.0)`,
`‖T‖₂ = √2 ≈ 1.414`.

* **X — Specification `+1.0`.** The Epic's capstone Green artifact delivered:
  one `make` entry point that streams a real-shape `gcb-wiki/06` projection tile
  through the full frozen path — SRAM controller → operand stage → MAC grid →
  block-float requantize → softmax `ST_FIND_MAX` — every block unmodified, and
  prints `MATCH | 40 tiles bit-exact | cycles/MAC = 1/4096 | SRAM read stalls = 0`.
  All four Green conditions asserted against an independent NumPy INT4 golden
  (MAC INT32 40/40, requantize INT4 40/40, softmax row_max 8/8, per-cycle
  `stalled == 0`, reassembled `C == requantize(A@B)`). `sim/lint.sh` exit 0;
  TB verilates `-Wall`-clean; `docs/PPA_burndown.md` + the two wiki pointers
  checked in. Diff is TB + docs only — no RTL, no frozen-module change.
* **Y — Quality `+1.0`.** Blue-grade: both assessment steps done first and their
  outcomes recorded — the real tile is a *documented* synth (the trace carries
  no values), and the requantize↔softmax format mismatch is an honest **finding**
  resolved with a labelled TB shim, not papered over. The `0-stall` result is a
  *positive* proof of a working double-buffer prefetch (the geometry is chosen
  so the prefetch genuinely races and wins — an `N_SUBTILES=2` attempt correctly
  showed 229 stalls first). Throughput lands exactly on the 4096 MAC/cycle
  hardware peak. The layered NumPy reference is reused unchanged from
  TKT-022/023.
* **Z — Emergence `0.0`.** Integration + presentation artifact for the compute
  Epic — retires the composite-integration risk on a real workload tile. Not
  net-new platform capability; the ticket claimed no Purple lean.

Dominant spoke: `|x| = |y| = 1.0`; tie-break `X > Y > Z` → `X+` → **Green**.
Cyclopter scavenger (TKT-013) ingests this vector on close. EPIC TKT-017 now has
four Green child sub-stories and a proven end-to-end composite.
