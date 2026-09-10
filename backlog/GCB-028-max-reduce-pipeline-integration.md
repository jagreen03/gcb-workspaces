---
id: GCB-028
title: "Architecture-from-measurement — pipeline gcb_max_reduce (REG_STAGES=2) in the requantize path and re-prove the stall-free e2e dataflow"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - compute
  - physical-design
  - pipeline
  - measurement-epoch
  - epic-tkt-017
---

# Objective

Execute the **Orange Team feedback loop** opened by [[GCB-027]]. The first
physical pass measured `gcb_max_reduce` (default `WIDTH=16 N_ELEMENTS=64
OUTPUT=BOTH REG_STAGES=0`) as a **~1.67 ns combinational cone**
(`WNS = −665.45 ps` against a 1 ns target in ASAP7) — it is **timing-bound** and
cannot sit single-cycle on any datapath faster than ~600 MHz.

`gcb_max_reduce` already carries a `REG_STAGES` parameter (TKT-016); synthesis
retiming distributes the registers into the tournament tree. This ticket:

1. **wires `REG_STAGES = 2` into the `gcb_max_reduce` instantiation inside
   `gcb_tile_requantize.sv`** (GCB-era / TKT-023 — the compute-path consumer
   that will drive the primitive on a real timed path), with the requantizer's
   own datapath re-aligned to the new internal latency so it stays functionally
   identical (+ latency only);
2. **adjusts the integration testbenches** for the new pipeline latency;
3. **re-proves the end-to-end compute dataflow is still stall-free and
   bit-exact** with the pipelined requantizer — the specific claim being that
   *inserting pipeline stages to meet physical timing does not perturb the
   operand feed*, because the added latency is strictly downstream of the frozen
   `gcb_tensor_sram_controller` read port and the `gcb_mac_tile_array`.

## Context & Constraints

* **Current state:**
  * `gcb_tile_requantize.sv` (TKT-023) instantiates one `gcb_max_reduce` per
    reduction channel with `REG_STAGES(0)` and is itself combinational except
    for its `REG_STAGES` output pipe and the sticky `q_clip`.
  * `gcb_max_reduce.sv` (TKT-016) — `REG_STAGES` param already implemented and
    Cocotb-proven; **not modified here**.
  * The compute path is functionally green end-to-end at **4096 MAC/cycle,
    0 SRAM read stalls** (EPIC TKT-017 / TKT-025) — but that proof never put
    `gcb_max_reduce` on a timed critical path.
  * The pinned RTL Baseline (`gcb-wdm-transceiver/sim/toolchain_manifest.json`)
    and every frozen interface stay as-is. `gcb_max_reduce`,
    `gcb_tensor_sram_controller`, `gcb_tensor_operand_sram`, `gcb_mac_tile_array`
    and `gcb_inline_vector_unit` are **not** re-architected — only the
    `gcb_tile_requantize` instantiation of `gcb_max_reduce` and the
    requantizer's internal latency alignment change.
* **Constraint:**
  * `gcb_tile_requantize.sv` gains a parameter (e.g. `MAXRED_REG_STAGES`,
    default `2`) passed straight to its `gcb_max_reduce` instances. Because
    `ch_max` then lands `MAXRED_REG_STAGES` cycles after `in_valid`, the
    requantizer must delay `pe_mag` / the per-element apply inputs / `in_valid`
    by the same amount so the shift-derive + apply stages see aligned operands.
    `MAXRED_REG_STAGES = 0` must reproduce the exact current behaviour
    (bit-identical, zero added latency) so nothing else regresses.
  * Pure SV-2017; Verilator-5 `sim/lint.sh`-clean; `sv2v` → Yosys **0.68**
    elaboration clean and **latch-free** at a `chparam` bring-up geometry
    (re-bless `sim/yosys068_bless/tile_requantize.stat`).
  * Cocotb on the pinned venv (`~/.venvs/cocotb19`).
  * PBG / Cyclopter prompt-layer protocol stays out of the RTL repo
    (`gcb-wiki/04`).

## AI Orchestration Priorities (PBG Evaluation)

**The target for GCB-028 is Green, through Blue-grade engineering** — the
minimal RTL change that acts on the GCB-027 measurement, proven not to disturb
the stall-free dataflow.

* **Green (target):** `gcb_tile_requantize` with `MAXRED_REG_STAGES = 2`
  (default), internally re-aligned so it is functionally identical + latency
  only; every requantize/chain/e2e Cocotb TB updated for the new latency and
  **still bit-exact**; `test_compute_e2e.py` **passes with the pipelined
  requantizer, `stall_count == 0` unchanged**; `sim/lint.sh` exit 0; `sv2v` →
  Yosys 0.68 elaboration clean + latch-free (re-blessed).
