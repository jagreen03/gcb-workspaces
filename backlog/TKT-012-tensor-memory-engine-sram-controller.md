---
id: TKT-012
title: "Tensor operand SRAM — allocation strategy + real controller behind the frozen engine"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - sram
  - memory
  - tensor
---

# Objective

Turn `gcb_tensor_memory_engine` / `gcb_tensor_sram_controller` from a behavioural
model into a synthesizable, macro-friendly on-chip operand buffer. It must hold
the double-buffered resident **A-band** (`GRID_DIM * K_STEPS * VEC_BYTES` = 32 KiB
at INT4 defaults) and **B-tile** (`N_TILE * K_STEPS * VEC_BYTES` = 2 MiB) fed by
the now-verified GDDR7 DMA (`TKT-009`), and arbitrate its ports so the DMA fill
path (write) and the execution grid's operand fetch (read) never corrupt or stall
each other. The frozen interface does not change — this ticket implements what is
behind it.

## Context & Constraints

* **Current State:**
  * `gcb_tensor_memory_engine.sv` and `gcb_tensor_sram_controller.sv` already
    exist with **frozen interfaces** and were used verbatim as the `TKT-009`
    Cocotb DUT (`sim/cocotb/dma_tb_top.sv` instantiates the real engine). The
    FSM (`ST_IDLE -> ST_PRIME -> ST_RUN -> ST_DONE`), the ping-pong bank swap
    (`a_bank` / `b_bank`), `sram_valid` / `sram_rdata`, and the `stalled` /
    `advancing` logic are all present. What is *not* real: storage is plain
    `logic [] *_mem` arrays with a `SRAM_LATENCY` knob — no bank/port model, no
    arbitration, nothing an SRAM compiler or OpenROAD can map.
  * `TKT-009` delivered `gcb_tensor_dma_arbiter`, which drives
    `{a,b}_wr_valid / row|col / kstep / data` at exactly **one `VEC_W` (8 B)
    beat per cycle** (16 GB/s @ 2 GHz). Its no-stall proof established that this
    write-beat port is the fill-rate limiter and that the SRAM controller must
    accept **every** beat with no backpressure.
  * `gcb-wiki/11` §6 (revised): band residency = `N_SUBTILES * K_STEPS` cycles;
    the grid reads the resident bank while the DMA fills the other; A-band fill
    = `GRID_DIM * K_STEPS` beats (4x margin), B-tile fill = `N_TILE * K_STEPS`
    beats.
  * There is no `gcb-wiki` note on the on-chip operand memory — capacity math,
    bank/port topology, and the double-buffer layout are undocumented.
  * Frozen modules this binds to, unchanged: `gcb_tensor_memory_engine` ports,
    `gcb_tensor_broadcast_fabric` (the grid read path), `gcb_tensor_dma_arbiter`
    (the write path).
* **Constraint:** Synthesizable SV-2017, Verilator-5 lint-clean at the
  `gcb-wdm-transceiver/sim/lint.sh` bar (new tops added), Cocotb-verified
  (`gcb-wiki/10`). Every capacity / bank / width / depth is a `parameter`, never
  a literal. Must sustain **8 B/cycle sustained writes with zero dropped beats**
  and **zero `sram_valid` low-cycles in `ST_RUN`** across a full pass. No edit to
  any frozen interface.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-012 is Green, delivered through Blue-grade engineering** —
a defensible allocation strategy plus real banked RTL, proven against the DMA
fill rate.

* **Green (target):** a written SRAM allocation / partitioning strategy (bank
  count, word width, depth, how 2x 32 KiB A + 2x 2 MiB B map to macro-sized
  banks, the double-buffer layout) **and** SV-2017 RTL implementing that banking
  with explicit DMA-write and grid-read ports plus their arbitration, passing a
  Cocotb testbench that streams `gcb_tensor_dma_arbiter` at 16 GB/s over at
  least one full pass and asserts **0 dropped write beats** and **0 read stalls
  in `ST_RUN`**, plus a directed same-bank simultaneous-access test with a
  documented resolution.

* **Yellow (reject):** one giant flat `logic` array with no bank / port model
  (does not map to macros — the behavioural model rebuilt), or "proving" the
  fill rate against an always-ready idealised memory instead of a cycle-accurate
  banked one with real read/write contention.

* **Red (reject):** widening or otherwise changing the frozen
  `gcb_tensor_memory_engine` / broadcast-fabric interface to simplify the
  controller, or moving the resident buffer off-chip / folding it into the DMA.

* **Purple / Light-gray:** ECC / scrubbing / redundancy-repair / power-gating on
  the operand SRAM is Purple / a later ticket. Leaving the engine a behavioural
  model (Light-gray) blocks synthesis and every PPA number downstream.

**Explicitly out of scope (separate tickets):**
1. The GDDR7 DMA — `TKT-009` (done).
2. The execution grid / `gcb_tensor_broadcast_fabric` internals.
3. ECC / redundancy / BIST / repair on the SRAM.
4. `dst` / result write-back buffering.
5. OpenROAD PPA, macro-compiler selection, and floorplanning of the banks.

## The "Green" Target

1. A `gcb-wiki` note (new file or a section in an existing memory doc) on the
   on-chip operand SRAM: capacity math (A-band, B-tile, x2 for the ping-pong),
   the bank / port topology chosen, word width vs `VEC_W`, and why.
2. Banked storage RTL — `gcb_tensor_sram_controller` extended, or a new
   `gcb_tensor_operand_sram.sv` it instantiates — with an explicit write port
   (DMA) and read port (grid), macro-friendly bank geometry, and `parameter`s
   for bank count / width / depth.
3. Zero interface change to `gcb_tensor_memory_engine` / `gcb_tensor_broadcast_
   fabric`; the `TKT-009` `dma_tb_top` still elaborates unmodified.
4. Read/write arbitration: the DMA writes the non-resident bank while the grid
   reads the resident bank; the boundary swap loses no in-flight beat; any true
   same-bank collision has a documented, tested resolution (bounded stall or
   none, never corruption).
5. Cocotb TB: drive `gcb_tensor_dma_arbiter -> controller` at sustained 8 B/cyc
   over >= 1 full pass at a small geometry and assert (a) every `{a,b}_wr_valid`
   beat is stored, (b) `sram_valid` never low in `ST_RUN` after the first valid,
   (c) grid-read data matches the closed-form address that was written.
6. A directed test forcing a same-cycle DMA write + grid read to the same bank,
   asserting the documented resolution.
7. `bash sim/lint.sh` exit 0 with the new top(s); Cocotb `TESTS=… PASS=…
   FAIL=0`; wired into `sim/lint.sh` and the guarded `sim/run_tb.sh` stanza.
8. The diff is the new / edited RTL + the TB + the sim-list edits + the wiki
   note — nothing in a frozen module, nothing from the out-of-scope list.

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
