---
id: TKT-009
title: "GDDR7 tensor-operand DMA — RTL implementation (arbiter + bank-group pipeline)"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - dma
  - gddr7
  - memory
---

# Objective

Write the SystemVerilog RTL for the GDDR7 tensor-operand DMA in
`gcb-wdm-transceiver`, realising `gcb-wiki/11_gddr7_tensor_dma_architecture.md`.
The core is `gcb_tensor_dma_arbiter` plus the bank-group activate pipeline and
the BL32 burst engine: page-aligned coalescing along `k`, an 8-deep bank-group
activate pipeline, strict-priority-A / page-preemptible-B arbitration on one
shared GDDR7 read port, closed-form (descriptor-free) addressing, and the
underrun / error status path. This ticket *implements* Doc 11 — it does not
re-open the trade study.

## Context & Constraints

* **Current State:**
  * `gcb-wiki/11` fixes every policy: EA→byte-address formula
    (`X_addr = ea + matrix_idx*ROW_STRIDE + k*VEC_BYTES`), the A row-major /
    B-transposed DRAM layout contract, 64 B mandatory base alignment (2 KiB
    recommended), BL32 (128 B / 16 beats) coalescing with BL16 tail fallback,
    the latency model (A prefetch clears the 8.192 µs band-residency deadline
    ~20×), the strict-priority-A / page-preemptible-B arbiter, and the
    `UNDERRUN` / `ERR` / `CFG_ERR` status semantics.
  * **Frozen interfaces this RTL binds to, unchanged:** the
    `gcb_tensor_command_wiring` sideband (`ea_valid`, `ea_a` / `ea_b` /
    `ea_dst` [47:0], `dim_k`) and `gcb_tensor_memory_engine`'s A/B host write
    channels (`{a,b}_load_req` / `{a,b}_load_band|pass` / `{a,b}_load_done` /
    `{a,b}_wr_valid|row|col|kstep|data`). No edit to
    `gcb_tensor_memory_engine` / `gcb_tensor_sram_controller` /
    `gcb_tensor_command_wiring` / `gcb_opcode_dispatcher`.
  * The GDDR7 PHY / memory controller is out of scope (Doc 11 §11). The RTL
    speaks to an abstract burst-oriented read port (address, BL16/BL32,
    bank-group id, valid/ready, read-data beats); a testbench BFM models
    `tRCD` / `tCL` / sustained BW and stands in for the controller.
  * EDA doctrine (`gcb-wiki/10`): hand-written SystemVerilog (IEEE 1800-2012),
    Verilator 5 for sim + lint, Yosys + Surelog/UHDM must elaborate it. The
    parameter / CSR wrapper generation is **TKT-010's** job, not this ticket's
    — this ticket keeps the datapath modules hand-written with plain
    `parameter`s.
  * v1 is descriptor-free / closed-form (Doc 11 §7). The v2 descriptor ring is
    out of scope.
* **Constraint:** Synthesizable SV. Verilator 5 lint-clean at the
  `gcb-wdm-transceiver/sim/lint.sh` bar (add the new tops). Yosys + Surelog
  elaboration must pass (no constructs the UHDM front end rejects). Directed
  testbenches in the repo's house style (`#1`-after-edge drives,
  `ALL CHECKS PASS`), registered in `sim/lint.sh` and `sim/run_tb.sh`. All
  Doc 11 figures (`ROW_STRIDE`, `VEC_BYTES`, burst length, geometry) are RTL
  parameters, never literals.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-009 is Green, delivered through Blue-grade engineering** —
real synthesizable RTL plus real verification against the Doc 11 latency model.

* **Green (target):** `gcb_tensor_dma_arbiter` + the BL32 burst engine + the
  bank-group activate pipeline as parameterised SV, binding the frozen
  sideband and write-channel interfaces, elaborating in Yosys/Surelog,
  Verilator-lint-clean, with directed testbenches that exercise the closed-form
  addressing, the A-preempts-B-at-page-boundary arbiter with a bounded
  worst-case A latency, and the ping-pong latency constraint against a
  timing-accurate GDDR7 BFM.

* **Yellow (reject):** Hard-coding burst length / strides / geometry to the
  default `4096³, N_TILE=1024, INT4` point (Doc 11's own Yellow), or "proving"
  the latency constraint against an instant-return memory model instead of a
  BFM with real `tRCD` / sustained-BW behaviour.

* **Red (reject):** Changing the `gcb_tensor_memory_engine` write-channel
  interface or the BPR EA contract to simplify the DMA, or folding the v2
  descriptor ring / a generic scatter-gather path into this module.

* **Purple / Light-gray:** A memory-controller QoS subsystem is Purple / out of
  scope. Leaving the A/B channels unfed (Light-gray) blocks every real GEMM —
  the gap this closes.

**Explicitly out of scope (separate tickets):**
1. The GDDR7 PHY / memory controller / training / refresh.
2. The DMA parameter / CSR wrapper **generator** — TKT-010.
3. The v2 descriptor ring (gather / strided / batched).
4. `dst` write-back and Softmax / vector-unit GDDR7 traffic.
5. End-to-end integration with a real GDDR7 model (BFM only here).

## The "Green" Target

1. New RTL under `gcb-wdm-transceiver/rtl/`: at least `gcb_tensor_dma_arbiter.sv`
   (A/B request arbitration, page-boundary preemption) and the burst engine +
   bank-group activate pipeline (one module or a small hierarchy), all with
   plain `parameter`s for `VEC_BYTES`, `ROW_STRIDE`, `GRID_DIM`, `K_STEPS`,
   `N_TILE`, `M_BANDS`, `N_PASSES`, burst length.
2. Binds the frozen `gcb_tensor_command_wiring` sideband and the
   `gcb_tensor_memory_engine` A/B write channels with zero interface change to
   either.
3. Closed-form address generation per Doc 11 §1 — a directed test checks the
   two worked examples (A `band=3,r=5,k=100`, B `pass=2,c=300,k=7`) bit-exact.
4. BL32 coalescing along `k` with a BL16 tail fallback; strictly ascending
   `(r,k)` / `(c,k)`; the 8-deep bank-group activate pipeline hides `tRCD` on
   the sustained path (checked: only the first page of a band/tile pays it).
5. Arbiter: `a_load_req` preempts an in-flight B stream **at the next GDDR7
   page boundary**; a test measures worst-case A latency and asserts it is
   below one band residency (and matches Doc 11's ~2.2 µs at the modelled
   constants, scaled to the test geometry).
6. Ping-pong latency proof in simulation: at a tiny geometry with a GDDR7 BFM
   modelling `tRCD` / `tCL` / a capped sustained BW, the A prefetch completes
   before its band boundary and B before its pass boundary, with no
   `sram_valid` stall in `gcb_tensor_sram_controller`.
7. `UNDERRUN` (sticky), `ERR` (+ withholds `*_load_done`, no silent bad data),
   `CFG_ERR` (misaligned `ea_a[5:0]` / `ea_b[5:0]` or CSR inconsistent with
   `dim_k`) exposed on a status word; tests force each.
8. `bash sim/lint.sh` exit 0 across all tops (new modules added); Yosys +
   Surelog/UHDM elaboration of the new tops passes. New testbenches print
   `ALL CHECKS PASS` and are wired into `sim/lint.sh` + `sim/run_tb.sh`.
9. The diff is the new RTL + testbenches + the two sim-list edits — nothing in
   the frozen modules, nothing from the out-of-scope list.

---
## Execution Log
*(To be populated during execution)*
* **Agent ID:**
* **Commands Run:**
* **Artifacts Touched:**

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
