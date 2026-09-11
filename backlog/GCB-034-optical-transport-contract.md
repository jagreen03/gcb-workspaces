---
id: GCB-034
title: "Optical Transport Contract — what the compute fabric actually needs moved, derived from the ASAP7 physical measurements, before any WDM/QAM physics"
date_created: 2026-09-10
closed: 2026-09-10
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.7
# pbg_o is a TKT-000 working-doctrine FLAG, orthogonal to and separate from the
# R³ telemetry vector above — it does not substitute for any axis.
pbg_o: orange
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

> **CLOSED 2026-09-10 (PM + Architect).** The four provisional decisions were
> subjected to the [[TKT-019]] Falsification Test (V1–V5, tickets
> [[GCB-035]] / [[GCB-036]] / [[GCB-037]] / [[GCB-038]]). **The contract
> survived — as a *dual-regime* contract, not a single global one.** The
> ratified contract is in § "The Ratified Dual-Regime Contract"; the D1–D4
> resolutions and their test verdicts are in the decisions table; the PBG
> grade and PBG-O disposition are in § "Telemetry & Evaluation". The Q1–Q4
> prose below is the derivation record, kept as written.

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

> **D1 — RATIFIED: POST-REQUANTIZATION.** ([[TKT-019]] V1 → CONTRACT HOLDS,
> [[GCB-035]].) The optical boundary sits **immediately after
> `gcb_tile_requantize`**; the `q_tile` + `q_scale` crosses. Measured actual
> transaction ≈ 143 B (scale + header add ~2 % to the idealised 140 B) —
> not a regime change. The boundary-after-`gcb_inline_vector_unit` alternative
> is not adopted.

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

> **D2 — RATIFIED: INT8, `SCALE_MODE = PER_ROW`, `ROUND = RNE`.** ([[TKT-019]]
> V3 → CONTRACT FAILS for INT4, [[GCB-036]].) INT4 block FP has only ~18 dB
> (~8×) usable in-block dynamic range; against a 25 dB SQNR budget it needs
> `r_max ≤ 1.56×` while real transformer activation blocks span 4–50×. Payload
> → ≈ 271 B, line rate → ≈ 4.74 Gbps true — still a single ≤ 10 G lane, ~0 dB
> optical-SNR penalty. INT4 remains an opt-in for QAT / verified-narrow-range
> models. Settling validation (real activation trace → `q_clip` rate, per-block
> `r_max`, end-to-end accuracy) is a `TKT-019.x` task against the ratified
> INT8 default.

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

> **D3 — RATIFIED: per-tile for `K ≥ ~2 k`; super-tile aggregation for
> small-`K` layers.** ([[TKT-019]] V2, [[GCB-035]] / [[GCB-036]].) Line rate is
> inversely proportional to `K_TOTAL`; at the FFN anchor (`K = 8192`, 512 ns
> window) per-tile is fine, but small-`K` layers (attention `Q·Kᵀ`,
> `head_dim = 128` → 8 ns window) drive the per-tile line rate up 64× — past
> any plausible per-λ rate. Those layers aggregate. The exact `K` threshold and
> super-tile depth are a `TKT-019.x` framing/latency/buffer trade table.

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

> **D4 — RATIFIED AS A SELECTABLE MODE (not a global law).** ([[TKT-019]] V5 →
> CONTRACT FAILS as a global law / HOLDS as a workload-class mode,
> [[GCB-038]]; [[GCB-034-LOOK-AROUND]].)
> * **Mode A — full-K local reduction** (optical carries only requantised
>   results): the default for **FFN-class throughput** — `K_TOTAL ≤ ~45 k`
>   (per-node SRAM residency ceiling at 8 MiB / `N_SUBTILES = 20`), batched
>   (M ≥ 16), context ≤ ~32 k. Keeps data + N-tensor + pipeline + expert
>   parallelism.
> * **Mode B — K-split + INT32 partial sums** (Alternative B; optical carries
>   1024 B `acc_tile`s to a remote accumulator): **mandatory** for
>   **long-context attention `A·V`** (`seq_len ≥ ~45 k` in the K role) and
>   **latency-critical batch-1 decode** (full-K-local has no K-parallel recovery
>   lever; ≈ 1.84 ms / 70B FFN block / token). Recovers K-tensor and
>   attention-sequence parallelism.
> * A **mode bit in the transaction header** selects the regime per matmul.
> * The dual-regime PHY ([[GCB-037]] V4) is provisioned for Mode B's
>   wavelength count (≈ 60 λ at the P = 4 accumulator), not Mode A's (~1 λ).

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
5. **Decisions D1–D4** — each logged with the `TKT-019` test that would falsify
   or confirm it. **All five ran; the contract survived as a dual-regime
   contract; D1–D4 are RATIFIED (§ decisions table / § Ratified Dual-Regime
   Contract).**

