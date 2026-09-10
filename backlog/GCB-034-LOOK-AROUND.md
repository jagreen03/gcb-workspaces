---
id: GCB-034-LOOK-AROUND
parent: GCB-034
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - epic-tkt-019
  - orange-team
  - look-around
  - architecture
  - discovery
---

# Objective

The **orthogonal-discovery pass** on [[GCB-034]]. GCB-034's central result — the
electrical compute domain as an enormous compression boundary, ~1000× smaller
optical representation than the internal operand bus — is *attractive*. This
document exists because attractive results are where architectures quietly
acquire constraints nobody chose.

**The question is not "is the compression real?" (that is [[TKT-019]]'s
falsification job). The question is: *what are we agreeing to, without noticing,
because the compression looks this good?*** In particular — the mandated focus —
if provisional **D4 = FULL-K LOCAL REDUCTION** holds, what has that done to our
ability to partition workloads and scale horizontally?

This is not a grade and not a decision. It is a list of accepted costs, so the
Architect accepts them on purpose. Its findings feed `TKT-019` validation **V5**.

## What makes the result seductive

A **compression ratio is a scalar**. "~1000×" collapses a many-dimensional
transport/compute trade into one number, on the one axis (per-transaction
optical bandwidth) the optical layer most wants to hear about. It is silent on:
aggregate fabric-crossing traffic, end-to-end latency, partition flexibility,
numeric fidelity of the hand-off, receiver-side flow control, and the
reversibility of the PHY commitment. The Look-Around re-expands the scalar.

## Constraints we may be silently accepting

Each is a real cost of the provisional GCB-034 contract (D1 post-requantization
+ D4 full-K local). None is disqualifying; all should be chosen knowingly.

| # | silently accepted | because we were looking at… |
|---|---|---|
| C1 | **The K (contraction) dimension is not partitionable across nodes.** Standard contraction-axis tensor parallelism (Megatron row/column-parallel) is off the table. | …how small the optical payload got once K was reduced locally. |
| C2 | **Per-node SRAM and weight capacity scale with the *model's* K, not with the fabric.** A node must hold a full-`K_TOTAL` slice of both operands (and the full-K weight column for every N-tile it owns). The `gcb-wiki/06` 8.126 MiB SRAM sizing is tied to a specific `K_TOTAL`. | …the transaction being 140 B, not the working set behind it. |
| C3 | **Accumulator width is bound to `K_TOTAL`.** `ACC_W = 32` was derived for K ≈ 4–8 k (`8 + ⌈log2 K⌉` bits over INT4 products). Grow K under full-K-local and every PE accumulator widens — straight into the GCB-032 sequential-area / max-transition regime — or precision is lost. A K-split keeps each node's accumulator narrow. | …the output being INT4 after requantization, not the INT32 it was accumulated in. |
| C4 | **Latency to first result is serial in `K_TOTAL`.** One tile = `K_STEPS = K_TOTAL/K_MAX` cycles (512 ns at production geometry), and full-K-local means that reduction *cannot be parallelised* to shorten it. Alternative B across `P` nodes is `K_STEPS/P` + one remote-accumulate hop. | …throughput (4096 MAC/cycle, 0 stalls), not time-to-first-token. |
| C5 | **The fault domain is the entire K-reduction.** A node failing mid-reduction loses the whole output tile; restart is from K = 0. A K-split has per-slice restart granularity. | …the happy-path periodicity, not the recovery path. |
| C6 | **Straggler / process-variation sensitivity.** One node owns a tile end-to-end for 512 cycles; the slowest node sets the tile rate. GCB-032 already shows this design lives near the max-transition edge, so per-node derating/binning is plausible — and un-averaged under full-K-local. A K-split spreads each tile across `P` nodes and averages the variation out. | …a single node's clean timing closure, not a population of nodes. |
| C7 | **D1 assumes a lossy INT4 hand-off is universally acceptable.** Post-requantization presumes every cross-fabric consumer is a matmul that tolerates INT4 activations. Residual adds, LayerNorm, the logits projection, KV-cache writes may need higher precision; if they live on other nodes the contract forces a lossy crossing where a lossless one was required. | …how much smaller INT4 made the payload. |
| C8 | **No receiver-side flow control.** GCB-034 removes rate-matching/backpressure because the *sender* is deterministically periodic. It does not establish that the *receiver* always consumes at the tile rate — a downstream node stalling on its own compute has no way to push back; the shallow FIFO overflows or tiles drop. | …the sender's 0-stall guarantee, not the consumer's. |
| C9 | **The PHY commitment is hard to reverse.** Sizing WDM channel count / QAM order / λ plan around ≈140 B periodic transactions bakes in the compression case. If any workload class later needs Alternative B (~7.3× wider payload, up to `P×` cadence), retrofitting a PHY optimised for 140 B is expensive. | …the contract as a fixed input to the physics stories, not as a hypothesis. |
| C10 | **"The optical layer moves the residue" invites under-investment.** Framing optical as carrying 0.27 GB/s of leftovers risks skimping on the optical layer's *own* reliability, observability, and error handling — the link is small in bandwidth, not in importance (every cross-node activation depends on it). | …the bandwidth number, not the dependency graph. |
| C11 | **The 0-stall cadence guarantee is conditional.** The `gcb-wiki/06` double-buffer margin (per-band compute > refill burst) is *validated* at `K_TOTAL = 256` (`test_compute_e2e.py`) and *asserted* at `K_TOTAL = 8192`. Full-K-local at very large K stresses the sustained-SRAM-read margin; if it ever breaks, the "deterministically periodic" cadence the optical layer is told to assume becomes bursty. | …the measured 0-stall result at test geometry, extrapolated. |

