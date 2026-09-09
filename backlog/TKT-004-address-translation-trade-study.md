---
id: TKT-004
title: "Address-translation mechanism trade study for tensor-memory addressing"
date_created: 2026-09-08
status: done
telemetry_color: green
tags:
  - backlog
  - rtl
  - architecture
  - memory
  - research
---

# Objective

Decide the address-translation mechanism that TKT-003 will implement. TKT-003
(>4 GiB tensor-memory addressing) carries three candidate mechanisms —
Base-Pointer Registers, High-bits companion + PRELOAD, Lightweight MMU / page
table — and, as originally written, asked the implementer (or the Product Owner)
to choose. That choice is an architecture decision with quantifiable trade-offs,
not an implementer's preference; it must be settled by analysis before TKT-003
can start. This ticket is that analysis. Deliverable: **one** selected mechanism
with quantified rationale across (1) silicon area, (2) fit to the GDDR7
tensor-streaming access pattern, (3) instruction-stream overhead, plus an
explicit "revisit if" trigger. TKT-003 consumes the result and TKT-003's
option list collapses to the single choice.

## Context & Constraints

* **Current State:**
  * TKT-003 fixes the target envelope: >= 48-bit internal effective addresses;
    the 128-bit Execution Opcode Bus word frozen; translation must compose with
    `gcb_tensor_sram_controller.sv`'s documented `base + band/pass/beat` offset
    math; `gcb-wiki/08`'s 40-bit conceptual pointer to be reconciled.
  * The three candidates are already sketched in TKT-003's Green bullet. This
    ticket scores those three; it does not invent new ones.
  * Access-pattern facts (from `gcb_tensor_sram_controller.sv` and
    `gcb-wiki/05_photonic_memory_dataflow.md`): weight-stationary /
    output-stationary tiling; per GEMM **exactly three** operand tensors
    (A row-bands, B column-tiles, DST); each a large contiguous or
    regularly-strided region walked as long sequential DMA bursts from one
    region base; base addresses reprogrammed **at most once per GEMM**
    (thousands of cycles apart); **no** pointer chasing, gather/scatter,
    data-dependent addressing, or sparsity.
* **Constraint:** Analysis only — no RTL, no schematic. Output is a decision
  recorded in this ticket's Execution Log and a one-line result in Telemetry.
  The decision must be **singular** (one mechanism), **quantified** (area as an
  order-of-magnitude gate-equivalent figure, instruction bits, walk/setup
  latency), and **falsifiable** (state the workload change that reopens it). It
  may not relax any TKT-003 constraint.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The deliverable of TKT-004 is a decision, so Green is defined by decisiveness
and rigor, not by code.**

* **Green (target):** A single recommended mechanism, chosen on quantified
  area / access-pattern / instruction-overhead grounds, stated decisively
  enough that TKT-003's option list collapses to it with no further
  deliberation, and carrying an explicit "revisit if" trigger.

* **Yellow (reject):** "It depends" / "here are the trade-offs, you pick" /
  carrying two candidates forward. Punting the decision is exactly the
  anti-pattern that spawned this ticket; a trade study that does not choose has
  failed its one job.

* **Red (reject):** Defaulting to the most general mechanism (the MMU) for
  future-proofing without weighing its area cost and its mismatch to a
  three-region sequential-streaming pattern — gold-plating dressed as caution.

* **Blue:** the analytical rigor itself — real gate-count estimates, real
  latency numbers, the access pattern actually characterised rather than
  assumed.

* **Purple / Light-gray:** not in play. This is neither a platform bet nor
  deferrable; TKT-003 is blocked on it.

## The "Green" Target

1. Exactly one mechanism chosen.
2. **Area:** order-of-magnitude gate-equivalent estimate for each candidate,
   dominant structures named (registers, adder, TLB CAM, page-walk FSM, GDDR7
   read client).