**Acceptance met and CLOSED 2026-09-10.** The falsification pass (V1–V5) ran;
the provisional decisions either survived (D1) or were replaced with a
measured resolution (D2 INT4→INT8, D3 per-tile→conditional aggregation, D4
global→mode-selected). Recording a provisional decision established the testable
hypothesis; the Falsification Test either confirmed it or corrected it, and the
result is the ratified contract.

Every WDM / QAM / wavelength / laser / SerDes parameter is **out of scope** —
those are Story 2+ of this Epic and must cite this contract's numbers as their
input.

### Architectural Decisions D1–D4 — RESOLVED (TKT-019 Falsification Test)

| id | decision | **RATIFIED resolution** | test verdict |
|---|---|---|---|
| **D1** | Optical boundary placement | **POST-REQUANTIZATION** — the `q_tile` + `q_scale` crosses; measured ≈ 143 B | [[GCB-035]] V1 → **HOLDS** (~2 % over 140 B) |
| **D2** | Payload precision `OUT_W` | **INT8**, `SCALE_MODE = PER_ROW`, `ROUND = RNE`; payload ≈ 271 B, ≈ 4.74 Gbps true. INT4 opt-in for QAT / verified-narrow-range | [[GCB-036]] V3 → INT4 **FAILS** the 25 dB SQNR budget (`r_max ≤ 1.56×` vs real 4–50×) → INT8 |
| **D3** | Transaction granularity | **per-tile for `K ≥ ~2 k`; super-tile aggregation for small-`K` layers** (line rate ∝ 1/`K_TOTAL`) | [[GCB-035]] V2 → **HOLDS** for FFN; small-`K` blow-up (64× at `head_dim`) → conditional aggregation |
| **D4** | K-reduction split | **SELECTABLE MODE.** Mode A full-K local (FFN throughput, `K ≤ ~45 k`, batched, ctx ≤ ~32 k); Mode B K-split + INT32 partials (long-context attention `A·V`, latency-critical batch-1 decode). Header mode bit | [[GCB-038]] V5 → **FAILS as a global law**, **HOLDS as a workload-class mode** |

**The Purple hypothesis survived** (§ "Telemetry & Evaluation"). It is realized
in **Mode A**: D1 = post-requantization + D4 Mode A → what crosses is the
`K_TOTAL:1`-reduced, `32b→8b`-compressed `q_tile` (≈ 432× below the internal
operand bus, [[GCB-036]]), on **one wavelength**, link closing with +2.5–8 dB
margin ([[GCB-037]] V4). In **Mode B** the compression is ~114× and the link
needs ≈ 4·P … 60 λ — the platform trades compression for K-parallelism and
single-request latency, exactly as [[GCB-034-LOOK-AROUND]] anticipated.

**Deferred to `TKT-019.x` build sub-stories** (validation against a ratified
contract, not blockers): the D2 settling measurement (real activation trace →
`q_clip` rate, per-block `r_max`, end-to-end accuracy); the D3 threshold / depth
trade table; the D4 mode-select policy and the remote-accumulate protocol; and
the [[GCB-037]] link budget parameterised with the real PIC process.

## The Ratified Dual-Regime Contract

**One optical transaction carries one 16×16 output tile's worth of data across
the fabric boundary, on a mode selected per matmul by a header bit.**

| property | **Mode A — FFN throughput** | **Mode B — long-context / low-latency** |
|---|---|---|
| what crosses (D1) | `q_tile` + `q_scale` **after `gcb_tile_requantize`** | INT32 `acc_tile` **partial sums**, K-split across `P` nodes → remote accumulate → requantize on the accumulator node |
| precision (D2) | **INT8** mantissa, `PER_ROW` block-float exponent (`EXP_W = 6`), `ROUND = RNE` | INT32 raw partials; final hand-off after remote accumulate is **INT8** |
| payload | **≈ 271 B** (`q_tile` 2048 b + `q_scale` 96 b + `q_clip` + header) | **≈ 1027 B** per K-partner (`acc_tile` 8192 b + header) |
| granularity (D3) | **per-tile** for `K ≥ ~2 k`; **super-tile aggregation** for small-`K` (attention `Q·Kᵀ`) | per-tile per K-partner |
| cadence | one txn / `K_STEPS = K_TOTAL/K_MAX` cycles (512 ns at the FFN anchor, 1 GHz); **deterministically periodic** (0 SRAM read stalls) | one partial / `(K_STEPS / P)` cycles per K-partner |
| continuity | periodic + 1–2 tile output FIFO (≈ 540 B at INT8) → continuous, near-zero jitter | periodic per link; the accumulator sees `P` partials per `K_STEPS` |
| true line rate (64b/66b + KP4, 12 % provision) | **≈ 4.74 Gbps** | **≈ 17.9 · P Gbps** per link; **≈ 17.9 · P² Gbps** at the accumulator |
| optical PHY (D4 → [[GCB-037]] V4) | **1 λ**, 2-PAM/QPSK + KP4, **link closes** +2.5–8 dB margin | **≈ 4·P λ** per link → **≈ 60 λ** at the P = 4 accumulator (~a C-band comb) |
| compression vs the 2048 Gbps internal operand bus | **≈ 432×** | ≈ 114× (P = 1) |
| reduction per transaction | `GRID_M·GRID_N·K_TOTAL` MACs → one tile; **`K_TOTAL:1` spatial + `32b:8b` precision**, all electrical | each K-partner: `GRID_M·GRID_N·(K_TOTAL/P)` MACs → one INT32 partial |
| applicability | `K_TOTAL ≤ ~45 k`, batched (M ≥ 16), context ≤ ~32 k. Keeps data + N-tensor + pipeline + expert parallelism | long-context attention `A·V` (`seq ≥ ~45 k`), latency-critical batch-1 decode. Recovers K-tensor + attention-sequence parallelism |

