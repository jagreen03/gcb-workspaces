---
id: GCB-035
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
  - optical-wdm
  - line-rate
  - architecture
---

# Objective

Execute **TKT-019 falsification validations V1 (payload size) and V2
(transaction cadence)** for the provisional [[GCB-034]] transport contract, and
from them **derive the raw and true (framed + FEC-coded) optical line rate**
each dataflow mode demands to sustain the compute fabric **without
backpressure**.

* **Alternative A** — provisional D1/D4: **post-requantization** payload,
  **full-K local reduction**. One INT4 `q_tile` + `q_scale` per output tile.
* **Alternative B** — the counterfactual: **K-split + INT32 partial sums**. One
  `acc_tile` per output tile per K-partner.

Anchor (from [[GCB-032]] / [[GCB-034]]): **1 transaction per `K_STEPS = 512`
advancing cycles at a 1.0 GHz target clock → a 512 ns window**, deterministically
periodic (0 SRAM read stalls, [[TKT-025]]).

This ticket computes numbers; it does not choose a mode. `GCB-034` stays
`open | pending`.

---

## V1 — Actual payload size (bit accounting)

The `~140 B` / `1024 B` in [[GCB-034]] were tensor-data-only. V1 counts **every
carried bit** — data + block-float scale + sticky flags + a transaction header
(tile `(M,N)` index, valid, mode bit).

### Alternative A — post-requantization tile

| field | size | source |
|---|---:|---|
| `q_tile` — 256 elements × `OUT_W = 4` | 1024 b (128.00 B) | `gcb_tile_requantize` (TKT-023) |
| `q_scale` — `SCALE_MODE = PER_ROW`: 16 channels × `EXP_W = 6` | 96 b (12.00 B) | TKT-023 |
| `q_clip` — sticky saturation flag | 1 b | TKT-023 (TKT-024 fix) |
| transaction header — `(M,N)` tile index + valid + mode | ≈ 24 b (3.00 B) | est. |
| **payload subtotal** | **1145 b ≈ 143.1 B** | |
| **rate-calc figure (data + scale, per task)** | **1120 b = 140.0 B** | |

`SCALE_MODE` sensitivity: `PER_TILE` → `q_scale` = 6 b, payload ≈ **129 B**;
`PER_ROW` / `PER_COL` → 96 b, payload ≈ **140 B**. (A D2-adjacent choice; the
contract assumes `PER_ROW`.)

### Alternative B — INT32 partial-sum tile

| field | size | source |
|---|---:|---|
| `acc_tile` — 256 elements × `ACC_W = 32` | 8192 b (1024.00 B) | `gcb_mac_tile_array` (TKT-022) |
| block-float scale | — (raw INT32; requantization is *after* remote accumulate) | — |
| transaction header — `(M,N)` tile index + K-partner id + valid | ≈ 24 b (3.00 B) | est. |
| **payload subtotal** | **8216 b ≈ 1027.0 B** | |
| **rate-calc figure (data only, per task)** | **8192 b = 1024.0 B** | |

### V1 verdict

**CONTRACT HOLDS.** The real Alternative-A transaction is **≈ 143 B**, not a
regime change from the contract's ≈ 140 B — scale + header add **≈ 2 %**, and
even at `SCALE_MODE = PER_COL` it stays well inside the "narrow, already-reduced"
class. Alternative B's 1024 B is exact (no scale) plus a 3 B header. The
**7.3× payload gap** between the modes is confirmed:
`8192 / 1120 = 7.31` (data) · `8216 / 1145 = 7.18` (incl. header).

---

## V2 — Transaction cadence

### Derivation

```
K_STEPS   = K_TOTAL / K_MAX                    (advancing cycles per output tile)
          = 8192 / 16  = 512                   (gcb-wiki/06 production geometry)
t_window  = K_STEPS × t_clk                    (t_clk = 1.0 ns @ 1.0 GHz target)
          = 512 × 1.0 ns = 512 ns
f_txn     = 1 / t_window = 1 / 512 ns
          = 1.953125 M transactions/s
```