3. **Access-pattern fit:** each candidate scored against the characterised
   pattern (~3 live regions, coarse sequential bursts, per-GEMM base changes,
   no sparsity).
4. **Instruction-stream overhead:** bits consumed in the 128-bit word (steady
   state and setup), plus any software-managed off-chip structure the mechanism
   implies.
5. The choice composes with `gcb_tensor_sram_controller`'s `base + offset` math
   and lets `gcb-wiki/08`'s 40-bit conceptual pointer be expressed exactly.
6. A "revisit if" trigger naming the concrete future workload characteristic
   that would reopen the decision.
7. TKT-003's Green Target is rewritten to the single chosen architecture;
   TKT-003's blocker on TKT-004 is removed; this ticket's Telemetry is Green.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Senior Architect)
* **Commands Run:** none — desk analysis against `gcb_tensor_sram_controller.sv`,
  `gcb_opcode_dispatcher.sv`, `gcb-wiki/05_photonic_memory_dataflow.md`,
  `gcb-wiki/08_instruction_set_architecture.md`, and TKT-002 / TKT-003.
* **Artifacts Touched:** this ticket (the decision); TKT-003 (blocker removed,
  Green Target rewritten to the chosen mechanism).

### 1. Access pattern — the deciding factor

The tensor memory engine is a weight-/output-stationary **streaming** datapath.
Per GEMM:

* exactly three operand regions — A (row-bands), B (column-tiles), DST (output);
* each large and contiguous / regularly strided; the DMA address generator walks
  it as long sequential bursts, every beat address = one region base + the
  structured `band*GRID_DIM+r`, `pass*N_TILE+c`, `k*K_MAX` offsets the controller
  already documents;
* base addresses reprogrammed at most once per GEMM — thousands of cycles apart;
* no pointer chasing, no gather/scatter, no data-dependent addressing, no
  sparsity.

So there are **~3 concurrently-live translations and a near-zero translation
rate**. Any mechanism whose cost scales with translation *entries* or
translation *rate* (a TLB, a page walker) is buying generality this workload
never exercises.

### 2. Silicon area (order of magnitude, 5 nm-class)

| Mechanism | Dominant structures | Estimate |
|---|---|---|
| **Base-Pointer Registers** | 4 x 48-bit base regs (~1.0 kGE) + one 48-bit adder, time-shared, evaluated once per GEMM (~0.25 kGE) + CSR write decode (~0.1 kGE) | **~1.3 kGE** |
| **High-bits + PRELOAD** | 1-3 x 16-32-bit hi regs (~0.2-0.6 kGE) + concat (0) or small adder | **~0.3-0.7 kGE** (only in the 1-register form, which has the worst placement constraints, see 3) |
| **Lightweight MMU** | 16-entry fully-associative TLB storage (~5.5 kGE) + 16-way CAM compare (~2-3 kGE) + HW page-walk FSM + PTE-fetch datapath + fault path (~5-15 kGE) + a new read client on the GDDR7 arbiter | **~15-25 kGE floor** (12-20x BPR) + a large verification surface (walk states, fault semantics, TLB coherence) |

### 3. Placement / fragmentation

* **BPR (additive):** EA = `base + zext(offset32)`. Regions may sit at any
  4 KiB-aligned address, any size, packed densely; a single tensor larger than
  4 GiB is representable (the offset is a within-region displacement, the base
  carries the rest).
* **High-bits (concatenative):** EA = `{hi, offset32}`. Every region is forced
  to 4 GiB alignment and <= 4 GiB size. Two 100 MiB tensors cannot share a
  4 GiB granule without wasting it; a 6 GiB tensor is unrepresentable. This is
  precisely the *fragmented memory management* TKT-003 flags as Yellow, reached
  by a different route. Making high-bits **additive and per-role** is
  definitionally BPR; making it 3-register is BPR with a worse name. CSR-vs-
  PRELOAD is only a delivery detail for how the base word is written.