**Invariants (both modes):** `ROUND = RNE`; **KP4 FEC mandatory** (6.05 dB — the
INT8 link does not close without it); **2-PAM/QPSK only** (PAM4+ breaks
closure); the compute fabric is **never back-pressured** — the FIFO + FEC absorb
the micro-burst and the line rate is sized to the sustained periodic cadence.

**The dual-regime PHY is provisioned for Mode B** (≈ 60 λ, ≈ 60× ring
thermal-tuning power); Mode A uses a small fraction of it.

## AI Orchestration Priorities (PBG Evaluation)

**Achieved: `T = (spec +1.0, quality +1.0, emergence +0.7)`, `telemetry_color:
green`** (argmax\|axis\| — spec = quality, tie-break spec → +X → Green). Detail
in § "Telemetry & Evaluation".

* **Spec +1.0 (Green):** the contract completely and correctly states what the
  optical layer must carry — payload, width, cadence, continuity, reduction —
  every figure traceable to a checked-in artifact, and it does so *before* any
  optical-physics choice. It also delivered the *correct* answer to a question
  that turned out to branch: a **dual-regime** contract, not the single global
  one the drafting scope assumed. D1–D4 ratified against a 5-part falsification
  test; the parts that failed (INT4, D4-as-global-law) were corrected with a
  measured resolution, not waived.
* **Quality +1.0 (Blue):** measure → provisional hypothesis → V1–V5
  falsification → revise, each validation its own locked ticket
  ([[GCB-035]]…[[GCB-038]]); the [[GCB-034-LOOK-AROUND]] orthogonal pass caught
  the batch-1-decode / K-parallelism constraints *before* they were baked in;
  the PBG↔Orange conflation was caught and corrected in an audit and the
  representation is clean; nothing pre-commits an optical parameter.
* **Emergence +0.7 (Purple):** the discovery — **not** "~1000× less bandwidth"
  but that **the electrical compute domain is an enormous compression boundary
  (local high-precision K-reduction over the whole `K_TOTAL` + block-float
  requantization) letting the optical transport operate on a dramatically
  smaller representation than the fabric moves internally** — **survived**
  falsification: ≈ 432× in Mode A, link closing on 1 λ. It reframes the optical
  Epic's difficulty envelope (the WDM PHY is sized by *reduced results*, and by
  Mode B's ≈ 60 λ, not by the 2048 Gbps operand bus). Supporting emergent
  reuse: `gcb_tile_requantize` (TKT-023, built for on-die numeric-range
  management) *is* the optical-boundary compressor; the K-reduction schedule
  *is* the optical cadence for free (no backpressure machinery, 0 stalls). Not
  +1.0: the headline ratio still carries a "pending a real activation trace"
  caveat (D2 settling measurement), and Mode B's compression is only ~114×.
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
Quality, or Emergence. No PBG vector and no PBG-O disposition was assigned by
the act of drafting. **At close (2026-09-10) both are assigned, separately:**
the R³ vector `T = (+1.0, +1.0, +0.7)` → `green` (in `telemetry:`), and the
PBG-O flag `orange` (in `pbg_o:`) — the contract *was* confronted with physical
reality (anchored in the [[GCB-032]] ASAP7 measurements; the V1–V5 Falsification
Test is a quantitative confrontation that did partly falsify it). The flag sits
beside the vector; neither replaces the other.

### Toolchain / scope

No RTL, no cocotb, no P&R run. Doc-only, in `gcb-workspaces`. The compute-side
figures are read from existing TKT-017 artifacts and `eda/GCB-032/`; the
RTL Baseline (`gcb-wdm-transceiver`) is not touched.

---
## Execution Log

