---
id: TKT-006
title: "Plumb the dispatcher [119:112] reserved byte to the BPR base-select override"
date_created: 2026-09-08
status: done
telemetry_color: green
tags:
  - backlog
  - rtl
  - integration
  - control-plane
---

# Objective

Unlock the Base-Pointer Register (BPR) per-operand base-select **override**.
TKT-003 landed `gcb_tensor_address_translation.sv` with a working override —
`OVR_EN` plus `SEL_A` / `SEL_B` / `SEL_DST` packed in the instruction word's
`[119:112]` reserved byte — and unit-tested it in
`tb_tensor_address_translation`. But `gcb_tensor_command_wiring.sv` ties
`u_bpr.base_sel_ovr` to `8'h00`, because `gcb_opcode_dispatcher.sv` does not
decode `[119:112]` (it is marked `_unused_ok`). So only the default role map
(A→BASE_A, B→BASE_B, DST→BASE_DST) is reachable end-to-end; `BASE_SCRATCH` and
cross-operand base sharing are dead code.

This ticket exposes `instruction_word[119:112]` as a decoded dispatcher output
and routes it through `gcb_vortex_command_processor.sv` to
`gcb_tensor_command_wiring.sv`'s `u_bpr.base_sel_ovr`, replacing the tie-off.

## Context & Constraints

* **Current State:**
  * `gcb_opcode_dispatcher.sv` registers `decoded_opcode` / `ptr_a` / `ptr_b` /
    `ptr_dst` / `dim_k` on the one accept edge (`instruction_valid &&
    instruction_ready`). `instruction_word[119:112]` is not decoded — a
    `wire _unused_ok = &{1'b1, instruction_word[119:112]}` guard marks it
    intentionally dropped.
  * `gcb_vortex_command_processor.sv` is a pure-wiring wrapper (IF queue →
    dispatcher); it exposes the decoded bus and would need to forward one more
    field.
  * `gcb_tensor_command_wiring.sv` (post-TKT-003) instantiates the BPR as
    `u_bpr` with `.base_sel_ovr (8'h00)` and a comment noting this is pending a
    dispatcher output.
  * BPR reserved-byte layout (already implemented): `[0]` OVR_EN,
    `[2:1]` SEL_A, `[4:3]` SEL_B, `[6:5]` SEL_DST, `[7]` reserved.
* **Constraint:** Additive plumbing only. The decode of `opcode` / `ptr_a` /
  `ptr_b` / `ptr_dst` / `dim_k`, and the `instruction_ready` / `decoded_valid`
  handshake, are byte-for-byte unchanged. The 128-bit instruction word is
  unchanged. Permitted new logic: registering one 8-bit field in the dispatcher
  on the existing accept edge, and forwarding it through one wrapper. Verilator
  5 lint-clean at the `sim/lint.sh` bar.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-006 is purely Green** — a bounded plumbing pass, no design
decision. One new registered output on the dispatcher, one forwarding hop
through the vortex wrapper, one connection in the command wiring, the `8'h00`
tie-off removed, and the override exercised in a testbench.

* **Green (target):** `base_sel_ovr` added as a registered dispatcher output
  (from `instruction_word[119:112]`, same accept edge, reset 0), forwarded
  verbatim by `gcb_vortex_command_processor`, connected to `u_bpr.base_sel_ovr`
  in `gcb_tensor_command_wiring`. `_unused_ok` guard for those bits removed.
  Existing outputs and handshake untouched.

* **Yellow (reject):** Decoding `[119:112]` combinationally off
  `instruction_word` (or `host_data`, or a hierarchical reference) inside the
  wiring module instead of adding it to the dispatcher's *registered* decode.
  That misaligns the override with the registered `ptr_*` and re-introduces the
  "which cycle is this field valid" ambiguity the dispatcher's one-deep
  register stage exists to remove.

* **Red (reject):** Repurposing bits of an already-decoded field
  (`opcode` / `dim_k` / a pointer) to carry the selector, or widening the
  instruction word past 128 bits.

* **Purple / Light-gray:** not in play. No new capability is designed here (the
  BPR override already exists); leaving the tie-off in place (Light-gray) keeps
  `BASE_SCRATCH` unreachable and is the gap this ticket closes.

## The "Green" Target

1. `gcb_opcode_dispatcher.sv` gains `output logic [7:0] base_sel_ovr`,
   registered from `instruction_word[119:112]` on the same
   `instruction_valid && instruction_ready` edge as the other decoded fields,
   reset to `'0`. No change to any existing output, to `instruction_ready`, or
   to `decoded_valid` timing. The `_unused_ok` guard for `[119:112]` is removed.
2. `gcb_vortex_command_processor.sv` gains a matching
   `output logic [7:0] base_sel_ovr` wired straight from the dispatcher
   instance — no logic added.
3. `gcb_tensor_command_wiring.sv` connects that output to
   `u_bpr.base_sel_ovr`; the `8'h00` tie-off is removed and the header note
   updated.
4. `tb_opcode_dispatcher.sv` and `tb_vortex_command_processor.sv` connect the
   new port and assert it equals `instruction_word[119:112]` after a decode.
