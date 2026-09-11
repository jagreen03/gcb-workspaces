---
id: GCB-038
parent: GCB-034
epic: TKT-019
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - epic-tkt-019
  - orange-team
  - falsification
  - scaling
  - partitioning
  - architecture
---

# Objective

Execute **TKT-019 falsification validation V5 — the scaling / partitioning
constraints of GCB-034 decision D4 (FULL-K LOCAL REDUCTION)**. Quantify one
node's K-reduction capacity, identify which workload classes exceed it, and
build the partitioning matrix: what horizontal-scale-out axes survive under
full-K-local, and which required class forces Alternative B.

Puts numbers on the qualitative [[GCB-034-LOOK-AROUND]] D4 analysis. `GCB-034`
stays `open | pending` — the Architect closes it, not this ticket.

---

## One node's K-reduction capacity — three ceilings

### (a) Accumulator-precision ceiling — **not binding**

`ACC_W = 32`, INT4×INT4 product ∈ `[−64, 63]` (8 b). Worst-case (all products
same sign, full magnitude) overflow at `K = 2^31 / 64 = 2^25 ≈ 33.5 M`;
the TKT-022 derivation `8 + ⌈log2 K⌉` leaves ~11 guard bits at `K = 8192`.
**K would have to exceed ~16 M to bind** — never the constraint.

### (b) SRAM operand-residency ceiling — **the binding constraint**

Full-K-local requires, per node, for a band of output tiles:

```
S_node ≈ 2·(GRID_M · K · P_act)              A-band, double-buffered
       + GRID_N · K · P_wt · N_SUBTILES      weight band held for the M-band
       + GRID_M·GRID_N · (ACC_W/8)           accumulators
```

With `P_act = 1 B` (INT8, per [[GCB-036]]), `P_wt = 0.5 B` (INT4),
`GRID_M = GRID_N = 16`, `N_SUBTILES = 20` (the [[TKT-025]] double-buffer
margin):

| `K_TOTAL` | `S_node` | fits 8 MiB? |
|---:|---:|:--:|
| 8 192 (70B FFN anchor) | **≈ 1.6 MiB** | ✅ |
| 16 384 | ≈ 3.1 MiB | ✅ |
| 32 768 | ≈ 6.3 MiB | ✅ (tight) |
| **≈ 45 000** | **≈ 8.6 MiB** | **❌ ceiling** |
| 65 536 | ≈ 12.6 MiB | ❌ |
| 131 072 | ≈ 25.2 MiB | ❌ |

**`K_TOTAL` ceiling ≈ 45 k** at 8 MiB SRAM / `N_SUBTILES = 20`. Cutting
`N_SUBTILES` raises it but re-opens the 0-stall guarantee ([[GCB-035]] V2 /
[[TKT-025]] refill-burst margin) — a trade, not free headroom.

### (c) Latency ceiling — **binding for batch-1 decode**

One tile = `K_STEPS = K_TOTAL / K_MAX` cycles. Full-K-local **serialises** the
K-reduction: it cannot be parallelised across nodes (that is D4). Batch-1 decode
adds a `GRID_M / M_active = 16×` penalty (M = 1 uses 1 of 16 PE rows).

| workload | effective MAC/cycle | time / 70B FFN block / token |
|---|---:|---:|
| batched (M ≥ 16) | 4 096 | ≈ 115 µs |
| **batch-1 decode** | 256 | **≈ 1.84 ms** |

The **only** lever that recovers the batch-1 penalty on the serial-K portion is
a K-split across `P` nodes (→ `1.84 / P` ms; P = 16 → back to ≈ 115 µs). **D4 =
full-K-local forbids exactly that lever.**

---

## Workload classes vs the ceiling

| class | `K` in the contraction role | full-K-local? |
|---|---:|:--|
| FFN up/down-proj, 70B (anchor) | `d_model = 8 192` | ✅ 1.6 MiB, 512 ns/tile |
| FFN, `d_model` 16 k – 32 k | 16 384 – 32 768 | ✅ 3 – 6 MiB, 1 – 2 µs/tile |
| Attention `Q·Kᵀ` | `head_dim = 128` | ✅ trivially — but small-`K` line-rate blow-up ([[GCB-035]] V2, [[GCB-036]]) |
| Attention `A·V`, context ≤ 16 k | `seq_len` ≤ 16 384 | ✅ ≤ 3 MiB |
| **Attention `A·V`, context ≥ ~32 k** | `seq_len` ≥ 32 768 | **❌ / marginal → Alternative B** |
| **Attention `A·V`, context 128 k** | `seq_len = 131 072` | **❌ 25 MiB → Alternative B mandatory** |
| MoE expert FFN | `d_model = 8 192` per expert | ✅ (routing is an orthogonal concern) |
| Very wide dense (`d_model ≥ 64 k`, hypothetical) | ≥ 65 536 | ❌ → Alternative B |
| **Latency-critical batch-1 decode (any `K`)** | — | **⚠️ no latency-recovery lever → Alternative B for the latency SLA** |

**Long context is not exotic** — it is a headline LLM capability. Contexts
≥ ~32 k tokens push the attention `A·V` matmul past the per-node K ceiling.
**Alternative B is mandatory for a required workload class.**

---

## Partitioning matrix — what survives under full-K-local