| date | step |
|---|---|
| 2026-09-10 | Drafted (Lead Systems Architect) — Q1–Q4 answered from the ASAP7 / TKT-017 measurements; D1–D4 surfaced. |
| 2026-09-10 | Provisional D1 = POST-REQUANTIZATION, D4 = FULL-K LOCAL REDUCTION set (D2/D3 open) — recorded as a testable hypothesis, ticket held `open`. |
| 2026-09-10 | [[GCB-034-LOOK-AROUND]] — orthogonal-discovery pass. C1–C11; the batch-1-decode / no-K-parallelism finding re-chartered [[TKT-019]] to carry both regimes. |
| 2026-09-10 | Audit correction (Architect + Orange Team) — PBG↔Orange conflation isolated and fixed: `telemetry:` restored to the R³ vector only, `pbg_o` kept as a separate flag, headings de-Orange-d, Purple stated as a candidate pending review. |
| 2026-09-10 | [[GCB-035]] — TKT-019 **V1** (payload ≈ 143 B, **HOLDS**) + **V2** (cadence `1/512 ns`, **HOLDS** for FFN; small-`K` → D3). |
| 2026-09-10 | [[GCB-036]] — TKT-019 **V3** (`OUT_W`): INT4 **FAILS** the 25 dB SQNR budget → **D2 = INT8, PER_ROW, RNE**. |
| 2026-09-10 | [[GCB-037]] — TKT-019 **V4** (link budget): Mode A **closes on 1 λ** (+2.5–8 dB); Mode B needs ≈ 60 λ; KP4 load-bearing; 2-PAM/QPSK only. |
| 2026-09-10 | [[GCB-038]] — TKT-019 **V5** (partitioning): full-K-local **FAILS as a global law** (`K` ceiling ≈ 45 k; batch-1 decode) → **D4 = selectable mode**. Falsification Test complete. |
| 2026-09-10 | **CLOSED (PM + Architect)** — contract survives as a **dual-regime** contract; D1–D4 ratified; graded `T = (+1.0, +1.0, +0.7)` → `green`, PBG-O flag `orange`. |

---
## Telemetry & Evaluation

**Final State:** `done` — the dual-regime Optical Transport Contract is ratified
(§ "The Ratified Dual-Regime Contract"). Build sub-stories `TKT-019.x` proceed
against it.

### PBG grade (R³ vector — `gcb-wiki/09` / TKT-005)

**`T = (spec +1.0, quality +1.0, emergence +0.7)`, `‖T‖₂ ≈ 1.578`,
`telemetry_color: green`** (argmax\|axis\| = spec = quality; tie-break X > Y →
+X → Green).

* **X Specification = +1.0 (Green).** The contract is complete and correct:
  payload / width / cadence / continuity / reduction, every figure traceable,
  stated before any optical-physics commitment. It delivered the *right* answer
  — a dual-regime contract — to a question that branched, and ratified D1–D4
  against a 5-part falsification test, correcting (not waiving) the parts that
  failed.
* **Y Quality = +1.0 (Blue).** Measure → hypothesis → V1–V5 → revise, each
  validation a locked ticket; the LOOK-AROUND pass caught silent constraints
  before commitment; the PBG↔Orange conflation was audited and corrected;
  nothing pre-commits an optical parameter.
* **Z Emergence = +0.7 (Purple).** The compression-boundary discovery survived
  falsification (≈ 432× Mode A, 1-λ link closure) and reframes TKT-019's
  difficulty envelope; plus the emergent reuse of `gcb_tile_requantize` as the
  boundary compressor and the K-schedule as the free optical cadence. Below
  +1.0 because the headline ratio still awaits the D2 real-activation-trace
  settling measurement and Mode B compression is only ~114×.

### PBG-O disposition (TKT-000 flag — separate from and orthogonal to the R³ vector above)

**`orange`.** The contract was **confronted with physical reality**: it is
anchored in the [[GCB-032]] ASAP7 measurements (WNS, flop count, the 38 max-slew
DRVs), and the V1–V5 Falsification Test is a quantitative confrontation that
*could have* — and in part *did* (V3 INT4, V5 D4-as-global-law) — falsify it.
Per TKT-000 this flag does **not** occupy or modify any R³ axis and is **not**
the grade; it records that the artifact is falsifiable and has been tested, and
sits beside `T` in the frontmatter (`pbg_o: orange`).

### Carried forward (not part of this grade)

The [[GCB-032]] **38 max-slew DRVs remain an open, unresolved physical
observation**; this contract did not resolve, close, or reinterpret them — it
respected them as a transport constraint (prefer narrow, reduced, low-cadence
payloads), which the ratified Mode A does.

**Vector Summary:** `green` · `T = (1.0, 1.0, 0.7)` · `‖T‖₂ ≈ 1.58` · PBG-O
flag `orange`.