Emission is **deterministically periodic**: the requantizer produces one tile
per `K_STEPS` with a constant [[GCB-028]] `MAXRED_REG_STAGES` latency offset
(shifts phase, not rate), and the operand feed has **0 SRAM read stalls**
([[TKT-025]]) — no data-dependent jitter. A 1–2 tile output FIFO (≈ 280 B)
absorbs the sub-`K_STEPS` micro-burst; the line must sustain the average, not a
peak.

### Line-rate identity

```
line_rate_raw = payload_bits / (K_STEPS × t_clk)
             = payload_bits / (K_TOTAL/K_MAX × t_clk)
```

**The line rate is inversely proportional to `K_TOTAL`.** The FFN production
geometry (`K_TOTAL = 8192`) is the anchor; a layer with materially different `K`
in the contraction role demands a different line rate for the *same* payload:

| layer / role | `K` | `K_STEPS` | `t_window` @ 1 GHz | Alt-A raw line rate (140 B) |
|---|---:|---:|---:|---:|
| FFN up-proj (anchor) | 8192 | 512 | 512 ns | **2.19 Gbps** |
| FFN, K = 4096 | 4096 | 256 | 256 ns | 4.38 Gbps |
| attention `A·V`, K = seq 2048 | 2048 | 128 | 128 ns | 8.75 Gbps |
| attention `Q·Kᵀ`, K = head_dim 128 | 128 | 8 | 8 ns | **140 Gbps** |
| e2e test geometry, K = 256 | 256 | 16 | 16 ns | 70 Gbps |

### V2 verdict

**CONTRACT HOLDS for the FFN production geometry** — cadence is exactly the
`1 / 512 ns` periodic stream [[GCB-034]] assumed. **Conditional finding:**
small-`K` layers (attention `Q·Kᵀ`, `head_dim` in the K role) push the per-tile
line rate up by `K_TOTAL / K` — 64× at `K = 128` — which **exceeds any plausible
per-lane optical rate at the per-tile granularity**. Those layers force
[[GCB-034]] decision **D3** (transaction granularity): super-tile aggregation, or
not crossing the optical boundary per-tile for small-K ops. This is a new,
falsifiable input to D3, logged here, not decided.

---

## Raw line rate — Alternative A vs B (512 ns window, per task)

```
Alt A :  140 B  = 1120 bit  /  512 ns  =  2.1875 Gbit/s   (raw)
Alt B : 1024 B  = 8192 bit  /  512 ns  = 16.0000 Gbit/s   (raw)
ratio  :  16.0 / 2.1875 = 7.314×
```

(Matches [[GCB-034]] Q2: 0.273 GB/s → 2.19 Gbps; 2.0 GB/s → 16.0 Gbps.)

---

## Framing / FEC overhead → true physical line rate

Standard optical PCS/FEC stack (IEEE 802.3, 25G-class and up):

| stage | ratio | overhead |
|---|---:|---:|
| 64b/66b line coding (Cl. 49) | 66 / 64 = 1.031250 | 3.125 % |
| KP4 FEC — RS(544, 514, t=15) over GF(2¹⁰) (Cl. 91/134) | 544 / 514 = 1.058366 | 5.837 % |
| **combined coding factor** | **1.091440** | **9.144 %** |
| + alignment markers / idle / rate-comp / protocol header | ≈ 1.005–1.03 | ≈ 0.5–3 % |
| **engineering line-rate provision (this ticket)** | **1.12** | **12 %** (task upper bound) |

**True physical line rate** (raw × provision; range = coding-exact 9.14 % → task
12 %):

```
Alt A :  2.1875 Gbps ×1.0914 = 2.388 Gbps   …  ×1.12 = 2.450 Gbps
       →  ≈ 2.39 – 2.45 Gbps
Alt B : 16.0000 Gbps ×1.0914 = 17.46 Gbps   …  ×1.12 = 17.92 Gbps
       →  ≈ 17.5 – 17.9 Gbps
```

Overhead is multiplicative, so the **7.31× A→B gap is unchanged** by framing.

---

## SerDes lane mapping (what the two modes actually cost in optics)