| parallelism axis | full-K-local | why |
|---|:--:|---|
| **Data parallel** (replicate model, split batch) | ✅ intact | orthogonal to K; each replica is full-K-local |
| **Tensor parallel — along N** (split output features) | ✅ intact | each node owns a column-band, full-K-local for it; optical carries per-node result tiles ([[GCB-034]] D1) |
| **Tensor parallel — along K** (shard the contraction, all-reduce) | ❌ **eliminated** | this *is* what D4 = full-K-local forecloses; Megatron row-parallel is not expressible |
| **Pipeline parallel** (split layers across nodes) | ✅ intact | each stage full-K-local; optical carries activations layer→layer — the D1 boundary |
| **Sequence parallel** (split the sequence dim) | ⚠️ **split** | attention `A·V` (`K = seq_len`): sequence-parallel *is* K-parallel → **blocked**. FFN (`sequence dim = M`): sequence-parallel = M-parallel → **intact** |
| **Expert parallel** (MoE, experts → nodes) | ✅ intact | each expert FFN is full-K-local |

**Full-K-local costs: K-tensor parallelism and sequence-parallelism-for-attention.
It keeps: data, N-tensor, pipeline, expert.** For a moderate-context dense
70B FFN that set is sufficient; for long-context or very-wide models the loss is
disqualifying.

---

## V5 verdict

**CONTRACT FAILS for D4 = full-K-local as a global law.** Two *required*
workload classes force Alternative B:

1. **Long-context attention `A·V`** — `seq_len ≥ ~45 k` in the K role exceeds
   the per-node SRAM residency ceiling; 128 k context needs ~25 MiB (3× over).
2. **Latency-critical batch-1 decode** — full-K-local serialises the
   K-reduction and, with the 16× M-grid under-utilisation, gives ≈ 1.84 ms per
   70B FFN block per token; the only recovery lever (K-split across `P` nodes)
   is exactly what D4 forbids.

**CONTRACT HOLDS for D4 = full-K-local as a *workload-class mode*** — for the
anchor 70B FFN geometry (`K = 8 192`, batched/throughput inference, context
≤ ~32 k) it is the right choice: data + N-tensor + pipeline + expert parallelism
all survive, SRAM ≈ 1.6 MiB, 512 ns/tile, and the ≈ 432× optical compression
([[GCB-036]]) with 1-λ link closure ([[GCB-037]]) are real wins.

**This confirms [[GCB-034-LOOK-AROUND]]: D4 must be a selectable mode, not a
platform-wide law.** The dual-regime PHY ([[GCB-037]] V4: ≈ 60 λ for the
latency / K-split mode) is **not optional** — it is required by the classes that
force Alternative B.

---

## What this feeds

* **`GCB-034` D4** → provisionally **"full-K-local for the FFN throughput class
  (`K ≤ ~45 k`, batched, context ≤ ~32 k); Alternative B (K-split) mandatory for
  long-context attention `A·V` and latency-critical batch-1 decode."** A
  mode bit in the transaction header selects the regime.
* **TKT-019** → the Falsification Test is **complete**: V1 ✅ · V2 ✅ (FFN;
  small-`K` → D3) · V3 ⚠️ (INT4 → INT8) · V4 ✅ throughput / ⚠️ latency (≈ 60 λ)
  · **V5 ⚠️ (D4 is a mode)**. **The contract SURVIVES — as a dual-regime
  contract, not a single global one.** `GCB-034` is ready for Architect review
  to close with D1 = post-requantization, D2 = INT8, D3 = per-tile for
  `K ≥ ~2 k` / super-tile for small-`K`, D4 = mode-selected.
* **TKT-019 PHY-scaling sub-stories** inherit: **dual-regime**, ≈ 60 λ, INT8,
  KP4, 2-PAM/QPSK; the swept-λ regression must reach ≥ 60 λ.
* **`GCB-034-LOOK-AROUND` C1 / C2 / C4** → quantified: K-tensor + attention
  sequence parallelism lost; `K_TOTAL` ceiling ≈ 45 k; batch-1 decode ≈ 1.84 ms
  / FFN block / token with no recovery lever under full-K-local.

## Execution constraints honored

- [x] One node's K-reduction capacity: accumulator (`K ≤ ~16 M`, not binding),
  **SRAM residency (`K_TOTAL ≤ ~45 k` at 8 MiB / `N_SUBTILES = 20`)**, latency
  (batch-1 decode ≈ 1.84 ms / FFN block / token, no K-parallel recovery).
- [x] Workloads exceeding it: long-context attention `A·V` (≥ ~45 k),
  very-wide dense (`d_model ≥ 64 k`), latency-critical batch-1 decode.
- [x] What full-K-local forces on partitioning: **loses K-tensor + attention
  sequence parallelism; keeps data + N-tensor + pipeline + expert.**
- [x] Verdict: **Alternative B is mandatory for a required class** → D4 = a
  selectable mode, not a global law; dual-regime PHY confirmed required.

---
## Telemetry & Evaluation
*(V5 execution for TKT-019 — no PBG vector, no PBG-O disposition; verdict feeds
the Falsification Test. The Falsification Test is complete; `GCB-034` stays
`open | pending` pending Architect review to close.)*
**Final State:** `open | pending`
