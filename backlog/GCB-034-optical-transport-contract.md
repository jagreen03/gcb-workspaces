---
id: GCB-034
title: "Optical Transport Contract — what the compute fabric actually needs moved, derived from the ASAP7 physical measurements, before any WDM/QAM physics"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - epic-tkt-019
  - optical-wdm
  - transport
  - orange-team
  - architecture
  - contract
---

# Objective

**Story 1 of EPIC `TKT-019` (Optical WDM Transport), authored under the
Orange-Team *method* ([[TKT-000]] — a way of working, "measure first, derive the
requirement, *then* design the physics"; not a PBG grade).**

The compute fabric (EPIC `TKT-017`) is proven bit-exact end-to-end at
4096 MAC/advancing-cycle with 0 SRAM read stalls ([[TKT-025]]), and its
`gcb_max_reduce` critical primitive has been through the ASAP7 / OpenROAD
physical flow six times ([[GCB-027]] → [[GCB-032]]). We now have real numbers
for the data that moves through and *out of* a compute tile.

**Before this Epic specifies a single WDM channel count, QAM order, wavelength
plan, laser budget, or SerDes rate, it must state — from the measurements —
exactly what the optical layer is being asked to carry.** This ticket is that
statement. It designs no optical physics. It answers four foundational
questions and surfaces the decisions that block the rest of the Epic.

## Measurement basis — what we physically know

*We do not have silicon. We have an ASAP7 / OpenROAD educational physical-design
measurement.* Every figure below traces to a checked-in artifact.

| fact | value | source |
|---|---|---|
| On-die grid | `GRID_DIM = 16`, `K_MAX = 16` → **256 INT4 MAC PEs** | `gcb-wiki/06` §8; `gcb_mac_tile_array` (TKT-022) |
| Operand format | INT4 × INT4 → INT32 accumulate (`ACC_W = 32`) | TKT-022; INT32 derivation in `gcb_mac_tile_array.sv` |
| Electrical operand-feed bus | one advancing beat = `2·GRID_DIM·VEC_W = 2·16·64 = 2048 b = **256 B**` (16 A-lanes + 16 B-lanes × `VEC_W = K_MAX·OPND_W = 64 b`) | `gcb_operand_stage` (TKT-024); PPA_burndown.md |
| Peak compute rate | **4096 MAC / advancing cycle** ( = 256 PE × 16 `K_MAX`), exactly the arithmetic peak | `test_compute_e2e.py` (TKT-025) |
| Operand-feed stalls | **0** SRAM read stalls across every advancing cycle — deterministic, non-data-dependent feed | TKT-025 |
| INT32 partial-sum tile (`acc_tile`, per `d_last`) | `GRID_M·GRID_N·ACC_W = 256·32 = 8192 b = **1024 B**`, row-major | `gcb_mac_tile_array.sv` |
| Requantized output tile (`q_tile`) | `256 · OUT_W` → **128 B** at `OUT_W = 4` (INT4) / **256 B** at `OUT_W = 8` | `gcb_tile_requantize` (TKT-023) |
| Block-float scale (`q_scale`) | `SCALE_MODE` PER_TILE → 1 × `EXP_W(6)` b; PER_ROW / PER_COL → 16 × 6 b = **96 b** | TKT-023 |
| K reduction per output tile | full `K_TOTAL`: `K_STEPS = K_TOTAL / K_MAX` advancing cycles of accumulation before a tile is emitted | TKT-022/025 |
| `gcb-wiki/06` production geometry | `M_TOTAL = 4096`, `N_TOTAL = 28672`, `K_TOTAL = 8192`, `N_TILE = 1024` → `K_STEPS = 512` | `gcb-wiki/06` |
| `gcb_max_reduce` @ 1 ns (`REG_STAGES=2`, mid-tree, no retiming) | **WNS 0.00 ps**, fmax 1.519 GHz, 372 flops, **38 max-slew DRVs** | [[GCB-032]] `report.json` |

### The physical observation this Epic must respect

[[GCB-032]] left **38 max-slew DRVs** at the `gcb_max_reduce` mid-tree register
banks — a **successful falsification** of the "0 DRVs" prediction, and an
**unresolved physical observation**. A slew-repair re-measure follow-on
**remains open** (see `GCB-032-FINDINGS.md`); this contract does **not** assume
it will be resolved and **does not change its disposition**.
Its meaning for transport: **a wide bank of registers driven in parallel at
1 GHz, feeding logic downstream, is already at the edge of the max-transition
limit on this node.** Any optical-boundary datapath that latches a wide payload
(the 8192-b `acc_tile`, or the 2048-b operand beat) into a parallel register
farm every cycle will hit the *same* wall, harder. **The contract must therefore
prefer a narrow, already-reduced, low-cadence payload over a wide, high-rate
one** — and this ticket's job is to say which payload that is.

## Foundational questions — the data-movement contract

The deliverable is a **falsifiable data-movement contract**: concrete numbers a
later story can contradict with a measurement. For each question — the answer
the measurements support, and the decision that is *not yet* ours to make.

### Q1 — What exact data leaves a compute tile?

**Candidates, by pipeline position:** raw operands (INT4, off the SRAM read
port) · INT32 partial sums (`acc_tile`, 1024 B/tile) · **requantized results**
(`q_tile` + `q_scale`, ~140 B/tile at INT4) · softmax-normalised activations
(post `gcb_inline_vector_unit`).

**Measurement-supported answer:** the **requantized output tile** — INT4/INT8
`q_tile` plus its block-float `q_scale`. It is the only representation that is
(a) *fully K-reduced* (a `K_TOTAL:1` contraction already done electrically),
(b) *precision-compressed* `32 b → 4/8 b` (8:1 or 4:1), and (c) produced by an
existing, verified block that exists **precisely to shrink this crossing**
([[TKT-023]]). Sending `acc_tile` optically would be 8× the payload at the same
cadence and would re-create the GCB-032 wide-bank problem at the transmit
serializer.

**Open decision D1:** does the optical boundary sit **after `gcb_tile_requantize`**
(an INT4 activation tile crosses to the next layer's matmul) **or after
`gcb_inline_vector_unit`** (a normalised softmax row crosses)? The softmax
pre-pass (`x − max(x)`) is a *within-row* electrical reduction; whether its
output or its input crosses the fibre is an Epic-level dataflow choice, not a
measurement.

> **D1 — PROVISIONAL: POST-REQUANTIZATION.** The Architect has provisionally
> set the optical boundary **immediately after `gcb_tile_requantize`** — the
> INT4/INT8 `q_tile` + `q_scale` is what crosses. This is a **testable
> hypothesis, not a fact**: it holds only if EPIC `TKT-019`'s falsification
> pass confirms the payload size, cadence and downstream numeric consequences,
> and it does **not** close this ticket. Status stays `open | pending`.

### Q2 — Width and physical cycle cadence of the payload at 1 GHz?

**Measurement-supported answer** (production geometry, `K_TOTAL = 8192` →
`K_STEPS = 512`, clock = 1.0 ns from the GCB-027…032 SDC):

| payload | size / tile | emitted every | rate-averaged | instantaneous |
|---|---:|---:|---:|---:|
| `q_tile` INT4 + `q_scale` PER_ROW | ≈ **140 B** | **512 cycles = 512 ns** | **≈ 0.27 GB/s** | 140 B in ~1–5 cycles, then idle ~507 |
| `q_tile` INT8 + scale | ≈ 260 B | 512 ns | ≈ 0.51 GB/s | — |
| `acc_tile` INT32 (rejected) | 1024 B | 512 ns | ≈ 2.0 GB/s | 1024 B/cycle burst |
| electrical operand beat (for contrast) | 256 B | **1 cycle** | **256 GB/s** | continuous |

So the optical crossing is **~1000× lower bandwidth than the electrical operand
feed**, because the K-reduction and the requantise both happen before the
boundary. One INT4 tile is `256 · OUT_W = 1024 b`; the wire-format adds
`q_scale` (≤ 96 b) and framing.

*The ~1000× figure — and the ~15 000 : 1 compute-to-transport ratio in Q4 — is
the surface reading of a **Purple-artifact candidate hypothesis** (see the PBG
Evaluation section). The hypothesis is **not** "~1000× less bandwidth" per se; it
is that **the electrical compute domain constitutes an enormous compression
boundary — local high-precision K-reduction (INT4×INT4 → INT32 over the whole
`K_TOTAL`) plus block-float requantization (`32b → 4/8b`) — so the optical
transport can be designed to operate on a dramatically smaller representation
than the fabric moves internally.** The ~1000× is arithmetic on the cited
geometry and an assumed **1 GHz** clock (inherited from the deliberately-
aggressive GCB-027…032 SDC; `docs/PPA_burndown.md` also references a "2 GHz
design point"); the clock and the provisional D1 / D4 must survive `TKT-019`
falsification before the hypothesis is a realized platform property rather than
a derived one.*

**Open decision D2:** `OUT_W = 4` vs `8` — sets the payload (140 B vs 260 B) and
the numerical headroom the next layer sees; downstream it sets the minimum QAM
order / optical SNR the physics stories must hit. A trade study, not a
measurement (tracked separately as the `OUTPUT`/precision study).

### Q3 — Is the transport continuous or bursty?

**Measurement-supported answer:** **deterministically periodic, not
data-dependent bursty.** The compute feed has **0 stalls** ([[TKT-025]]), so a
tile is finished every `K_STEPS` cycles on a fixed schedule regardless of data.
At *sub-tile* granularity it is a micro-burst (the whole `q_tile` is registered
in ≈ 1 cycle after the block-float pass, then the link is quiet for
`K_STEPS − 1`). A **shallow output FIFO (1–2 tiles ≈ 280 B)** absorbs the
micro-burst and presents the optical layer a continuous ≈ 0.27 GB/s stream with
a 512-cycle period and near-zero jitter.

**Open decision D3:** transaction granularity — **one 16×16 tile per optical
transaction** (140 B, 512 ns period), **sub-tile row/column streaming**
(≈ 9 B every 32 cycles — smaller framing overhead ratio is worse), or
**super-tile aggregation** across `N_SUBTILES` (e.g. 20 tiles → 2.8 kB every
10 240 cycles — amortises framing, adds latency and buffer). Framing/FEC
overhead vs latency vs SRAM buffer is the trade; the measurement only fixes the
*native* granularity (one tile / `K_STEPS`).

### Q4 — How much reduction is electrical before the optical boundary, and what does one optical transaction correspond to computationally?

**Measurement-supported answer:** **the entire K dimension reduces
electrically.** One INT4 optical tile transaction is:

* `GRID_M · GRID_N · K_TOTAL = 16 · 16 · 8192 = **2 097 152 INT4 MACs**`
  (production geometry) — or `16·16·256 = 65 536` MACs in the [[TKT-025]] test
  geometry — collapsed into `1024 b` of INT4 + a shared exponent.
* a `K_TOTAL : 1` spatial contraction **and** a `32 b : 4 b` precision
  contraction, i.e. the optical layer never sees a partial sum, only a final,
  requantised result.
* the arithmetic behind `≈ 0.27 GB/s` of fibre traffic is `≈ 4.1 TMAC/s`
  (`4096 MAC/cycle` × 1 GHz) of on-die compute — a **~15 000 : 1**
  compute-to-transport ratio at INT4. The electrical fabric does essentially
  all the work; the optical layer moves the residue between fabric tiles /
  layers / nodes.

**Open decision D4:** is `K_TOTAL` *always* fully reduced on one node, or is
there a **K-split across nodes** where partial `acc_tile`s (INT32, 1024 B, and
at a *higher* cadence than `K_STEPS`) cross optically to be summed remotely? A
K-split trades the ~1000× transport saving for latency/wafer-yield flexibility
and re-introduces the wide-payload problem the physical observation above warns
about. This is the single biggest dataflow fork in the Epic and needs an
explicit Architect decision.

> **D4 — PROVISIONAL: FULL-K LOCAL REDUCTION.** The Architect has provisionally
> set the whole `K_TOTAL` contraction to complete **electrically on one node** —
> the optical layer never carries an INT32 partial sum. This is a **testable
> hypothesis, not a fact**: EPIC `TKT-019` must falsify it against the
> counterfactual (Alternative B: K-split + partial sums → substantially wider
> transport), and it does **not** close this ticket. It also *accepts a
> horizontal-partitioning constraint* that `GCB-034-LOOK-AROUND.md` examines
> directly. Status stays `open | pending`.

## The "Green" Target — acceptance

`GCB-034` is complete when the ticket states, as checked-in prose + a table:

1. **The payload** — `q_tile` (INT4/INT8) + `q_scale`, chosen per D1/D2, with
   the exact bit layout of one wire-format transaction (data + scale + framing
   placeholder).
2. **The cadence** — one transaction per `K_STEPS` cycles; `K_STEPS` as a
   function of `K_TOTAL / K_MAX`; the 1 GHz period; the rate-averaged and
   instantaneous bandwidth for the production and test geometries.
3. **The continuity model** — periodic + shallow-FIFO-smoothed; the FIFO depth
   (tiles) and its byte cost; the jitter bound.
4. **The reduction statement** — "`K_TOTAL:1` + `32b:4b` electrically; one
   optical transaction = `256·K_TOTAL` MACs → `1024 b`"; the
   compute-to-transport ratio.
5. **Decisions D1–D4** — D1 / D4 recorded as *provisional* (POST-REQUANTIZATION
   / FULL-K LOCAL REDUCTION), D2 / D3 open; each logged with the `TKT-019` test
   that would falsify or confirm it.

**This ticket stays `open | pending` until EPIC `TKT-019` runs the falsification
pass and the provisional decisions either survive or are replaced.** Recording a
provisional decision establishes the testable hypothesis — it does not close the
contract.

Every WDM / QAM / wavelength / laser / SerDes parameter is **out of scope** —
those are Story 2+ of this Epic and must cite this contract's numbers as their
input.

### Architectural Decisions Required (D1–D4)

**The contract cannot close until all four are decided *and* the decisions
survive EPIC `TKT-019`'s falsification pass.** Each is a dataflow choice, not a
measurement; each has a stated test that *would* validate it. The Architect has
**provisionally** set D1 and D4 (below) — provisional decisions establish the
**testable hypothesis** this contract embodies; they do **not** move the ticket
off `open | pending`.

| id | decision | provisional resolution | still-open alternative | falsified / confirmed by |
|---|---|---|---|---|
| **D1** | **Optical boundary placement** | **POST-REQUANTIZATION** — the INT4/INT8 `q_tile` + `q_scale` crosses | boundary after `gcb_inline_vector_unit` (normalised softmax row crosses) | `TKT-019` measured payload size incl. scale/metadata; downstream numeric consequences of a requantised hand-off |
| **D2** | **Payload precision `OUT_W`** | *open* | INT4 (≈ 140 B/tile) vs INT8 (≈ 260 B/tile) | `TKT-019` accuracy sweep of the downstream layer INT4 vs INT8; feeds the minimum QAM order / optical SNR the physics stories must hit |
| **D3** | **Transaction granularity** | *open* | one 16×16 tile / `K_STEPS` · sub-tile streaming · super-tile aggregation across `N_SUBTILES` | `TKT-019` framing/FEC-overhead vs added latency vs SRAM output-buffer-bytes trade table |
| **D4** | **K-reduction split** | **FULL-K LOCAL REDUCTION** — the whole `K_TOTAL` contraction completes electrically on one node; optical carries only final results | K split across nodes (INT32 `acc_tile`s, 1024 B, cross optically at a *higher* cadence to be summed remotely — **Alternative B**) | `TKT-019` counterfactual test against Alternative B: transport width/cadence, remote-accumulate latency, and the horizontal-partitioning constraint it imposes (`GCB-034-LOOK-AROUND.md`) |

**D1 and D4 are load-bearing for the Purple hypothesis.** The electrical-domain
compression boundary (§ "Purple candidate", below) is *only physically realized*
if the provisional resolutions hold:

* **D1 = post-requantization** — so what crosses is the `K_TOTAL:1`-reduced,
  `32b→4b`-compressed `q_tile`, not a wider representation; **and**
* **D4 = full-K local** — so the optical layer never carries an INT32 partial
  sum at all.

If **D1 is falsified** (the boundary lands elsewhere) the payload identity (Q1)
and size (Q2) change. If **D4 is falsified** (Alternative B wins), the optical
layer carries 1024 B `acc_tile`s at a higher cadence and the compression
collapses toward the ~2 GB/s partial-sum rate — the platform trades the
compression for latency / yield / horizontal-scaling flexibility. Neither
provisional decision is a realized property of the platform until `TKT-019`
closes.

*(D2 and D3 shape the payload and framing but do not, by themselves, negate the
order-of-magnitude compression; they are second-order to D1 / D4 and remain
fully open.)*

## AI Orchestration Priorities (PBG Evaluation)

**Target: Green, at Blue-grade rigor.** Spec (X, Green↔Red): the contract
completely and correctly states what the optical layer must carry — payload,
width, cadence, continuity, reduction — in numbers that each trace to a
checked-in artifact. Quality (Y, Blue↔Yellow): every figure cites its source;
no WDM / QAM / wavelength / laser / SerDes parameter is pre-committed. A
**Purple (Z, Purple↔Light-gray)** result is *possible* but **is not claimed on
drafting** — see below.

* **Green / Blue (target):** the four foundational questions answered with
  numbers traceable to checked-in artifacts (`gcb-wiki/06`,
  TKT-022/023/024/025, `eda/GCB-032/report.json`); D1–D4 listed as decisions
  with their settling measurement; the GCB-032 max-slew observation carried
  forward as a transport constraint without changing its disposition. Nothing
  in the contract requires an optical-physics choice to be made first.
* **Purple (Z) — candidate hypothesis, pending `TKT-019` falsification (not
  graded here):** the discovery is **not** "~1000× less bandwidth"; it is that
  **the electrical compute domain is an enormous compression boundary — local
  high-precision K-reduction over the whole `K_TOTAL` plus block-float
  requantization (`32b → 4/8b`) — allowing the optical transport to operate on a
  dramatically smaller representation than the fabric moves internally.** If the
  provisional D1 (post-requantization) and D4 (full-K local) survive
  falsification, this reframes the entire optical Epic: the WDM PHY is sized by
  *reduced results*, not by the operand bus. Supporting sub-observations, each
  its own falsifiable claim: (a) `gcb_tile_requantize` (TKT-023, specified for
  on-die numeric-range management) doubling as the optical-boundary compression
  stage; (b) the K-reduction schedule *being* the optical cadence for free, so
  no rate-matching / backpressure machinery is needed at the boundary
  (0 SRAM read stalls, [[TKT-025]]). See `GCB-034-LOOK-AROUND.md` for the
  constraints this attractive compression may cause us to accept silently.
* **Yellow (reject):** picking `OUT_W`, tile granularity, or the K-split
  *silently* to make a downstream WDM number look good; quoting a bandwidth
  without stating the geometry (`K_TOTAL`) and clock it assumes.
* **Red (reject):** specifying channel count / QAM order / wavelength plan in
  this ticket; asserting "continuous 256 GB/s optical" by carrying the operand
  bus across the fibre (re-creates the GCB-032 wide-bank wall at the
  serializer); treating the 38 max-slew DRVs as resolved or resolvable here.
* **Light-gray:** leaving the payload identity ("operands? partials? results?")
  implicit — the entire reason this ticket exists.

**Out of scope (later Epic):** a fabric-wide optical NoC with arbitrary
tile-to-tile routing; this contract is point-to-point layer / K hand-off only.

### Methodology note (not a grade)

This ticket is authored under the Orange-Team physical-reality-first doctrine
([[TKT-000]]). Per TKT-000, **Orange / PBG-O is a working-doctrine *flag*,
orthogonal to the R³ PBG axes** — it is *not* a colour on the vector, does not
change `gcb-wiki/09`'s maths, and does **not** substitute for Specification,
Quality, or Emergence. Whether this contract has been adequately confronted with
physical reality (its PBG-O disposition) is assessed at architectural review,
**alongside — never instead of** — the R³ grade. No PBG vector and no PBG-O
disposition is assigned by the act of drafting this document.

### Toolchain / scope

No RTL, no cocotb, no P&R run. Doc-only, in `gcb-workspaces`. The compute-side
figures are read from existing TKT-017 artifacts and `eda/GCB-032/`; the
RTL Baseline (`gcb-wdm-transceiver`) is not touched.

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated at architectural review — not on drafting.)*
**Final State:** `open | pending` — awaiting architectural review; no PBG vector
assigned by the act of drafting.
**PBG-O disposition:** to be assessed at review, separately from and alongside
the R³ grade (never in place of it).
**Vector Summary:** —
