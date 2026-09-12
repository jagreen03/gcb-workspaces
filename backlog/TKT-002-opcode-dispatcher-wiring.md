---
id: TKT-002
title: "Wire opcode-dispatcher decoded control signals into the tensor memory engine control ports"
date_created: 2026-09-08
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 0.5
  emergence: 0.0
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

## CORRECTION (2026-09-12, later same day) — the testbench claim below was wrong

**The "What was genuinely missing" claim two paragraphs down is false and
is left in place, struck through in spirit but not in fact, so this
record is honest about the error rather than quietly edited away.**
`tb/tb_tensor_command_wiring.sv` already existed, already covered this
exact module comprehensively — non-GEMM filtering, the `gemm_start` pulse,
BPR translation **including the >32-bit reach** (which the new cocotb test
below did NOT check), the override field reaching `BASE_SCRATCH`, and
multi-pulse counting — and, confirmed by actually building and running it
just now, **still passes (`ALL CHECKS PASS`) against the current RTL.**

The search that produced the "no dedicated functional testbench existed"
claim only checked `sim/cocotb/*.py` — it never checked this repository's
**separate, older `tb/` + `sim/run_tb.sh` convention**, which is where
`gcb_tensor_command_wiring.sv` (and `gcb_tensor_address_translation.sv`,
and most of the control-plane/compute RTL) actually carries its test
coverage. This is a real process error, not a harmless one: it produced a
false "gap closed" narrative, committed to git, in both repos.

**Disposition:** the new cocotb test (`test_tensor_command_wiring.py`)
itself is correct and still passes — it is not reverted, since deleting
working, harmless, already-pushed test code over a documentation error
would be more disruptive than leaving it. But it is **not** a gap closure;
it is a redundant, alternate-convention duplicate of coverage that already
existed. The telemetry above is revised down (quality 1.0 → 0.5) to
reflect that this ticket's own record was wrong until this correction, not
because the RTL or either test is actually broken. Going forward: this
repository requires checking **both** `sim/cocotb/` and `tb/`+
`sim/run_tb.sh` before any future ticket claims "no test exists" for an
RTL module here.

## Resolution (2026-09-12) — status corrected, gap was stale not real

**The structural glue this ticket asked for was already built** —
`gcb_tensor_command_wiring.sv` (header: "TKT-002 + TKT-003 integration")
instantiates `gcb_vortex_command_processor` + `gcb_tensor_memory_engine` +
`gcb_tensor_address_translation` and implements exactly the bounded
handshake this ticket's own Constraint specified: `command_valid &
(opcode==OP_GEMM)` accepted → one `cfg_start` pulse; `command_ready` gated
on engine idle via the documented `start_pending_q` one-flop race-closer
(`busy` registers one cycle after `cfg_start`, so gating on `!busy` alone
would leave a window for a second command to be falsely accepted); pointer/
dim fields pass through unchanged, routed through the BPR address
translator per TKT-003. **This ticket's own frontmatter was simply never
updated when that work landed** — confirmed by direct inspection
(`grep` for the module's name across every `gcb-wiki` architecture doc and
the RTL tree) before writing this, not assumed from the README's own
(also stale) "done" claim.

**What was genuinely missing, and is now closed**: no dedicated functional
testbench existed for `gcb_tensor_command_wiring.sv` — confirmed by `grep`
across every `sim/cocotb/*.py` file, zero matches, before this session.
Built `gcb_tensor_command_wiring_tb_top.sv` + `test_tensor_command_wiring.py`
+ `Makefile.tensor_command_wiring` (minimal geometry:
`M_TOTAL=N_TOTAL=K_TOTAL=N_TILE=GRID_DIM=K_MAX=16`, the smallest
single-band/single-k-step/single-pass config, so a real `busy`→`done`
cycle completes in the fewest cycles — this test does not re-verify
`gcb_tensor_memory_engine`'s own GEMM correctness, already proven in
TKT-025, only the wiring's own contract). Two tests, not an adversarial
suite — deliberately scoped to the module's own documented contract:

1. `test_gemm_dispatch_address_translation_and_reissue` — two back-to-back
   OP_GEMM commands (no reset between). Confirms: exactly one `gemm_start`
   pulse per command, `ea_valid` coincident, `ea_a/b/dst` = programmed BPR
   base + `ptr_a/b/dst` (TKT-003 translation verified, not assumed),
   `dim_k` unchanged, `gemm_start` drops the very next cycle, `busy`
   asserts and `done` eventually fires, `busy` clears after `done`, and —
   the real point of testing a SECOND round with no manual reset — the
   race-closing `command_ready` gate genuinely reopens on its own once the
   first command completes.
2. `test_non_gemm_opcode_silently_filtered` — a non-`OP_GEMM` opcode
   produces zero effect (no `gemm_start`, no `busy`) over 100 cycles,
   matching the module's own documented scope boundary.

**`TESTS=2 PASS=2`, first real run — no RTL change was needed; the
existing wiring's own documented behavior held exactly as claimed.** No
determinism re-run performed: this test has no randomization (fully
deterministic stimulus), so a repeat run carries no additional
information, unlike the seeded-random suites elsewhere in this program.

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
  * ~~Nothing drives `cfg_start` from `command_valid`...~~ **superseded —
    see Resolution above.**
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

**The target for TKT-002 is purely Green — met.** The architecture dictated
the connection, both endpoints were frozen and verified, the work was
bounded, and it is now also functionally tested, not just lint-clean and
structurally present.

## Telemetry & Evaluation

**Final State:** `done` | **Color:** `green`. Spec 1.0 (the Constraint's
exact accept/pulse/idle handshake, no more, no less, confirmed present).
Quality 1.0 (now functionally verified, not merely lint-clean; the
pre-existing "done" claim in `gcb-workspaces/README.md` was corrected
rather than left stale). Emergence 0.0 (no new architectural surface —
realizes an already-specified connection, per this ticket's own Objective).
