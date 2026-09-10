---
id: TKT-023
title: "Story 2 of EPIC TKT-017 — gcb_tile_requantize: block-float requantization of the INT32 MAC tile to INT4/INT8 via the frozen gcb_max_reduce"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - compute
  - quantization
  - int4
  - epic-tkt-017
---

# Objective

**Story 2 of EPIC TKT-017** (Compute execution units). Design
`gcb-wdm-transceiver/rtl/gcb_tile_requantize.sv` — the reduction stage that sits
between the TKT-022 `gcb_mac_tile_array` and the activation consumers
(`gcb_inline_vector_unit` softmax pre-pass, `gcb_qam_datapath_top` optical QAM).
It takes the wide **INT32** output tile the MAC grid produces and narrows it back
to **INT4** (default) or **INT8** with a **block-floating-point scale**:

1. reduce the tile to a single magnitude maximum — per-tile, or per-row /
   per-column ("per-channel") — using the **frozen `gcb_max_reduce`** primitive
   (TKT-016), instantiated unmodified: this is the **third consumer** of that
   one comparator tree the Epic's Purple lean names, alongside QAM slicing and
   the softmax `x − max(x)`;
2. derive the right-shift / shared exponent that maps that maximum into the
   target range without clipping the block;
3. apply the shift with a documented rounding mode and saturating clamp, and
   emit the narrowed tile **plus** the shared scale so the consumer can
   dequantize.

This story owns **the INT32 → narrow conversion and its scale only**. It does not
touch the MAC grid, the SRAM path, `gcb_max_reduce`, or the consumers' internals.

## Context & Constraints

