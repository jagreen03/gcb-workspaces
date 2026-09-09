---
id: TKT-003
title: "Widen tensor-memory addressing past 4 GiB with a formal translation layer"
date_created: 2026-09-08
status: done
telemetry_color: green
tags:
  - backlog
  - rtl
  - architecture
  - memory
  - addressing
---

# Objective

> **Mechanism decided by TKT-004 (Green): Base-Pointer Registers with additive
> translation.** Trade study result — BPR ~1.3 kGE, 0 instruction bits, 0
> fragmentation; rejected the lightweight MMU (12-20x area + a page-table
> software contract, for translation generality a 3-region sequential-streaming
> engine never uses) and bare high-bits concatenation (permanent 4 GiB
> alignment / fragmentation tax). This ticket is unblocked and implements that
> single mechanism.

Remove the 4 GiB ceiling on tensor operand addressing. `gcb_opcode_dispatcher.sv`
decodes `ptr_a`, `ptr_b`, `ptr_dst` as **32-bit** fields, and every consumer
downstream (the `gcb_execution_scheduler` latched tags, the TKT-002
`gcb_tensor_command_wiring` sideband, and the future GDDR7 DMA address
generator) inherits that width. 2^32 bytes = 4 GiB total reach for A, B and the
output tensor combined — fundamentally short of the GDDR7 tensor-memory capacity
the accelerator targets (tens of GiB and growing). This ticket defines a clean
architectural mechanism to give the memory engine a large (>= 48-bit) internal
address space **without enlarging the frozen 128-bit Execution Opcode Bus word**.

## Context & Constraints

* **Current State:**
  * `gcb_opcode_dispatcher.sv` bit layout is fixed at 128 bits:
    `[127:120]` opcode, `[119:112]` reserved (8 b, undecoded), `[111:80]`
    `dst_ptr`, `[79:48]` `b_ptr`, `[47:16]` `a_ptr`, `[15:0]` `dim_k`. Three
    32-bit pointers, no room to widen them in place.
  * The pointers are not yet ports on `gcb_tensor_memory_engine` /
    `gcb_tensor_sram_controller` at all — they travel as **opaque 32-bit tags**
    (`gcb_execution_scheduler.latched_ptr_*`, `gcb_tensor_command_wiring`
    sideband) for a DMA address generator that does not exist yet.
  * `gcb_tensor_sram_controller.sv` already documents the offset math that
    address generator must apply to a base:
    `A row r, K-step k of band b  -> matrix row b*GRID_DIM + r, K offset k*K_MAX`;
    `B col c, K-step k of pass p  -> matrix col p*N_TILE  + c, K offset k*K_MAX`.
    Whatever this ticket produces must compose cleanly with that math — it
    supplies the **base**; the controller/DMA supplies the structured offset.
  * `gcb-wiki/08_instruction_set_architecture.md` describes a wider *conceptual*
    256-bit bus with 40-bit pointers; the concrete 128-bit form with 32-bit
    pointers is a documented narrowing. The two need reconciling as part of the
    solution, not left as a silent divergence.
  * The `[119:112]` reserved byte is the only unused headroom in the
    instruction word — 8 bits, nowhere near enough to widen three pointers.
* **Constraint:**
  * The **128-bit instruction format is frozen.** No field may grow, no field
    may be repurposed in a way that changes `gcb_opcode_dispatcher.sv`'s decode
    of `opcode` / `dst_ptr` / `b_ptr` / `a_ptr` / `dim_k`. The `[119:112]`
    reserved byte *may* carry the 2-bit `BASE_SEL_OVERRIDE` field, since that
    does not change the decode of any existing field.
  * Internal address width: **48 bits** (256 TiB) — comfortably past any
    near-term GDDR7 capacity with headroom; datapath extensible to 64 if it
    does not cost meaningful area. State the width in the RTL and here.
  * The base-pointer register file needs a real programming path — an MMIO/CSR
    interface or a dedicated management opcode — that is itself specified and
    verified, not hand-waved.
  * Must not regress TKT-002: `gcb_tensor_command_wiring`'s GEMM -> `cfg_start`
    handshake and its pointer sideband stay behaviourally intact (the sideband
    simply carries wider effective addresses once translated).
  * Verilator 5 lint-clean at the `sim/lint.sh` bar; a directed testbench proves
    translation correctness and the >4 GiB reach.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-003 is Green, delivered through Blue-grade engineering.**
