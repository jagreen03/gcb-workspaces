---
id: GCB-036
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
  - quantization
  - numerics
  - architecture
---

# Objective

Execute **TKT-019 falsification validation V3 — the numeric consequences of
`OUT_W`** (GCB-034 decision **D2**: INT4 vs INT8 for the post-requantization
optical payload). Does an INT4 `q_tile` preserve enough accuracy for the
downstream matmul, or must the payload be INT8 (or wider) — with the bandwidth,
line-rate ([[GCB-035]]) and QAM-order consequences that carries?

This ticket computes error bounds and states a falsifiable threshold. It does
**not** run a model. `GCB-034` stays `open | pending`.

---

## What crosses — recap ([[TKT-023]])

`gcb_tile_requantize` is **block floating point**: for each channel (row / col /
tile, per `SCALE_MODE`) it takes the INT32 accumulator magnitudes, finds
`ch_max` via the frozen `gcb_max_reduce`, computes a shared right-shift
`s_ch = max(0, msb(ch_max) + 2 − OUT_W)` (capped at `S_CAP`), then per element
`qm = pe_mag >> s_ch`, rounds per `ROUND`, and saturates to the signed `OUT_W`
range. The wire payload is the `OUT_W`-bit signed mantissa tile + one
`EXP_W = 6` exponent per channel + the sticky `q_clip`.

* INT4 → 1 sign + **3 magnitude bits**, range `[−8, 7]`.
* INT8 → 1 sign + **7 magnitude bits**, range `[−128, 127]`.

The [[TKT-025]] end-to-end test used `OUT_W = 4`, `SCALE_MODE = PER_TILE`,
`ROUND = RNE` and proved the RTL is **bit-exact against the same block-FP
reference** — it did **not** test accuracy against full precision. V3 is that
gap.

---

## Quantization-error model — block FP at `OUT_W` bits

Shared step `Δ = ch_max / 2^b` with `b = OUT_W − 1` magnitude bits. An element
of true magnitude `m`, with in-block ratio `r = ch_max / m ≥ 1`, has
signal-to-quantization-noise ratio (uniform-noise `Δ²/12`):

```
SQNR(r) = 10·log10( 12 · 2^(2b) / r² )
        = 10.79 + 6.021·b − 20·log10(r)   dB
```

| `OUT_W` | `b` | SQNR at `r = 1` (block max) | at `r = 8` (÷8) | at `r = 16` | at `r = 64` |
|---:|---:|---:|---:|---:|---:|
| **INT4** | 3 | **28.9 dB** | 10.8 dB | 4.8 dB | −7.3 dB |
| **INT8** | 7 | **52.9 dB** | 34.9 dB | 28.9 dB | 16.8 dB |

INT4 block FP has **only ≈ 18 dB (≈ 8×) of usable in-block dynamic range**;
INT8 has **≈ 42 dB (≈ 128×)**. The 6-bit exponent gives huge *inter-block*
range either way; it is the *intra-block* spread that `OUT_W` governs, and that
is where transformer activations live.

---

## Activation statistics — the outlier-channel problem

Post-GEMM transformer activations are approximately Gaussian **with heavy tails
and structured outlier channels**: a small number of feature dimensions carry
magnitudes 10–100× the median (the well-documented "outlier feature" behaviour
behind LLM.int8() / SmoothQuant / AWQ). The consequence for a 16×16 block:

| `SCALE_MODE` | one exponent per… | outlier consequence |
|---|---|---|
| **PER_TILE** (the TKT-025 config) | whole 16×16 tile | a single 50× outlier sets the exponent for **all 256 elements** → every non-outlier element gets `Δ` ≈ 50× too coarse → **INT4 ≈ 0 effective bits** on them |
| **PER_ROW / PER_COL** | 16-element row / column | outliers are channel-structured, so they localise to **1 of 16 blocks**; the other 15 keep their own exponent — this is per-channel/group quantisation, the standard mitigation |

So INT4 is only even *arguable* with `PER_ROW` / `PER_COL`, and only if the
per-block ratio `r_max` stays small.

---

## The dynamic-range bound

