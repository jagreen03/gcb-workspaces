---
id: TKT-022
title: "Story 1 of EPIC TKT-017 — gcb_mac_tile_array: verified INT4 MAC tile array (SRAM operands → dot-product grid → wide accumulators)"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - compute
  - matmul
  - int4
  - epic-tkt-017
---

# Objective

**Story 1 of EPIC TKT-017** (Compute execution units). Design
`gcb-wdm-transceiver/rtl/gcb_mac_tile_array.sv` — the core execution grid that:

1. pulls **INT4** weight and activation operands from the **verified TKT-012
   banked 1W1R SRAM macros**, through the frozen `gcb_tensor_sram_controller`
   read port / operand-staging path (the `0 read-stall` guarantee, now also
   guarded by the TKT-020 R1 write-coverage trap);
2. computes the per-PE **dot products** across the `K` contraction steps;
3. **accumulates** the partial sums into wide accumulators (INT32 default,
   INT16 selectable narrow-tile mode) with a documented overflow / saturation
   policy;
4. hands the accumulated tile off to the **`gcb_max_reduce` requantize stage**
   (per-tile / per-channel block-float max scale — the TKT-016 primitive's
   third consumer, per the Epic's Purple note) and thence to the softmax
   (`gcb_inline_vector_unit`) and optical-QAM (`gcb_qam_datapath_top`)
   consumers.

This story owns **the MAC grid and its accumulator geometry only**. Operand
staging fabric detail, the requantize datapath internals, and the full
end-to-end integration TB are sibling TKT-017 sub-stories.

## Context & Constraints

* **Current State:**
  * `gcb-wdm-transceiver/rtl/gcb_int4_mac_array.sv` exists as a MAC primitive;
    `gcb_tensor_broadcast_fabric.sv` distributes operands; TKT-012 delivered the
    banked 1W1R operand SRAM behind the frozen `gcb_tensor_memory_engine`, with a
    proven `0 read-stall` grid read and (TKT-020 R1) a write-coverage assertion
    that hard-fails a partial tile load instead of returning silent zeros.
  * `gcb_max_reduce.sv` (TKT-016) is verified and area-quantified; it is the
    intended requantize-scale reducer.
  * `gcb-wiki/06` holds a 70B-transformer layer trace (tile shapes, dtypes);
    `gcb-wiki/07` specifies the inline-vector / softmax datapath.
  * There is no `gcb_mac_tile_array` that ties a parameterised PE grid to the
    SRAM read port with a proven wide-accumulator GEMM.
* **Constraint:**
  * One hand-written file `gcb-wdm-transceiver/rtl/gcb_mac_tile_array.sv`, pure
    **SV-2017**, fully parameterised — PE-grid dims, contraction depth,
    operand width, accumulator width, signedness, pipeline stages, narrow-mode
    saturation — with **no tile-specific literal**.
  * **No edit to any frozen-list interface** (`gcb_tensor_memory_engine`,
    `gcb_tensor_sram_controller` ports, `gcb_max_reduce`). They are instantiated
    unchanged.
  * Verilator-5 `sim/lint.sh`-clean with the new top added; Cocotb ≥ 1.9
    (`/tmp/cocotb19`, `SIM=verilator`); `sv2v`→Yosys elaboration checked and
    latch-free at a bring-up geometry (`chparam` — the default geometry
    bit-blast is intractable, per the TKT-020 Y1 finding).
  * PBG / Cyclopter prompt-layer protocol stays out of the RTL repo
    (`gcb-wiki/04`).

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-022 is Green, through Blue-grade engineering** — a small,
fully parameterised MAC grid with a bit-exact NumPy INT4 equivalence proof and a
MACs/cycle + cell-count line for the Epic's PPA burn-down.

* **Green (target):** `gcb_mac_tile_array.sv` as scoped, plus
  `sim/cocotb/test_mac_tile_array.py` proving **bit-exact** hardware matrix
  multiplication against a NumPy INT4 golden model over swept grid / K /
  signedness and directed corners (all `-8`, all `+7`, alternating sign, `K=1`,
  single-PE, non-power-of-two grid dims) **and** the INT16 narrow-mode
  saturation boundary. `bash sim/lint.sh` exit 0 with the new top wired into
  `sim/lint.sh` and the guarded `sim/run_tb.sh` stanza; `sv2v`→Yosys
  elaboration clean and latch-free at a `chparam` bring-up geometry; a Yosys
  `stat` MACs/cycle + cell-count row for the TKT-017 PPA table.
* **Blue:** the accumulator width **derived, not guessed** (rationale below), a
  frozen NumPy INT4 reference reused by the later integration TB, `REG_STAGES`
  retiming-friendly pipelining with a drain proof, an overflow-sticky status
  bit, and a one-line pointer added to `gcb-wiki/06`.
* **Yellow (reject):** a "GEMM" TB that checks only small random matrices and
  never runs a real `gcb-wiki/06` attention-projection tile shape through the
  actual SRAM read port; hard-coded `2×2` grid with no parameterisation;
  accumulator width picked as "32 looks fine" with no `log2(K)` argument.
* **Red (reject):** editing a frozen interface to "make integration easier"; a
  monolithic module fusing staging + MAC + requantize with no unit-testable
  seam; silent accumulator wrap with no status bit.
* **Purple / Light-gray:** a reconfigurable systolic fabric with dataflow
  switching is Purple / a later Epic; leaving the GEMM proven only on random
  stimulus (Light-gray) carries the integration risk into the demo.

**Explicitly out of scope (sibling TKT-017 sub-stories / other Epics):**
1. The operand-staging fabric internals and its own TB.
2. The requantize datapath beyond the `gcb_max_reduce` hand-off contract.
3. The full SRAM→MAC→softmax end-to-end integration TB.
4. Physical PPA / floorplan / GDSII — TKT-018 (toolchain now provisioned by
   **TKT-021**).
5. Training-time INT4 quantisation calibration — taken as given.

## The "Green" Target

1. `gcb-wdm-transceiver/rtl/gcb_mac_tile_array.sv` — one synthesizable SV-2017
   module. Parameters (names indicative): `GRID_M`, `GRID_N` (PE array),
   `K_STEPS` (contraction unroll / streaming depth), `OPND_W` (= 4, INT4),
   `ACC_W` (= 32 default), `SIGNED` (= 1), `REG_STAGES` (pipeline cut count,
   0 = combinational), `SATURATE` (narrow-mode clamp + sticky overflow).
   No tile-specific literal; grid dims need not be powers of two.
2. **Accumulator bit-width — derived:**
   * Signed INT4 operand ∈ `[-8, +7]`. One partial product ∈ `[-56, +64]` →
     **8 bits** signed (7 magnitude + sign).
   * A `K`-deep dot product has `|Σ| ≤ K · 64`, needing `8 + ⌈log2 K⌉` bits.
   * `gcb-wiki/06` 70B attention / projection tiles have contraction depth
     `K` up to ≈ 4096–8192 → `8 + 13` = **21 bits**; add headroom for
     partial-sum chaining across `N_PASSES` / `M_BANDS` tile passes before
     requantize → **`ACC_W = 32` (INT32) is the default**, giving ≥ 11 bits of
     margin at `K = 4096`.
   * **`ACC_W = 16` (INT16)** is a selectable narrow-tile mode for short
     contraction (`K ≲ 500`, `8 + 9 = 17` bits — so 16-bit needs the clamp):
     valid only with `SATURATE = 1`, which clamps to `±(2^15−1)` and raises a
     sticky `acc_ovf` status bit. The TB proves the exact saturation boundary.
   * Down-conversion back to INT4 / INT8 for the consumers is done by the
     **frozen `gcb_max_reduce`** block-float scale in the requantize sub-story —
     out of scope here beyond presenting `ACC_W`-wide accumulators and the
     `acc_ovf` flag on the hand-off.
3. `sim/cocotb/test_mac_tile_array.py`: bit-exact vs a NumPy INT4 golden model
   (`np.int8` products, explicit two's-complement wrap for `ACC_W=32`,
   documented clamp for `ACC_W=16`), swept over `GRID_M/GRID_N/K_STEPS/SIGNED`,
   plus the directed corners and the saturation-boundary test.
4. `bash sim/lint.sh` exit 0 with `gcb_mac_tile_array` added to the RTL list and
   the top loop; Cocotb `TESTS=… PASS=… FAIL=0`; wired into `sim/lint.sh` and
   the guarded `sim/run_tb.sh` stanza.
5. `sv2v mac_<cfg>.sv rtl/gcb_mac_tile_array.sv | yosys -p '…; hierarchy -check;
   proc; check -assert; select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr;
   synth -flatten; stat'` at a `chparam` bring-up geometry — exit 0, latch-free.
6. A Yosys `stat` row — MACs/cycle, cell count, and (with the SRAM read port
   width) bandwidth utilisation — added to the TKT-017 PPA burn-down table.
7. Diff confined to the new RTL + TB + `sim/lint.sh` / `sim/run_tb.sh` /
   `.gitignore` edits + the `gcb-wiki/06` pointer. Nothing in a frozen module.

---
## Yellow-Team AI Check — WSL toolchain drift from TKT-021 (gate before execution)

**Why this is here.** **TKT-021** mutated the *shared* WSL2 environment that
every prior green RTL ticket was verified in, in order to build OpenROAD:

* a **KLayout 0.30.12 `.deb`** (`apt-get install ./klayout*.deb` — pulls
  transitive Qt / `libstdc++` / Python packages);
* an **ORFS `setup.sh` apt pass** (gcc/g++, cmake, boost, tcl, swig, spdlog,
  eigen, python3-dev — any of which `apt` may bring to a newer point release);
* **`.wslconfig` changes** (`swap=8GB`, `autoMemoryReclaim=disabled`) applied
  with **`wsl --shutdown`**, which restarts the guest.

The TKT-009 / TKT-012 / TKT-016 / TKT-020 Execution Logs each recorded their
`FAIL=0` under a *specific* toolchain — **Verilator 5.032, `sv2v` 0.0.12,
Yosys 0.52, cocotb 1.9.2 (`/tmp/cocotb19`, Python 3.12), Node 22.x**. An `apt`
upgrade, a transitive `libstdc++` bump, or a rebuilt WSL rootfs can move any of
these **silently**, and a moved lint / elaboration back end can change output
without any RTL changing. The MAC array must be verified against the *known*
toolchain, not a drifted one.

**The check (AI-orchestrated; run and recorded before any
`gcb_mac_tile_array.sv` lands):**

1. **Toolchain manifest diff.** Capture, in the post-TKT-021 WSL guest:
   `verilator --version`, `sv2v --numeric-version`, `yosys -V`, `node -v`,
   `python3 -V`, `pip show cocotb` (in `/tmp/cocotb19`), `klayout -v`,
   `gcc --version`, `cmake --version`. Diff against the versions the
   TKT-009 / 012 / 016 / 021 logs cite. **Any delta is a finding.**
2. **Regression re-run of the locked baseline.** In `gcb-wdm-transceiver`:
   `bash sim/lint.sh` → expect **exit 0, 29 tops**; then the guarded
   `sim/run_tb.sh` cocotb stanzas for `gcb_max_reduce` (`Makefile.max_reduce`),
   the operand SRAM (`Makefile.sram`), and the TKT-020 R1 partial-load
   (`Makefile.sram_partial`) → all **`FAIL=0`**, and `Makefile.sram_partial`
   must still show **`cov_violation=1`, `cov_events≥1`** on the partial-load
   test (the R1 trap still fires under the moved toolchain).
3. **Elaboration re-check.** `sv2v`→Yosys `hierarchy -check; proc; check -assert`
   + latch-free `select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr` for
   `gcb_tensor_sram_controller` and `gcb_max_reduce` at their TKT-012 / TKT-016
   bring-up geometries — output identical to what those tickets recorded.
4. **cocotb venv integrity.** Confirm `/tmp/cocotb19` still resolves to a
   Python 3.12 interpreter (a rebuilt rootfs drops `/tmp`). If gone, re-create
   per the TKT-012 recipe (`uv venv --python 3.12 /tmp/cocotb19` +
   `uv pip install 'cocotb>=1.9,<2.0'`) and record it.

**Disposition.** Proceed to `gcb_mac_tile_array` execution **only if** the
manifest diff is empty, **or** every delta is explicitly reviewed and steps 2–4
still reproduce the recorded results. A silent version bump that changes any
lint / elaboration / cocotb output is a **Yellow finding filed back as a TKT-022
blocker** — the MAC array is not "verified" if the toolchain under it moved
without being re-pinned. (Root cause of the drift risk: TKT-021's Y `-0.5` —
the OpenROAD build shares one un-containerised WSL guest with the RTL flow.)

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