Unlike TKT-002 this is a genuine design effort, not a wiring pass — but the
outcome is still a bounded, in-spec capability, not a new platform. The
mechanism is no longer an open question: TKT-004 evaluated the three candidates
on area, access-pattern fit, and instruction overhead and selected
**Base-Pointer Registers with additive translation**. A full virtual-memory
subsystem (multi-context protection domains, demand paging, per-process page
tables) would be **Purple** and is over-scope; this ticket implements the
minimum formal translation layer that reaches the whole GDDR7 space and no
more.

* **Green (target):** Widen the internal effective-address datapath to 48 bits
  (headroom to 64) and implement the **Base-Pointer Register file** selected by
  TKT-004: architected 48-bit `BASE_A` / `BASE_B` / `BASE_DST` / `BASE_SCRATCH`,
  MMIO/CSR-programmed with defined reset values, and
  `EA[47:0] = BASE[sel] + zero_extend(instr_ptr[31:0])` computed once per GEMM
  at `cfg_start` accept. `sel` is the operand role by default; an optional
  2-bit `BASE_SEL_OVERRIDE` occupies bits inside the existing `[119:112]`
  reserved byte, so the 128-bit format stays byte-for-byte unchanged. The
  translation composes with `gcb_tensor_sram_controller`'s `base + band/pass/
  beat` offset math (the BPR sum *is* that base), and gives `gcb-wiki/08`'s
  40-bit conceptual pointer the exact definition `BASE[role] + offset32`. No
  TLB, no page walker, no page-table software contract.

* **Yellow (reject):** Redefining the 32-bit `ptr_*` as raw block indices /
  fixed-size-region offsets **without** a translation table or base-register
  mechanism — "just multiply the pointer by 64 KiB." It moves the ceiling but
  leaves memory management informal and fragmented: no relocation, no way to
  place regions freely, alignment and aliasing bugs waiting to happen, and every
  later allocator has to reverse-engineer the implied layout.

* **Red (reject):** Breaking the 128-bit instruction decoder to brute-force
  wider pointers into the stream — stealing `dim_k` bits, overloading the opcode
  byte, spanning a pointer across two instruction words, or bumping the word to
  160/256 bits. This violates `gcb_opcode_dispatcher.sv`'s frozen contract and
  gcb-wiki/08, and forces a re-verification of every module that touches the
  Execution Opcode Bus.

* **Purple / Light-gray (not the target):** A general virtual-memory subsystem
  is Purple and out of scope. Accepting the 4 GiB limit (Light-gray) is a
  non-starter — it is incompatible with the stated GDDR7 scale.

**Explicitly out of scope (separate tickets):**
1. The GDDR7 PHY / memory controller / burst scheduler itself.
2. The DMA address-generation engine that turns a translated base plus the
   controller's band/pass/beat offsets into real GDDR7 bursts (TKT-002 and
   `gcb_tensor_sram_controller` already defer this).
3. Caching, prefetch, or write-combining in front of GDDR7.
4. Multi-context isolation / memory protection, unless it falls out of the
   chosen mechanism for free.
5. Any change to `dim_k` semantics or the `K_TOTAL` compile-time parameter.

## The "Green" Target

A "Green" outcome is the Base-Pointer Register file from TKT-004, implemented
such that:

1. The memory engine and its DMA-facing address path operate on **48-bit
   effective addresses** (datapath extensible to 64), sufficient for the
   targeted GDDR7 capacity with headroom; the width is stated in RTL and in the
   design note.
2. The **128-bit Execution Opcode Bus word is byte-for-byte unchanged** and
   `gcb_opcode_dispatcher.sv` is not modified. The optional 2-bit
   `BASE_SEL_OVERRIDE` occupies bits within the existing `[119:112]` reserved
   byte only; `opcode` / `dst_ptr` / `b_ptr` / `a_ptr` / `dim_k` decode exactly
   as today.
3. A **Base-Pointer Register file** is implemented: architected entries
   `BASE_A`, `BASE_B`, `BASE_DST`, `BASE_SCRATCH`, 48-bit, reset 0, programmed
   through a defined MMIO/CSR map entry. The 32-bit `ptr_*` fields are now
   defined as within-region byte offsets.
4. `EA[47:0] = BASE[sel] + zero_extend(instr_ptr[31:0])`, `sel` = operand role
   by default and the `BASE_SEL_OVERRIDE` field when present; the add is
   evaluated once per GEMM at `cfg_start` accept (one time-shared adder). No
   per-beat translation.
5. Translation composes with `gcb_tensor_sram_controller`'s `base + band/pass/
   beat` offset math with **no double translation**: the BPR sum is the base
   the controller / DMA applies structured offsets to.
6. The programming path is **specified and verified**: CSR offsets, reset
   values, and the ordering rule — bases are programmed while the engine is
   idle; a base write concurrent with `busy` is fenced / UB.
7. `gcb-wiki/08` is updated so its 40-bit conceptual pointer is defined as
   `BASE[role] + offset32`.
8. TKT-002's `gcb_tensor_command_wiring` still passes its directed testbench;
   its sideband now carries 48-bit translated effective addresses.
9. Verilator 5 lint-clean at the `sim/lint.sh` bar. A directed testbench:
   program `BASE_A` above 4 GiB, issue a GEMM, observe the effective A / B / DST
   addresses land at `base + offset` beyond the 32-bit range, bit-exact.
10. None of the five out-of-scope items is touched. No TLB, page walker, or
    page-table structure is introduced.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Senior RTL Architect)
* **Commands Run:**
  * `bash sim/lint.sh` — Verilator 5.032 `--lint-only -sv -Wall
    -Wno-DECLFILENAME -Wno-UNUSEDPARAM` across all 22 tops (21 pre-existing +
    `gcb_tensor_address_translation`). Exit 0, no warnings.
  * `verilator --binary --timing -Wall -Wno-DECLFILENAME -Wno-UNUSEDPARAM
    -Wno-GENUNNAMED -Wno-WIDTHEXPAND -Wno-BLKSEQ -Wno-UNUSEDSIGNAL
    +define+SIMULATION --top-module tb_tensor_address_translation
    rtl/gcb_tensor_address_translation.sv tb/tb_tensor_address_translation.sv`
    → build exit 0.
  * `./sim/sim_out/obj_tb_tensor_address_translation/Vtb_tensor_address_translation`
    → `=== tb_tensor_address_translation: ALL CHECKS PASS ===` (25/25).
  * Regression: rebuilt + ran `tb_tensor_command_wiring` (TKT-002) → still
    `ALL CHECKS PASS`.
* **Artifacts Touched:**
  * `rtl/gcb_tensor_address_translation.sv` — NEW. Base-Pointer Register file.
    * `base_q[4]` x 48-bit: `BASE_A` (0), `BASE_B` (1), `BASE_DST` (2),
      `BASE_SCRATCH` (3). Reset 0, so out of reset `EA == zero_extend(offset)`
      and the block is transparent.
    * `EA[47:0] = base_q[sel] + {16'b0, off}` — three parallel 48-bit adders
      (deliberate: once-per-GEMM, not timing critical; ~2 extra adders < 1 kGE
      vs. TKT-004's one-time-shared estimate, in exchange for no sequencer).
      Registered on `xlate_valid` (= the `gemm_start` / `cfg_start` pulse);
      `ea_valid` follows one cycle later, `ea_*` hold between GEMMs.
    * `sel` = operand role by default (A→0, B→1, DST→2); the reserved byte
      `instruction_word[119:112]`, passed in as `base_sel_ovr`, optionally
      overrides: `[0]` OVR_EN, `[2:1]/[4:3]/[6:5]` SEL_A/SEL_B/SEL_DST,
      `[7]` reserved. 128-bit instruction word byte-for-byte unchanged;
      `gcb_opcode_dispatcher.sv` not touched.
    * 32-bit CSR/MMIO port: LO/HI word pairs at `0x00..0x1C`, `0x20` RO STATUS
      (`ovf_a/ovf_b/ovf_dst`, sticky `wr_while_busy`). Readback path included.
    * `engine_busy` interlock: base writes are dropped while high and flagged
      sticky — makes TKT-003/004's "program bases only while idle" ordering
      rule defined-safe rather than UB.
    * 48-bit carry-out is captured per operand (`STATUS.ovf_*`); EA wraps mod
      2^48.
    * Composition: `ea_a/ea_b/ea_dst` are exactly the *base* that
      `gcb_tensor_sram_controller`'s documented `absolute = base + structured
      (band/pass/beat)` math consumes — this block never applies the structured
      offset, so no double translation. Verified by check 9.
  * `tb/tb_tensor_address_translation.sv` — NEW. 25 directed checks: reset
    transparency; `ea_valid` one cycle wide; BASE_A programmed above 4 GiB →
    EA beyond the 32-bit range, bit-exact; distinct BASE_B/BASE_DST with the
    default role map; reserved-byte override incl. BASE_SCRATCH; CSR readback;
    `engine_busy` write-drop + sticky STATUS; 48-bit carry-out → `ovf_a`;
    `EA == BASE + zext(instr offset)` composing with a downstream structured
    offset.
  * `sim/lint.sh` — added `rtl/gcb_tensor_address_translation.sv` to the RTL
    list and `gcb_tensor_address_translation` to the lint-top loop.
  * `sim/run_tb.sh` — added the RTL entry and
    `run_one tb_tensor_address_translation tb/tb_tensor_address_translation.sv`.
  * NOT touched: `gcb_opcode_dispatcher.sv`, `gcb_tensor_memory_engine.sv`,
    `gcb_tensor_sram_controller.sv`.

### Integration (follow-on, completed same session)

* **Commands Run:**
  * `bash sim/lint.sh` → exit 0, no warnings, 23 tops
    (adds `gcb_tensor_command_wiring` re-linted with the embedded BPR).
  * Rebuilt + ran `tb_tensor_command_wiring` → `ALL CHECKS PASS` (20 checks,
    incl. the new BPR-sideband checks).
  * Reran `tb_tensor_address_translation` → `ALL CHECKS PASS` (25/25), no
    regression.
* **Artifacts Touched:**
  * `rtl/gcb_tensor_command_wiring.sv` — now instantiates
    `gcb_tensor_address_translation` (`u_bpr`). `u_cmd`'s decoded
    `ptr_a/ptr_b/ptr_dst` feed `u_bpr` as 32-bit offsets `off_a/off_b/off_dst`;
    `xlate_valid = gemm_accept` (the combinational accept), so `u_bpr` registers
    `ea_*` on the same edge `cfg_start_q` rises — `ea_valid` is **coincident
    with `gemm_start`**. The 32-bit `ptr_*` outputs are replaced by
    `ea_valid` + `ea_a/ea_b/ea_dst [47:0]`; `dim_k` still passes straight
    through. A CSR/MMIO port (`csr_we/csr_re/csr_addr/csr_wdata/csr_rdata`) is
    exposed at the wrapper boundary and wired directly to `u_bpr`;
    `u_bpr.engine_busy` is tied to the engine `busy` so base writes are
    interlocked during a run. `base_sel_ovr` is tied to `8'h00` (default role
    map) — the dispatcher does not forward `instruction_word[119:112]`;
    exposing that byte to exercise the override is a small separate change,
    noted below.
  * `tb/tb_tensor_command_wiring.sv` — updated for the new 48-bit sideband:
    GEMM #1/#2 checks now assert `ea_* == zero_extend(ptr)` (bases 0) and
    `ea_valid` coincident with `gemm_start`; a new block programs
    `BASE_A = 0x0006_0000_0000` over the wrapper CSR port while idle, issues a
    GEMM, and verifies `ea_a == BASE_A + zero_extend(offset)` on the sideband,
    beyond the 32-bit range.
  * `gcb-wiki/08_instruction_set_architecture.md` — the "Pointer range: 4 GiB
    per pointer … Not resolved here" section now carries a **Resolved
    (TKT-003 / TKT-004 — Base-Pointer Registers)** paragraph: `a_ptr/b_ptr/
    dst_ptr` are 32-bit within-region offsets, `EA_48 = BASE[role] +
    zero_extend(ptr_32)`, and the 256-bit conceptual layout's 40-bit pointer is
    that same `BASE[role] + offset32`.
  * `sim/lint.sh` / `sim/run_tb.sh` — RTL list already carried the new module
    from the first pass; no further edit needed for integration.
* **Remaining (small, not blocking):** forward `instruction_word[119:112]` as a
  decoded output of `gcb_opcode_dispatcher` (or the vortex wrapper) so the
  per-operand base-select **override** can be exercised end-to-end. The BPR
  block already implements and unit-tests the override; only the plumbing of
  the reserved byte to `u_bpr.base_sel_ovr` remains, and it needs a dispatcher
  output which every prior ticket deliberately deferred.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** BPR translation layer implemented per TKT-004, clean.
`gcb_tensor_address_translation.sv` — four architected 48-bit base registers
(`BASE_A/B/DST/SCRATCH`), reset 0, CSR/MMIO-programmed as LO/HI word pairs with
readback; `EA[47:0] = BASE[sel] + zero_extend(instr_ptr[31:0])` computed once
per GEMM on the `cfg_start` strobe; `sel` = operand role by default with an
optional override packed entirely inside the existing `[119:112]` reserved
byte, so the 128-bit instruction word and `gcb_opcode_dispatcher.sv` are
untouched. Composes with `gcb_tensor_sram_controller`'s `base + structured
offset` math with no double translation (verified). `engine_busy` interlock
turns the "program bases while idle" rule into defined-safe behaviour;
per-operand 48-bit carry-out is flagged in STATUS.

**Integrated:** `gcb_tensor_command_wiring.sv` now embeds the BPR
(`u_bpr`); the decoder's `ptr_*` feed it as 32-bit offsets, `xlate_valid =
gemm_accept` so `ea_valid` is coincident with `gemm_start`, and the sideband
now carries `ea_a/ea_b/ea_dst [47:0]` plus a boundary CSR/MMIO port (with
`engine_busy` tied to the engine `busy`). `gcb-wiki/08` carries the
"Resolved — Base-Pointer Registers" paragraph reconciling the 40-bit
conceptual pointer as `BASE[role] + offset32`.

Verilator 5 lint-clean across all 23 tops; `tb_tensor_address_translation`
25/25; `tb_tensor_command_wiring` 20/20 (incl. new BPR-sideband checks). Diff
surface: 2 new RTL/TB files, `gcb_tensor_command_wiring.sv` + its TB updated,
one `gcb-wiki/08` paragraph, two sim-list lines. Deviations, both minor and
deliberate: three parallel adders vs. TKT-004's one time-shared estimate
(< 1 kGE); the `[119:112]` base-select **override** is tied to the default role
map in the wrapper pending a `gcb_opcode_dispatcher` output for the reserved
byte (the BPR itself implements and unit-tests the override).
