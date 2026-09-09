---
id: TKT-008
title: "GDDR7 tensor-operand DMA engine — architecture scoping & trade study"
date_created: 2026-09-09
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 0.5
  emergence: 0.5
tags:
  - backlog
  - rtl
  - architecture
  - memory
  - dma
  - gddr7
---

# Objective

Architect the GDDR7 DMA engine that feeds the photonic tensor complex. With
TKT-003 / TKT-006 the 48-bit effective addresses (EA) are on
`gcb_tensor_command_wiring`'s sideband (`ea_valid`, `ea_a` / `ea_b` / `ea_dst`,
`dim_k`), and `gcb_tensor_memory_engine`'s A and B host write channels
(`{a,b}_load_req` / `{a,b}_load_band|pass` / `{a,b}_load_done` /
`{a,b}_wr_valid|row|col|kstep|data`) sit undriven, waiting for a loader.
`gcb_tensor_sram_controller.sv` already documents the *structured* address math
the loader must apply to a base; nothing turns an EA into GDDR7 burst
transactions. This ticket produces the **architectural specification** for that
translation — burst scheduling, memory alignment, bus utilisation, and a
latency model — before any RTL, so the execution units are not starved and the
design does not fracture across tensor topologies.

## Context & Constraints

* **Current State:**
  * Sideband from `gcb_tensor_command_wiring` (post-TKT-006): `ea_valid`
    (coincident with `gemm_start`), `ea_a` / `ea_b` / `ea_dst` [47:0],
    `dim_k` [15:0]. The EAs are `BASE[role] + zero_extend(instr_offset[31:0])`,
    48-bit, relocatable.
  * `gcb_tensor_memory_engine` write channels are **beat-addressed**: one
    `VEC_W`-bit operand vector per `(row|col, kstep)` write. At the default
    geometry `VEC_W = K_MAX * INT4_W = 16 * 4 = 64 bits = 8 bytes` (16 INT4
    elements). `a_load_req` / `b_load_req` are level; `a_load_done` /
    `b_load_done` are single-cycle completion pulses; the controller
    **stalls** (`sram_valid` low, counters held) at a ping-pong boundary if
    the prefetch has not landed.
  * `gcb_tensor_sram_controller.sv` header fixes the offset math the loader
    composes with the EA base:
    `A row r, K-step k of band b  -> matrix row  b*GRID_DIM + r, K offset k*K_MAX`;
    `B col c, K-step k of pass p  -> matrix col  p*N_TILE  + c, K offset k*K_MAX`.
  * Geometry envelope (`gcb-wiki/05`): defaults `GRID_DIM=16`, `K_MAX=16`,
    `INT4_W=4`, `M_TOTAL=N_TOTAL=K_TOTAL=4096`, `N_TILE=1024` ->
    `K_STEPS=256`, `N_SUBTILES=64`, `M_BANDS=256`, `N_PASSES=4`. A resident
    A row-band is ~32 KiB (single-buffered), a resident B tile ~2 MiB
    (single-buffered), both ping-pong double-buffered. Dataflow-doc GDDR7
    budget is ~9 GB/s for the 4096^3 INT4 matmul (`gcb-wiki/06`: ~7 GB/s for a
    70B FFN up-projection).
  * `gcb-rtl` already carries a *different* streaming tensor DMA
    (`greencoyote_streaming_dma` = walker + AXI master + CDC FIFO) for the
    optical fabric's activation/weight path. Whether its walker / burst
    patterns transfer here is an open question, not an assumption.
* **Constraint:** Specification only — no RTL in this ticket. The spec must not
  require any change to `gcb_tensor_memory_engine` /
  `gcb_tensor_sram_controller`'s write-channel interface, or to the BPR EA
  contract. It must cover the whole geometry envelope (`M/N/K`, `N_TILE`,
  `OPERAND_BITS in {4, 8}`), not a single point. The GDDR7 PHY / controller
  itself is out of scope (assume a burst-oriented read interface with stated
  timing constants). Deliverable lands under `gcb-spec/docs/` (authoritative),
  cross-linked from `gcb-wiki`.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-008 is Green, delivered through Blue-grade engineering.**
It is a genuine architecture effort — a trade study plus a written spec — but
the outcome is a bounded, in-spec capability (the tensor-operand loader), not a
new platform. A general-purpose scatter/gather DMA or a full memory-controller
QoS subsystem would be **Purple** and is over-scope.

* **Green (target):** A comprehensive spec that defines how a 48-bit EA becomes
  GDDR7 burst transactions — the operand DRAM layout contract, a chosen
  alignment strategy with rationale, a burst-scheduling / coalescing policy,
  and a latency + throughput model that *proves* the double-buffered prefetch
  beats the ping-pong deadline across the geometry envelope (or names the
  GDDR7 sustained-BW / latency constraint that must hold). Plus the DMA
  configuration interface, A/B channel arbitration, and the underrun/error
  path — all parameterised, nothing hardcoded.

