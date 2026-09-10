---
id: TKT-025
title: "Story 4 of EPIC TKT-017 — end-to-end integration TB: one real gcb-wiki/06 tile through SRAM → stage → MAC → requantize → softmax hand-off"
date_created: 2026-09-10
status: open
telemetry_color: pending
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
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