* **Current State:**
  * TKT-022 delivered `gcb_mac_tile_array.sv`: a parameterised INT4 PE grid on
    the frozen `gcb_tensor_sram_controller` read port. Its output contract is
    `acc_tile` (`GRID_M*GRID_N` signed `ACC_W`-bit, row-major
    `[(i*GRID_N+j)*ACC_W +: ACC_W]`), a one-cycle `tile_valid`, and a sticky
    `acc_ovf`. `ACC_W = 32`. That contract is the **input** contract here and is
    treated as stable — do not change it.
  * `gcb_max_reduce.sv` (TKT-016) is verified and area-quantified: parameters
    `N`, `W`, `SIGNED`, `MODE` (MAX/MIN), `OUT` (value/index/both), `TIE`,
    `REG_STAGES`; proven bit-exact vs a Python reference and used already by the
    softmax pre-pass and the QAM slice.
  * `gcb-wiki/07` §3 (hardware softmax, structural) and §4.1 (fixed-point
    representation) specify the softmax consumer's expected input format;
    `gcb-wiki/06` holds the 70B-transformer tile trace (shapes, dtypes, the
    activation dynamic range block-float has to cover); `gcb-wiki/05` the
    photonic-memory dataflow.
  * There is no RTL that turns an INT32 accumulator tile into a scaled narrow
    block. TKT-022 explicitly deferred it ("down-conversion … is done by the
    frozen `gcb_max_reduce` block-float scale in the requantize sub-story").
* **Constraint:**
  * One hand-written file `gcb-wdm-transceiver/rtl/gcb_tile_requantize.sv`, pure
    **SV-2017**, fully parameterised — tile dims, input/output widths, scale
    granularity, rounding mode, exponent width, pipeline depth — with **no
    tile-specific literal**.
  * `gcb_max_reduce` is **instantiated, not re-implemented**. No port change to
    it, to `gcb_mac_tile_array`, or to any frozen-list interface
    (`gcb_tensor_memory_engine`, `gcb_tensor_sram_controller`).
  * Verilator-5 `sim/lint.sh`-clean with the new top added; Cocotb ≥ 1.9 on the
    **pinned** toolchain (`~/.venvs/cocotb19` — cocotb 1.9.2 / Python 3.12,
    `gcb-wdm-transceiver/sim/toolchain_manifest.json`); `sv2v`→Yosys **0.68**
    elaboration clean and latch-free against the blessed baseline
    (`sim/yosys068_bless/`).
  * PBG / Cyclopter prompt-layer protocol stays out of the RTL repo
    (`gcb-wiki/04`).
  * The INT4 numeric scheme is **taken as given** (TKT-017 out-of-scope item 5):
    this story implements a fixed block-float requantizer, not a learned or
    calibrated quantization policy.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-023 is Green, through Blue-grade engineering** — a small,
fully parameterised requantizer whose block-max is a pure instantiation of the
existing `gcb_max_reduce`, with a bit-exact reference proof and a scale that
round-trips.

* **Green (target):** `gcb_tile_requantize.sv` as scoped, plus
  `sim/cocotb/test_tile_requantize.py` proving the narrowed tile **and** the
  emitted scale are **bit-exact** against a NumPy block-float reference over
  swept tile dims / output widths / scale granularities / rounding modes and
  directed corners (all-zero tile → shift 0, no divide; single non-zero;
  every element at `INT32_MAX` → clamp; a value exactly on a rounding
  boundary; per-tile vs per-row vs per-col). `bash sim/lint.sh` exit 0 with the
  new top wired into `sim/lint.sh` and the guarded `sim/run_tb.sh` stanza;
  `sv2v`→Yosys 0.68 elaboration clean and latch-free at a `chparam` bring-up
  geometry; a `stat` row (cells + `gcb_max_reduce` instance count) for the
  TKT-017 PPA burn-down.
* **Blue:** a frozen NumPy block-float reference reused by the later end-to-end
  TB; `gcb_max_reduce` dropped in as a pure instantiation with no glue logic
  around it; a `gcb_mac_tile_array → gcb_tile_requantize` chained TB that drives
  one real `gcb-wiki/06` tile and asserts the dequantized output
  (`q_tile * 2^q_scale`) is within the block-float error bound of the true FP
  matmul; a one-line pointer added to `gcb-wiki/07` §4.1.
* **Yellow (reject):** re-rolling a bespoke max/argmax tree instead of
  instantiating `gcb_max_reduce` (breaks the "one verified reduction" claim and
  the Epic's Purple lean); a requantizer that only truncates — no rounding mode,
  no saturating clamp — so it silently clips large blocks; a hard-coded shift or
  a fixed per-tile-only granularity with no parameter.
* **Red (reject):** editing `gcb_max_reduce` or the `gcb_mac_tile_array` output
  contract to "make the wiring easier"; fusing requantize back into the MAC
  array and destroying the unit-testable seam TKT-022 established; a scale that
  is computed but not emitted (downstream cannot dequantize).
* **Purple / Light-gray:** adaptive / per-token learned quantization calibration
  is Purple and a later Epic (and TKT-017 out-of-scope item 5). Leaving the
  INT32→consumer conversion unspecified (Light-gray) blocks the end-to-end
  presentation tile.

**Explicitly out of scope (sibling TKT-017 sub-stories / other Epics):**
1. The full SRAM → MAC → requantize → softmax end-to-end integration TB with a
   real `gcb-wiki/06` tile and the `MATCH` / `cycles/MAC` presentation print —
   that is the Epic's capstone Green demo, not this story.
2. The operand-staging fabric internals — a separate sub-story.
3. Any port change to `gcb_inline_vector_unit` / `gcb_qam_datapath_top`; their
   internal `exp` / normalisation / constellation logic.
4. `gcb_max_reduce` internals.
5. Physical PPA / floorplan / GDSII — TKT-018.
6. Training-time quantisation calibration; the INT4 scheme is taken as given.

## The "Green" Target

1. `gcb-wdm-transceiver/rtl/gcb_tile_requantize.sv` — one synthesizable SV-2017
   module. Parameters (names indicative): `GRID_M`, `GRID_N` (tile dims, match
   the MAC array); `IN_W` (= `ACC_W` = 32); `OUT_W` (= 4 INT4 default; 8 INT8
   selectable); `SCALE_MODE` (`PER_TILE` / `PER_ROW` / `PER_COL`); `ROUND`
   (`RNE` / `RTZ` / `RNA`); `EXP_W` (emitted shift/exponent width); `SIGNED`
   (= 1); `REG_STAGES` (pipeline cut count, 0 = combinational). No tile-specific
   literal; grid dims need not be powers of two.
2. **Reduction path:** compute `|acc[i][j]|` (two's-complement abs, with the
   `-2^(IN_W-1)` edge handled), then instantiate the **frozen `gcb_max_reduce`**
   (`MODE=MAX`, `OUT=value`, `SIGNED=0`, `N` = `GRID_M*GRID_N` for `PER_TILE`
   or `GRID_N` / `GRID_M` per channel, `W=IN_W`) — one instance per reduction
   axis, unchanged, no surrounding glue beyond the abs and the fan-out.
3. **Scale derivation:** from `max_abs`, a leading-zero / priority-encode step
   yields the smallest right-shift `s` such that
   `(max_abs >> s) <= 2^(OUT_W-1) - 1`; `s` is clamped to `[0, 2^EXP_W-1]` and
   emitted as `q_scale` (one per tile, or one per channel).
4. **Apply:** `q_tile[i][j] = sat( round_<ROUND>( acc[i][j] >> s ) )` into the
   signed `OUT_W` range, with the `>>` arithmetic (sign-preserving) and the
   rounding done before the clamp. Outputs: `q_valid` (1-cycle, tracks the input
   `tile_valid` through `REG_STAGES`), `q_tile` (`GRID_M*GRID_N*OUT_W`, row-major
   like `acc_tile`), `q_scale` (`EXP_W`, or `GRID_M/GRID_N * EXP_W` per channel),
   and a sticky `q_clip` if any element saturated after the shift (should be rare
   by construction — a non-zero `q_clip` on a well-scaled block is a bug signal).
5. `sim/cocotb/test_tile_requantize.py` + `Makefile.tile_requantize`: bit-exact
   vs a NumPy block-float reference (`np.right_shift` with the matching round /
   clamp), swept over `GRID_*`, `OUT_W ∈ {4,8}`, `SCALE_MODE`, `ROUND`, plus the
   directed corners in the Green bullet. `bash sim/lint.sh` exit 0 with the new
   top; Cocotb `TESTS=… PASS=… FAIL=0` on the pinned venv; wired into
   `sim/lint.sh` and the guarded `sim/run_tb.sh` stanza.
6. `sv2v mac_rq_<cfg>.sv rtl/gcb_max_reduce.sv rtl/gcb_tile_requantize.sv |
   yosys -p '…; hierarchy -check; proc; check -assert;
   select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr; stat'` at a `chparam`
   bring-up geometry — exit 0, latch-free; `stat` recorded next to
   `sim/yosys068_bless/`.
7. A chained `gcb_mac_tile_array → gcb_tile_requantize` Cocotb TB: one real
   `gcb-wiki/06` attention-projection tile driven through both, asserting
   `dequant(q_tile, q_scale)` is within the stated block-float error bound of the
   FP reference `A @ B`, and a `stat` MACs/cycle + cells row added to the TKT-017
   PPA table.
8. Diff confined to the new RTL + TBs + `sim/lint.sh` / `sim/run_tb.sh` /
   `.gitignore` edits + the `gcb-wiki/07` pointer. Nothing in a frozen module,
   nothing in `gcb_mac_tile_array`.

### Toolchain

The environment is now **pinned** (`gcb-wdm-transceiver/sim/toolchain_manifest.json`,
established by TKT-022's Yellow-Team remediation: Verilator 5.032 / Python
3.12.14 / cocotb 1.9.2 / Yosys 0.68 / sv2v 0.0.12 / numpy 2.5.3, venv at
`~/.venvs/cocotb19`). Before execution, re-run the manifest diff from the
TKT-022 Yellow-Team check; it should now be **empty**. Only if a delta reappears
does the full baseline regression re-run (incl. the TKT-020 R1 `cov_violation=1`
trap) gate this story.

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