* **Blue:** `MAXRED_REG_STAGES = 0` proven bit-identical to the pre-change RTL
  (a regression guard); the alignment delay written as a clean valid-gated pipe
  reusing the requantizer's existing style; a one-line note in
  `GCB-027-FINDINGS.md` / the `docs/PPA_burndown.md` closing the loop.
* **Yellow (reject):** hard-coding `REG_STAGES=2` with no parameter and no
  `=0` regression path; "fixing" the latency by hand-tweaking TB wait counts
  until they pass without understanding the new pipe depth; skipping the
  `stall_count == 0` re-check (the whole point).
* **Red (reject):** re-architecting `gcb_max_reduce`, the SRAM controller, the
  MAC array, or any frozen interface; moving the pipeline registers *upstream*
  of the MAC array (that could starve the operand feed); editing
  `gcb_max_reduce.sv`.
* **Purple / Light-gray:** a full radix-`k` / 4-ary tournament redesign of
  `gcb_max_reduce` is a later trade study (its own `GCB-###`); leaving
  `gcb_max_reduce` combinational everywhere (Light-gray) ships the −665 ps
  critical path into the first real timed datapath.

## The "Green" Target

1. `gcb-wdm-transceiver/rtl/gcb_tile_requantize.sv` — new `MAXRED_REG_STAGES`
   parameter (default `2`), passed to the internal `gcb_max_reduce` instances;
   an internal `pe_mag` / `in_valid` alignment delay of `MAXRED_REG_STAGES`
   cycles so the shift-derive + apply stages see operands aligned with the
   (now-delayed) `ch_max`; `q_valid` / `q_tile` / `q_scale` / `q_clip` emerge
   `MAXRED_REG_STAGES` cycles later than today. `MAXRED_REG_STAGES = 0`
   reproduces the current RTL bit-for-bit.
2. `sv2v` → Yosys 0.68 elaboration at a `chparam` bring-up geometry: `check
   -assert` 0 problems, `select -assert-count 0 t:$dlatch t:$dlatchsr t:$sr`
   clean; refresh `sim/yosys068_bless/tile_requantize.stat` + `SUMMARY.md`.
3. Cocotb:
   * `test_tile_requantize.py` — sample `q_tile` / `q_scale` / `q_clip` on the
     (now-delayed) `q_valid` instead of combinationally; still **64 blocks
     bit-exact** across the 4 param sets; add a directed `MAXRED_REG_STAGES = 0`
     vs `= 2` equivalence check (same values, 2-cycle shift).
   * `test_mac_requant_chain.py`, `test_stage_mac_requant.py` — bump the
     post-`done` collection margin for the extra latency; **still bit-exact**.
   * `test_compute_e2e.py` — **the Green gate.** `MAXRED_REG_STAGES = 2` in the
     e2e TB's requantize instance; assert all **40/40** MAC INT32 + **40/40**
     requantize INT4 tiles bit-exact, the softmax `row_max` sample bit-exact,
     the reassembled `C == requantize(A @ B)`, and **`stall_count == 0`
     unchanged** — the pipeline latency is downstream of the SRAM read port and
     the MAC grid, so it must not add a single read stall.
4. `bash sim/lint.sh` exit 0; every Cocotb suite `FAIL = 0` on the pinned venv;
   `sim/run_tb.sh` stanzas unchanged (same Makefiles).
5. `docs/PPA_burndown.md` + `GCB-027-FINDINGS.md` get a one-line "loop closed:
   requantize path now instantiates `gcb_max_reduce` with `REG_STAGES=2`"
   note. Diff confined to `gcb_tile_requantize.sv` + the four test files + the
   bless stat + the two doc lines. Nothing else in a frozen module.

### Follow-on (not this ticket)

* Re-run the [[GCB-027]] ORFS/ASAP7 pass on `gcb_max_reduce` at `REG_STAGES=2`
  to confirm `WNS ≥ 0` at the 1 ns target — closes the measurement loop with a
  second measurement. Its own `GCB-###`, in the isolated P&R env.
* `OUTPUT="VALUE"` (drop the index datapath) where consumers don't need the
  argmax — a separate area/timing trade.
* TKT-019 optical-serialization sizing must budget the QAM-slice
  `gcb_max_reduce` as a 2–3 cycle pipelined block (tracked in
  [[GCB-027-FINDINGS]]).

### Toolchain

Pinned RTL Baseline (`gcb-wdm-transceiver/sim/toolchain_manifest.json`)
unchanged. Re-run the manifest diff before execution; a delta re-triggers the
TKT-022 Yellow-Team baseline regression as a gate.

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