* **Yellow (reject):** Jumping straight to RTL with no memory-alignment
  strategy, or hardcoding a burst length / stride set tuned to the default
  `4096^3, N_TILE=1024, INT4` point. It "works" on the demo and fractures the
  moment `N_TILE`, `OPERAND_BITS`, or a transposed B shows up — and every
  later ticket inherits the un-analysed alignment debt.

* **Red (reject):** Changing `gcb_tensor_sram_controller`'s write-channel
  interface or the BPR EA contract to make the DMA easier to write, or
  widening scope into an arbitrary-descriptor scatter/gather engine beyond the
  tensor-operand loader. Both create a multi-concern block later tickets must
  unpick.

* **Purple / Light-gray:** A full memory-controller QoS / virtual-channel
  subsystem is Purple and out of scope. Leaving the A/B channels unfed
  (Light-gray) means the engine can never run a real GEMM — this is the gap
  the ticket closes.

**Explicitly out of scope (separate tickets):**
1. The GDDR7 PHY / memory controller / link training / refresh / QoS.
2. Writing the DMA RTL — a follow-on once this spec is accepted.
3. The compute-stream consumer (`core_valid` / `core_a_flat` / `core_b_flat`
   -> PE array).
4. Softmax / `gcb_inline_vector_unit` data paths and their GDDR7 traffic.
5. Backfilling ticket `telemetry:` blocks (TKT-005 follow-on).

## The "Green" Target

A "Green" outcome is one accepted spec document such that it defines:

1. **EA → GDDR7 byte address.** The exact derivation composing the 48-bit BPR
   EA base with `gcb_tensor_sram_controller`'s documented `band/pass/beat`
   structured offset, with one worked numeric example per operand (an A
   `(band, row, kstep)` and a B `(pass, col, kstep)`), and no double
   translation.
2. **Operand DRAM layout contract.** Dimension order and element size for
   `OPERAND_BITS in {4, 8}`, the stride formulas for an A band and a B tile,
   contiguity guarantees (band = ~32 KiB contiguous, tile = ~2 MiB), and
   whether B may be stored pre-transposed.
3. **Alignment strategy (chosen, with rationale).** The required alignment of a
   BPR base — GDDR7 burst granule, DRAM page/row, or arbitrary with head/tail
   sub-burst handling — who enforces it (allocator / BPR programming vs. the
   DMA), and the bandwidth cost of the rejected options.
4. **Burst-scheduling policy.** How the 8-byte (`VEC_W`) per-beat writes are
   coalesced into GDDR7 bursts (BL16 / BL32), the read order within a band /
   tile for row-buffer locality and bank interleaving, and the handling of a
   non-burst-aligned head/tail.
5. **Latency + throughput model.** A cold-start term plus a sustained-BW term,
   with the GDDR7 timing constants stated, showing the A prefetch completes
   within one band-residency and the B prefetch within one pass-residency
   across the geometry envelope — i.e. a proof the PEs do not starve, or the
   explicit GDDR7 sustained-BW / access-latency constraint that must hold.
6. **DMA configuration / descriptor interface.** What the engine consumes (the
   `ea_*` / `dim_k` / `load_band` / `load_pass` sideband, plus any descriptor
   ring or CSR config), and how strides, precision, and tensor topology are
   parameterised so no burst length or stride is fixed in silicon.
7. **A/B channel arbitration.** The two `load_req` / `load_done` handshakes,
   whether A and B share one GDDR7 read port or use two, and the arbitration
   policy given A has the tighter (band-residency) deadline.
8. **Underrun / error path.** What the DMA signals when a load cannot complete
   before the ping-pong boundary or on a GDDR7 error, and how that composes
   with `gcb_tensor_sram_controller`'s existing stall-on-`!rdy` behaviour.
9. **Reuse survey.** A keep / adapt / discard call on `gcb-rtl`'s
   `greencoyote_streaming_dma` walker and AXI-master patterns — evidence-based,
   not a mandate.
10. **Non-goals recorded** — the five out-of-scope items above, restated in the
    spec so the RTL follow-on inherits the boundary.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Lead Hardware Architect)
* **Commands Run:** none — desk trade study against
  `gcb_tensor_sram_controller.sv` / `gcb_tensor_memory_engine.sv` /
  `gcb_tensor_command_wiring.sv` (interfaces, geometry, FSM residency),
  `gcb-wiki/05` (bandwidth + residency model), `gcb-wiki/08` (EA contract),
  and `gcb-rtl/rtl/greencoyote_{dma_walker,dma_axi_master,cs_lane_fifo,
  streaming_dma}.sv` (the reuse survey).