| mode | true line rate | fits in… | headroom |
|---|---:|---|---|
| **Alt A** (post-requant, full-K local) | **≈ 2.4 Gbps** | a single **≤ 10 Gbps** lane (2.5G / 10G NRZ) | **~4× on a 10G lane**; trivially one sub-λ of any DWDM channel |
| **Alt B** (K-split, per K-partner, 512 ns ref) | **≈ 17.9 Gbps** | a single **25G-class** lane (25.78125G / 26.5625G NRZ) | ~30–45 % on a 26.5625G lane; **does not fit a 10G lane** |

### Alt B is worse than 7.3× once the K-split is real

A K-split exists to cut **single-tile latency** ([[GCB-034-LOOK-AROUND]] C4):
`P` partners co-reduce one tile's `K`, each finishing in `K_STEPS / P` cycles
and emitting a 1024 B partial every `512 / P` ns.

```
per-link raw  = 8192 bit / (512/P ns)      = 16 · P  Gbps  (raw)
per-link true = 16 · P · 1.12              ≈ 17.9 · P  Gbps
accumulator inbound (P links)             = 16 · P²  Gbps raw  ≈ 17.9 · P² true
```

| `P` (K-partners) | per-link true | accumulator aggregate true | vs Alt A |
|---:|---:|---:|---:|
| 1 (reference) | 17.9 Gbps | 17.9 Gbps | 7.3× |
| 2 | 35.8 Gbps (→ 53G PAM4 lane) | 71.7 Gbps | 14.6× / 29× |
| 4 | 71.7 Gbps (→ 2× 53G or 112G lane) | **286 Gbps** | 29× / 117× |

The accumulator node's inbound (**≈ 286 Gbps at P = 4**) is ~14 % of the
internal 2048 Gbps operand bus — a real, if not fabric-dominant, bandwidth sink.
**Alternative B's transport cost is `~7.3 · P×` per link and `~7.3 · P²×` at the
accumulator**, not a flat 7.3×.

---

## What this feeds

* **TKT-019 V1** → `CONTRACT HOLDS` (payload ≈ 143 B, ~2 % over the contract's
  140 B; 7.3× A→B gap confirmed).
* **TKT-019 V2** → `CONTRACT HOLDS` for FFN production geometry; **conditional
  fail** for small-`K` layers → escalates to D3.
* **`GCB-034`** — add the line-rate identity
  `line_rate = payload_bits / (K_TOTAL/K_MAX · t_clk)` and the two derived
  numbers (Alt A ≈ 2.4 Gbps, Alt B ≈ 17.9 Gbps · P). Do **not** close;
  V3 (`OUT_W` numeric consequences) and V4 (link budget) are still open.
* **TKT-019 V4 (link budget)** — inputs: Alt A needs ≥ 2.45 Gbps/lane; Alt B
  needs ≥ 17.9 Gbps/lane (P = 1) up to ≥ 71.7 Gbps/lane (P = 4); the demo λ
  count and the `gcb-wiki/13` reconstruction algebra set the per-λ carve-up.
* **`GCB-034` D3** — small-`K` line-rate blow-up is a new falsifiable driver for
  transaction granularity.

## Execution constraints honored

- [x] Raw Gbps for the **140 B** post-requant payload (Alt A): **2.1875 Gbps**.
- [x] Raw Gbps for the **1024 B** INT32 partial-sum payload (Alt B):
  **16.0 Gbps**.
- [x] Cadence anchored to [[GCB-032]]: 1 tile / `K_STEPS = 512` cycles @
  1.0 GHz = **512 ns window**.
- [x] Framing/FEC penalty applied: 64b/66b × KP4 RS(544,514) = **9.14 %**
  coding, carried at the task's **12 %** engineering provision →
  **Alt A ≈ 2.4 Gbps**, **Alt B ≈ 17.9 Gbps** true physical line rate.

---
## Telemetry & Evaluation
*(V1/V2 execution for TKT-019 — no PBG vector, no PBG-O disposition; verdicts
feed the Falsification Test. `GCB-034` stays `open | pending`.)*
**Final State:** `open | pending`