* **MMU:** arbitrary placement, no fragmentation — but that benefit is
  **redundant** with BPR-additive for a 3-region workload, and is bought with
  Section 2's area plus a DRAM-resident page-table software contract.

### 4. Instruction-stream overhead (128-bit word)

* **BPR:** 0 bits in the common case — operand role (A / B / DST) implicitly
  selects the base. An optional 2-bit `BASE_SEL_OVERRIDE` fits entirely inside
  the existing `[119:112]` reserved byte, so the frozen format is untouched
  even with it. Base programming is 3 CSR writes (or one `SET_BASE` management
  op) per locality window of many GEMMs — amortised to ~0.
* **High-bits + PRELOAD:** 0 instruction bits, one PRELOAD per window — same
  amortised cost, but with Section 3's alignment tax baked in permanently.
* **MMU:** 0 instruction bits, but the overhead **relocates off-chip** into a
  page table the runtime must build and maintain, plus a page-walk stall
  (1-4 dependent DRAM reads, ~hundreds of ns each) on every region-boundary TLB
  miss. Rare for streaming, but real latency and real software complexity added
  to every remap.

### 5. Composition with existing math and gcb-wiki/08

BPR-additive is a strict superset of the controller's own model: the controller
already assumes `absolute = base + structured_offset`. BPR simply **is** that
base, now 48-bit and relocatable. `gcb-wiki/08`'s 40-bit conceptual pointer
becomes exactly `BASE[role] + offset32` — the concrete 128-bit encoding carries
`offset32`, the role (or the override field) selects `BASE`. Nothing in doc 08
changes semantically; it gains the definition it was missing.

### Decision

**Base-Pointer Registers with additive translation.**

* Architected bank: `BASE_A`, `BASE_B`, `BASE_DST`, `BASE_SCRATCH`, **48-bit**
  each (datapath headroom to 64), reset 0, MMIO/CSR-programmed.
* `EA[47:0] = BASE[sel] + zero_extend(instr_ptr[31:0])`; one adder, evaluated at
  `cfg_start` accept (once per GEMM).
* `sel` defaults to operand role; an optional 2-bit override lives inside the
  existing `[119:112]` reserved byte — 128-bit format byte-for-byte unchanged.
* Ordering rule: program bases while the engine is idle; a base write concurrent
  with `busy` is fenced / UB, to be spec'd in the CSR map.

Rationale in one line: the workload has three coarse, sequential, rarely
re-translated regions; **four registers and one adder** (~1.3 kGE, zero
instruction bits, zero fragmentation) cover it completely, while the MMU costs
**12-20x the area** plus a page-table software contract to buy fine-grained,
high-rate, sparse-translation generality this engine will never use, and bare
high-bits concatenation trades BPR's one adder for a permanent 4 GiB
alignment / fragmentation tax.

### Revisit if

The tensor memory engine gains a workload with **data-dependent or scattered
operand addressing** — gather/scatter, sparse-tensor or MoE expert-routing where
the live-region count per instruction window exceeds the base-register file, or
demand-paged operands larger than physical GDDR7. At that point a TLB + page
walker becomes justified, **layered in front of** the BPR-translated address, not
replacing the base registers.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** Trade study executed and decided. **Base-Pointer Registers
with additive translation** (`BASE_A` / `BASE_B` / `BASE_DST` / `BASE_SCRATCH`,
48-bit, CSR-programmed; `EA = BASE[role] + zext(ptr32)`; optional 2-bit selector
inside the existing reserved byte; ~1.3 kGE; 0 instruction bits; 0
fragmentation). Rejected: **lightweight MMU** (12-20x area + page-table software
contract + walk latency, for translation generality a 3-region
sequential-streaming engine never uses); **high-bits concatenation** (permanent
4 GiB alignment / fragmentation tax, and its additive per-role form is just
BPR). Revisit trigger: data-dependent / scattered / demand-paged operand
addressing. TKT-003 unblocked; its Green Target rewritten to BPR.