* **Artifacts Touched:**
  * `gcb-wiki/11_gddr7_tensor_dma_architecture.md` — NEW. The spec / trade
    study, all ten Green-Target criteria:
    1. **EA → GDDR7 byte address** — `X_addr = ea + matrix_idx*ROW_STRIDE +
       k*VEC_BYTES` with `ROW_STRIDE = K_STEPS*VEC_BYTES`; two worked numeric
       examples (A `band=3,r=5,k=100` → `0x0005_0001_AB20`; B
       `pass=2,c=300,k=7` → `0x0007_1049_6038`); one translation only (BPR
       added the instruction offset; DMA adds only the structured offset).
    2. **DRAM layout contract** — A row-major K-contiguous (band = 32 KiB
       contiguous); **B stored transposed, N-major K-contiguous** (tile =
       2 MiB contiguous) — K-major B rejected (256× the page activations);
       `OPERAND_BITS ∈ {4,8}` scales `VEC_BYTES`/`ROW_STRIDE` only.
    3. **Alignment** — 64 B base alignment mandatory (allocator-enforced, DMA
       raises `CFG_ERR` otherwise); 2 KiB page alignment recommended not
       required (unaligned costs ~2.7% extra `tRCD`, never a stall);
       arbitrary-alignment head/tail + byte-rotate rejected (< 0.1% BW for a
       shifter datapath).
    4. **Burst coalescing** — BL32 (128 B / 16 beats) along `k`, BL16 fallback;
       one matrix row/col = one 2048 B page = 16× BL32; 8-deep bank-group
       activate pipeline hides `tRCD` on the sustained path; strictly ascending
       `(r,k)`/`(c,k)`.
    5. **Latency/throughput proof** — `t_load = 30 ns + bytes/90 GB/s`.
       A band 0.39 µs vs the 8.192 µs residency deadline → **20.8× margin**
       (2.5× even at 10 GB/s); B tile 23.3 µs vs 2.097 ms → 90×; cold-start
       ~23 µs (pre-sequence, no deadline, 0.3% of the GEMM). Aggregate demand
       ~4.8 GB/s read = ~5% of one GDDR7 channel — latency-bound, not
       BW-bound, and latency clears.
    6. **Config interface** — v1 descriptor-free / closed-form; per-GEMM
       `{ea_a,ea_b,ea_dst,dim_k}` latched at `ea_valid`; a CSR block
       (`VEC_BYTES`, `ROW_STRIDE`, grid/tile/pass params, `B_LAYOUT`, `CTRL`,
       `STATUS`, `IRQ_EN`) — topology in CSR + the closed form, never a
       hardcoded burst table. v2 32-B descriptor ring deferred (format reused
       from `gcb-spec/docs/streaming_dma_architecture.md`).
    7. **A/B arbitration** — one shared GDDR7 read port; strict priority to A,
       B preemptible at page boundaries; worst-case A latency ~2.2 µs ≪
       8.192 µs; B set back ~100 µs / 2.097 ms pass; page- not beat-level
       preemption (no partial-burst state, avoids a `tRP+tRCD` re-activate).
    8. **Underrun/error** — sticky `UNDERRUN` (missed deadline, informational —
       controller already stalls-on-`!rdy`), `ERR` + IRQ (GDDR7 read error →
       DMA withholds `*_load_done`, no silent bad data), `CFG_ERR` + IRQ
       (misaligned base / inconsistent CSR).
    9. **Reuse call** — `cs_lane_fifo` **KEEP verbatim** (CDC FIFO);
       `dma_walker` **ADAPT for v2 only** (stride-nest arithmetic);
       `dma_axi_master` **ADAPT skeleton, replace protocol** (bank-array +
       CDC pattern kept, AXI4 burst layer replaced by the GDDR7 burst
       engine). 1 KEEP / 2 ADAPT / 0 verbatim protocol reuse.
    10. **Non-goals** restated — PHY/controller/QoS, the DMA RTL, the
        compute-stream consumer, `dst` write-back + softmax traffic, the v2
        descriptor ring.
  * `gcb-wiki/README.md` — index row 11 added (L1).
  * `gcb-workspaces/README.md` — TKT-008 index row → `done | green`.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** In-spec architecture deliverable, delivered with trade-study
rigour, removing a hard blocker. All ten Green-Target criteria met in one
`gcb-wiki/11` spec: closed-form EA→GDDR7 addressing (worked examples, single
translation), an explicit DRAM layout contract (B transposed), a defended
alignment decision (64 B mandatory / 2 KiB recommended), a BL32 coalescing +
bank-group activate-pipeline scheduling policy, and a quantified latency model
proving the A prefetch beats the 8.192 µs ping-pong deadline 20× (2.5× at a
pathological 10 GB/s) — i.e. a real no-starve proof, not an assertion. Strict-
priority-A / page-preemptible-B arbitration on one shared port with a
worst-case A latency of ~2.2 µs. Component-level keep/adapt/discard on
`greencoyote_streaming_dma` (1 KEEP, 2 ADAPT). No RTL (correctly — that is the
follow-on). **PBG vector T = (spec 1.0, quality 0.5, emergence 0.5)**,
‖T‖₂ = √1.5 ≈ 1.225; derived dominant spoke = green (argmax |axis| = X).