Take an activation-quantisation budget of **SQNR ≥ 25 dB** per block (a
defensible "activation quantisation stays below the weight-quantisation and
accumulation noise floor, < ~1 % relative layer-output error" heuristic — to be
confirmed by the settling measurement below). Solving `SQNR(r_max) ≥ 25`:

| `OUT_W` | max in-block ratio `r_max` for ≥ 25 dB | real activation blocks span… |
|---:|---:|---|
| **INT4** | **`r_max ≤ 1.56×`** — essentially a flat block | 4–50× typical → **fails generically** |
| **INT8** | **`r_max ≤ 24.9×`** | 4–50×; the ≤ 25× majority pass, and even a 50× block still yields ≈ 19 dB — degraded, not destroyed |

INT4 clears the bar only for: (a) quantisation-aware-trained (QAT) models;
(b) models with an independently verified narrow per-channel range; or (c)
scale granularity finer than per-row (per-group-of-4, per-element) — which
multiplies the `q_scale` metadata and erodes the payload advantage.

---

## Saturation (`q_clip`) — the error that does not average out

Zero-mean rounding error (with `ROUND = RNE`) partially averages over the
downstream K-sum. **Saturation does not.** If `s_ch`'s `+2` headroom bits are
insufficient (a heavier-tailed block than assumed), elements clip to
`±(2^(OUT_W-1) − 1)`:

* INT4 clips to **±7** — a clipped element can lose **> 50 %** of its value, a
  systematic magnitude bias that accumulates as a gain error over K.
* INT8 clips to **±127** — a clipped element loses **< 1 %**.

The requantizer already exposes this: `q_clip` (sticky, per tile). **The
empirical INT4-viability signal is the `q_clip` assertion rate on a real
activation trace** — non-zero `q_clip` at INT4 is a direct falsification.

---

## `ROUND` mode — RNE mandatory for the crossing

`ROUND = RTZ` (0) biases magnitude by ≈ `−Δ/2` mean; this does **not** average
out and accumulates as a systematic gain error over the downstream K-sum.
`ROUND = RNE` (1) is zero-mean. **Anything crossing the optical boundary must be
`ROUND = RNE`**, independent of `OUT_W`. (The TKT-025 config already is.)

---

## V3 verdict

**CONTRACT FAILS for INT4 as a general default.** For a general (non-QAT)
transformer FFN activation tile:

* INT4 block FP holds ≥ 25 dB SQNR only for near-flat blocks (`r_max ≤ 1.56×`),
  while real blocks span 4–50×;
* `PER_TILE` INT4 (the only config yet exercised, TKT-025) is the weakest —
  one outlier destroys the tile;
* INT4 saturation error is a non-averaging systematic bias.

**D2 → provisionally INT8**, `SCALE_MODE = PER_ROW` (or `PER_COL`, whichever
axis carries the outlier channels), `ROUND = RNE`. INT4 remains available as an
opt-in for QAT / verified-narrow-range models, or with finer scale granularity
at a metadata cost.

*This is provisional, exactly as D1/D4: it is the hypothesis V3 hands to the
settling measurement, not a closed decision. `GCB-034` stays `open | pending`.*

---

## Consequences of D2 = INT8

### Payload and line rate ([[GCB-035]] revised)

| field | INT4 (prior) | **INT8 (D2 provisional)** |
|---|---:|---:|
| `q_tile` — 256 × `OUT_W` | 1024 b (128 B) | **2048 b (256 B)** |
| `q_scale` PER_ROW — 16 × 6 b | 96 b (12 B) | 96 b (12 B) |
| `q_clip` + header | ≈ 25 b | ≈ 25 b |
| **payload** | ≈ 1145 b ≈ **143 B** | ≈ 2169 b ≈ **271 B** |
| raw line rate (512 ns window) | 2.19 Gbps | **4.23 Gbps** |
| true line rate (×1.12) | ≈ 2.4 Gbps | **≈ 4.74 Gbps** |
| SerDes lane | single ≤ 10 G, ~4× headroom | **single ≤ 10 G, ~2× headroom** |

**INT8 does not push Alternative A out of its lane class** — it stays a single
sub-10 Gbps lane. The throughput mode can afford INT8.

### QAM / optical SNR

