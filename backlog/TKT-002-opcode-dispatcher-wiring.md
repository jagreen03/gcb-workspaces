---
id: TKT-002
title: "Wire opcode-dispatcher decoded control signals into the tensor memory engine control ports"
date_created: 2026-09-08
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - control-plane
  - integration
---

# Objective

Close the open loop in the execution control plane. `gcb_opcode_dispatcher.sv`
(via its `gcb_vortex_command_processor.sv` wrapper) already turns a 128-bit
Execution Opcode Bus word into discrete, independently-verified control signals
— `command_valid`, `opcode`, `ptr_a`, `ptr_b`, `ptr_dst`, `dim_k`, with a real
`command_ready` backpressure input. `gcb_tensor_memory_engine.sv` already exposes
its run control — `cfg_start` (kick one full `M_TOTAL x N_TOTAL x K_TOTAL` pass
set), `busy`, `done`. **The wiring between the two does not exist.** No module
instantiates both; the decoded command interface currently terminates in mid-air.
This ticket creates the structural glue that routes the dispatcher's decoded
signals into the memory engine's control ports and closes the `command_ready`
handshake back from engine status.

## Context & Constraints

* **Current State:**
  * `gcb_vortex_command_processor` outputs `command_valid` / `opcode[7:0]`
    (`OP_GEMM=0x01`, `OP_SOFTMAX=0x02`, `OP_SCALE_DIAG=0x03`) /
    `ptr_a[31:0]` / `ptr_b[31:0]` / `ptr_dst[31:0]` / `dim_k[15:0]`, and takes
    `command_ready` as its one backpressure input. The dispatcher holds exactly
    one decoded word and stalls correctly when `command_ready` is low.
  * `gcb_tensor_memory_engine` takes `cfg_start` (one-cycle pulse) and emits
    `busy` + a one-cycle `done`. Its A/B host write channels
    (`a_load_req/a_load_band/a_load_done/a_wr_*`, `b_load_req/b_load_pass/
    b_load_done/b_wr_*`) are the DMA fill path and are **not** part of this
    ticket.
  * Nothing drives `cfg_start` from `command_valid`; nothing derives
    `command_ready` from `busy`/`done`; `ptr_a/ptr_b/ptr_dst/dim_k` are not
    presented to anything. The control plane is an open loop.
  * The connection itself is already specified architecture
    (gcb-wiki/05_photonic_memory_dataflow.md sec. 9, gcb-wiki/08_instruction_
    set_architecture.md). This ticket realizes it; it does not design it.
* **Constraint:** Pure structural / minimal-handshake wiring only. Permitted new
  logic is limited to: qualifying `command_valid` by `opcode == OP_GEMM`,
  generating the one-cycle `cfg_start` pulse on command accept, and gating
  `command_ready` so a new command is accepted only when the engine is idle
  (`!busy` and not mid-`done`). No datapath, no address translation, no new
  memory, no FSM beyond that accept/pulse/idle handshake. Decoded pointer/dim
  fields are passed through unchanged. No edit to `gcb_opcode_dispatcher.sv` or
  `gcb_vortex_command_processor.sv`. Verilator 5 lint-clean, matching the repo's
  existing `sim/lint.sh` bar.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-002 is purely Green.** There is no menu of options to weigh
here — the architecture already dictates the connection, both endpoints are
frozen and verified, and the work is bounded: map the existing decoded signals
exactly onto the memory engine's existing control ports, close the one
handshake, expose the pointer/dim sideband unchanged. A Green execution does
**only** that and stops. The other colors are named here only as anti-patterns
to reject mid-execution:

* **Green (target):** New file `gcb_tensor_command_wiring.sv` (or equivalently
  named) instantiating `gcb_vortex_command_processor` + `gcb_tensor_memory_engine`
  and binding: `command_valid & (opcode == OP_GEMM)` on accept -> one-cycle
  `cfg_start`; `command_ready = !busy` (single outstanding command);
  `ptr_a/ptr_b/ptr_dst/dim_k` -> wrapper output sideband for the (separate) DMA
  engine; `busy`/`done` -> wrapper status outputs. Nothing else changes.

* **Yellow (reject):** Tying `cfg_start` to a constant or a bare
  `command_valid` level (not a pulse), or hardcoding `command_ready = 1'b1` to
  "make it elaborate" — silently drops every command issued while the engine is
  busy. Unblocks a smoke test, corrupts the control contract.

* **Red (reject):** Bolting `ptr_*` -> band/pass/beat address translation, a
  >4 GiB paging scheme, or an opcode router for `OP_SOFTMAX` / `OP_SCALE_DIAG`
  into this glue module. Each is a separate ticket; folding them in here creates
  a multi-concern module that every later ticket has to unpick.

* **Purple / Blue (not in play):** No new platform capability and no
  architecture change — the dataflow doc already froze this interface. Treat any
  urge to "improve the architecture while we're in here" as scope creep.

* **Light-gray (current state):** Leaving the loop open. Zero capability; the
  decoded control plane stays inert.

**Explicitly out of scope (separate tickets):**
1. The >4 GiB addressing limitation — `ptr_a/ptr_b/ptr_dst` are 32-bit (4 GiB
   reach). Not solved, not worked around, here.
2. Refactoring `gcb_opcode_dispatcher.sv` — its handshake is already correct and
   independently verified.
3. Routing `OP_SOFTMAX` / `OP_SCALE_DIAG` to their execution engines — this
   ticket wires the `OP_GEMM` -> tensor-memory-engine path only.
4. Reconciling the concrete 128-bit encoding with gcb-wiki/08's 256-bit
   conceptual bus; reconciling `dim_k[15:0]` against the engine's compile-time
   `K_TOTAL` parameter.
5. The DMA / GDDR7 engine that fills the A/B host write channels, and any
   merge of those two channels into a generic port.

## The "Green" Target

A "Green" outcome is a single new structural wiring module such that:

1. `gcb_vortex_command_processor` and `gcb_tensor_memory_engine` are instantiated
   together for the first time, with every decoded control signal mapped
   **1:1** to an existing memory-engine control port or a pass-through wrapper
   output — no renamed, reinterpreted, or invented signals.
2. A decoded `OP_GEMM` command accepted at the wrapper boundary produces exactly
   one `cfg_start` pulse into the engine.
3. `command_ready` is driven from engine status so that at most one GEMM pass
   set is outstanding; the dispatcher backpressures cleanly while `busy` is high,
   with no dropped or duplicated commands.
4. `ptr_a`, `ptr_b`, `ptr_dst`, `dim_k` appear unchanged as wrapper outputs for
   the downstream DMA engine; the wrapper adds no interpretation of them.
5. `busy` and `done` are exposed as wrapper status outputs.
6. No change to `gcb_opcode_dispatcher.sv`, `gcb_vortex_command_processor.sv`, or
   `gcb_tensor_memory_engine.sv`. Verilator 5 lint-clean. A directed testbench
   shows: issue GEMM -> single `cfg_start` -> `busy` asserts -> second command
   held off -> `done` -> next command accepted.
7. None of the five out-of-scope items above is touched. The diff is the new
   wiring module plus its testbench and sim-list entry, nothing more.

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