## D4 deep-dive — Full-K Local Reduction vs partitioning / horizontal scale

**If all K-reduction is forced electrically onto one node, horizontal scaling is
restricted to the M and N axes only.**

* **K-parallelism: gone (C1).** For a `M×K · K×N` matmul you may split `M`
  (batch / sequence rows) and `N` (output features) across nodes; you may **not**
  split `K`. Contraction-axis parallelism — the workhorse of large-model tensor
  parallel — is unavailable. Every node that participates in an output tile must
  see that tile's *entire* K.

* **The node is sized by the model, not by the job (C2, C3, C10-weights).**
  Adding nodes buys more M-tiles and N-tiles in flight; it does **not** reduce
  the per-node K working set, accumulator width, or full-K weight-column
  residency. A model whose `K_TOTAL` (hidden dim; or, in attention, the
  sequence length that plays the K role) exceeds one node's electrical
  reduction budget is **not runnable** under a strict full-K-local contract —
  it *requires* Alternative B or a hybrid.

* **Latency-critical autoregressive decode is the sharp edge (C4, C6).**
  Single-stream decode is `batch = 1`: there is **no M dimension to
  parallelise**. Horizontal scale-out for one request then reduces to
  N-parallelism (split the output projection) plus pipeline parallelism across
  layers. The K-reduction for each tile stays serial at `K_STEPS` and cannot be
  shortened by adding nodes. So: **full-K-local caps how much faster more silicon
  can make a single latency-bound request** — you can add throughput (more
  concurrent requests) but not much single-request speed. A K-split would let
  `P` nodes co-reduce one tile's K and cut its latency ~`P×` (minus a hop).

* **Scale-out story that survives:** throughput-oriented, large-batch workloads
  (training; batched/offline inference) whose `K_TOTAL` fits one node. There,
  M-parallelism has plenty to spread, the serial-K latency is amortised over the
  batch, and the ~1000× transport compression is a genuine win with few
  regrets.

* **Scale-out story that does not:** (i) any model whose K exceeds a node's
  budget; (ii) low-latency single-stream serving; (iii) workloads needing
  fine-grained fault/restart granularity along K; (iv) heterogeneous-node
  fabrics where straggler-averaging matters.

**Net:** D4 = full-K-local is not wrong — it is a **workload-class commitment**.
Adopting it globally silently narrows the platform to K-fits-in-a-node,
throughput-first workloads. The likely correct shape is **D4 as a mode**:
full-K-local where it holds (and the ~1000× compression stands), Alternative B
(or a hybrid: local reduce to INT16 partials, optical-carry those) where a
workload class needs K-parallelism or single-request latency. `TKT-019` V5 is
where each class is tested against that fork.

## What this feeds

* **`TKT-019` validation V5** — model workloads beyond one node's K budget;
  quantify the partitioning / horizontal-scale cost of strict full-K-local; test
  each workload class against Alternative B. A class where Alternative B wins
  **falsifies D4 for that class**.
* **`GCB-034` D4 entry** — should likely be reframed from a single global
  decision to "full-K-local for class X (contract holds); Alternative B / hybrid
  for class Y" — pending the V5 result. Not changed here.
* **PHY sizing (later `TKT-019.x`)** — carry a headroom / mode provision so C9
  (irreversible PHY commitment) does not bite if a K-split class turns out to be
  required.

## Disposition

This pass makes no PBG grade and no architectural decision. It records that the
provisional GCB-034 contract, if adopted globally, **accepts C1–C11** — most
sharply, **no K-parallelism and limited single-request horizontal scale**. The
Architect should adopt full-K-local *as a workload-class mode*, with the
alternative kept live, rather than as a platform-wide law. `GCB-034` stays
`open | pending`.

---
## Telemetry & Evaluation
*(Orthogonal-discovery pass — no PBG vector, no PBG-O disposition; findings feed
`TKT-019` V5.)*
**Final State:** `open | pending`