Line rate ≈ doubles (2.19 → 4.23 Gbps) but stays far below a 10 G lane's
capacity — **spend baud, not constellation order**. No higher-order modulation
is forced, so the **optical-SNR penalty of INT8 over INT4 is ≈ 0 dB** in
practice (the extra bit-planes ride available symbol rate). In the `gcb-wiki/13`
bitplane framing this is 8 signed planes instead of 4 — ~2× the per-λ plane
load or ~2× the λ count, still tiny in absolute terms.

### The Purple compression hypothesis ([[GCB-034]])

| representation | true line rate | vs the 2048 Gbps internal operand bus |
|---|---:|---:|
| INT4 post-requant | ≈ 2.4 Gbps | ≈ **850×** |
| **INT8 post-requant** | ≈ 4.74 Gbps | ≈ **432×** |
| INT32 partial (Alt B, P=1) | ≈ 17.9 Gbps | ≈ 114× |

**The "electrical compute domain is an enormous compression boundary"
hypothesis survives D2 = INT8** — ~2.6 orders of magnitude, roughly half the
INT4 ratio.

### Alternative B

Alt B carries the raw INT32 `acc_tile` — **V3 does not change its 1024 B
payload**. But the requantisation that runs *after* the remote accumulate on the
accumulator node inherits this verdict: its final hand-off to the next layer is
**INT8**, not INT4 (≈ 271 B, ≈ 4.74 Gbps), for the same accuracy reasons.

---

## Settling measurement (what V3 cannot run here)

Requires a representative activation trace from the target model:

1. **`q_clip` assertion rate** at `OUT_W ∈ {4, 8}`, `SCALE_MODE ∈ {PER_TILE,
   PER_ROW, PER_COL}` — non-zero at INT4 is a direct falsification.
2. **Per-block `r_max` distribution** (max/median ratio) across a real layer —
   confirms or refutes the 4–50× assumption and the `r_max ≤ 1.56×` INT4 bound.
3. **End-to-end accuracy** (perplexity / task metric) of the full model with the
   optical hand-off at INT4 vs INT8 vs full precision — the ground truth for the
   25 dB budget.
4. **Outlier-axis check** — are outliers row- or column-structured → sets
   `PER_ROW` vs `PER_COL`.

---

## What this feeds

* **`GCB-034` D2** → provisionally **INT8, PER_ROW, RNE**; logged with the four
  settling measurements above. Not closed.
* **`GCB-034` payload / Purple** → Alt A payload 143 B → **271 B**; line rate
  2.4 → **4.7 Gbps**; compression ratio ≈ 850× → **≈ 432×** (hypothesis holds).
* **[[GCB-035]]** → add the INT8 column to the line-rate and lane-mapping
  tables (raw 4.23 Gbps, true ≈ 4.74 Gbps, still ≤ 10 G).
* **TKT-019 V4 (link budget)** → per-lane requirement rises to **≥ 4.74 Gbps**
  for Alt A INT8; Alt B unchanged at ≥ 17.9 Gbps (P = 1).
* **`GCB-034` D3** → unchanged; small-`K` line-rate blow-up ([[GCB-035]] V2) now
  compounds with the 1.9× INT8 payload (e.g. attention `Q·Kᵀ` at `K = 128`,
  INT8: ~266 Gbps per-tile — even more firmly a super-tile-aggregation case).

## Execution constraints honored

- [x] Quantisation-error model for INT4 vs INT8 block FP, with the SQNR
  identity and a per-`r` table.
- [x] Block dynamic-range headroom under realistic (outlier-bearing) activation
  statistics; `SCALE_MODE` sensitivity.
- [x] Falsifiable threshold (25 dB SQNR budget → `r_max ≤ 1.56×` INT4 /
  `≤ 24.9×` INT8) and the settling measurements that confirm it.
- [x] Consequences propagated to payload, line rate ([[GCB-035]]), QAM/SNR,
  the Purple compression ratio, and Alternative B's post-accumulate hand-off.

---
## Telemetry & Evaluation
*(V3 execution for TKT-019 — no PBG vector, no PBG-O disposition; verdict feeds
the Falsification Test. `GCB-034` stays `open | pending`.)*
**Final State:** `open | pending`