5. `tb_tensor_command_wiring.sv` gains an override check: program `BASE_SCRATCH`
   to a distinct value, push a GEMM whose `[119:112]` byte selects
   `BASE_SCRATCH` for one or more operands, and verify the sideband `ea_*` use
   the overridden base.
6. `bash sim/lint.sh` exits 0 across all tops; every affected testbench passes.
7. The 128-bit instruction word and the decode of `opcode` / `ptr_a` /
   `ptr_b` / `ptr_dst` / `dim_k` are unchanged.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Senior RTL Architect, hardware-silicon workspace)
* **Commands Run:**
  * `bash sim/lint.sh` — Verilator 5.032 lint across all 23 tops → exit 0, no
    warnings.
  * Built + ran the four affected testbenches:
    `tb_opcode_dispatcher`, `tb_vortex_command_processor`,
    `tb_tensor_command_wiring`, `tb_tensor_address_translation` (regression) —
    all `ALL CHECKS PASS`.
* **Artifacts Touched:**
  * `rtl/gcb_opcode_dispatcher.sv` — added `output logic [7:0] base_sel_ovr`,
    registered from `instruction_word[119:112]` on the existing
    `instruction_valid && instruction_ready` accept edge (reset `'0`). Removed
    the `_unused_ok` guard for those bits; updated the bit-layout header.
    `decoded_opcode` / `ptr_a` / `ptr_b` / `ptr_dst` / `dim_k` decode and the
    `instruction_ready` / `decoded_valid` handshake are byte-for-byte unchanged.
  * `rtl/gcb_vortex_command_processor.sv` — added a matching
    `output logic [7:0] base_sel_ovr`, wired straight from `u_dispatcher`. No
    logic added (still a pure-wiring wrapper).
  * `rtl/gcb_tensor_command_wiring.sv` — new internal `cmd_base_sel_ovr` wire;
    `u_cmd.base_sel_ovr → cmd_base_sel_ovr → u_bpr.base_sel_ovr`. The
    `.base_sel_ovr (8'h00)` tie-off is gone; header note updated. `xlate_valid
    = gemm_accept` already aligns the override byte with `off_*`.
  * `tb/tb_opcode_dispatcher.sv` — connected the new port; every
    `send_and_check` now asserts `base_sel_ovr === reserved`; section 5 renamed
    from "reserved-bits canary" to the `base_sel_ovr` decode check
    (`[119:112]=0xFF` lands on `base_sel_ovr`, does not leak into
    opcode/ptr/dim); the held-outputs check includes `base_sel_ovr`.
  * `tb/tb_vortex_command_processor.sv` — `instr_t` gains `reserved`;
    `pack_instruction` sets `w[119:112]`; `random_instr` randomises it; the
    golden-queue bit-exact compare now includes `base_sel_ovr`.
  * `tb/tb_tensor_command_wiring.sv` — added `pack_i_ovr(...)` (explicit
    `[119:112]` byte) and a new block: program `BASE_SCRATCH` distinct, push a
    GEMM with `[119:112] = 0x7F` (OVR_EN + all three SEL = 3), verify
    `ea_a / ea_b / ea_dst` all use `BASE_SCRATCH` — proving the byte reaches
    `u_bpr.base_sel_ovr` through dispatcher → vortex → wiring. 26 checks total.
  * `sim/lint.sh` / `sim/run_tb.sh` — no change needed (all modules and TBs
    already listed).
* **Verification:**
  * `sim/lint.sh` → exit 0, 23 tops, no warnings.
  * `tb_opcode_dispatcher` → `ALL CHECKS PASS` (incl. `base_sel_ovr == 0xA5 /
    0x5A / 0x00 / 0xFF`, no leak into other fields).
  * `tb_vortex_command_processor` → `ALL CHECKS PASS` (golden-queue compare
    with `reserved` included).
  * `tb_tensor_command_wiring` → `ALL CHECKS PASS`, 26 checks — `override: ea_a
    / ea_b / ea_dst uses BASE_SCRATCH` all pass.
  * `tb_tensor_address_translation` → `ALL CHECKS PASS` (25/25, no regression).

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** Pure plumbing, done clean. `gcb_opcode_dispatcher` gains
one registered output `base_sel_ovr` from `instruction_word[119:112]` on the
existing accept edge — every other decoded field and the valid/ready handshake
unchanged, `_unused_ok` guard removed. `gcb_vortex_command_processor` forwards
it verbatim (no logic). `gcb_tensor_command_wiring` connects it to
`u_bpr.base_sel_ovr`, retiring the `8'h00` tie-off, so the BPR per-operand
base-select override is reachable end-to-end. Three testbenches extended:
dispatcher asserts the exact `[119:112]` decode with no leak, vortex adds
`reserved` to its bit-exact golden compare, command-wiring proves a
`[119:112] = 0x7F` GEMM routes all three effective addresses through
`BASE_SCRATCH`. `sim/lint.sh` exit 0 across all 23 tops; all four affected
testbenches `ALL CHECKS PASS`. The 128-bit instruction word is unchanged.
