---
id: GCB-037
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
  - link-budget
  - architecture
---

# Objective

Execute **TKT-019 falsification validation V4 — the optical link budget** for
the provisional [[GCB-034]] contract. Do the line rates from V1–V3 ([[GCB-035]],
[[GCB-036]]) imply a link that **closes** — hits the required BER within a
plausible power / loss budget at the `gcb-wiki/13` bit-plane modulation format —
or does the contract ask for a link that does not close?

Numbers only; no PHY is designed. `GCB-034` stays `open | pending`.

---

## Inputs (from V1–V3)

| mode | payload | true line rate (per K-split link) | cadence |
|---|---:|---:|---:|
| **Alt A** — post-requant, full-K local, **D2 → INT8** ([[GCB-036]]) | ≈ 271 B | **≈ 4.74 Gbps** | 1 / 512 ns, periodic |
| **Alt B** — K-split INT32 partial, per K-partner | ≈ 1027 B | **≈ 17.9 · P Gbps** (P = 1 → 17.9; P = 4 → 71.7) | 1 / (512/P) ns |
| Alt B accumulator inbound (P links) | — | **≈ 17.9 · P² Gbps** (P = 4 → ≈ 286 Gbps) | — |

Framing/FEC = **64b/66b + KP4** RS(544, 514, t=15) already folded into the true
line rate ([[GCB-035]]).

---

## Link-budget method

### Target BER

KP4 corrects up to 15 symbol errors / 544-symbol codeword. Standard IEEE 802.3
assumption: **pre-FEC BER ≤ 2.4 × 10⁻⁴** (random errors) → **post-FEC ≤ 10⁻¹³…⁻¹⁵**.
Net coding gain of KP4 on a 2-PAM AWGN channel ≈ **6.0 dB** at these operating
points.

### Modulation — the `gcb-wiki/13` doctrine format

Signed-bitplane **antipodal (2-PAM-class), ~1 bit/symbol/plane**, I + Q. This is
the lowest-order, most power-efficient format available; V3 already concluded
"spend baud, not constellation order."

Coherent 2-PAM `BER = Q(√(2·Eb/N0))`:

| operating point | required `Eb/N0` |
|---|---:|
| pre-FEC BER 2.4 × 10⁻⁴ (KP4 input) | **7.85 dB** |
| BER 10⁻¹² **without** FEC | 13.9 dB |
| ⇒ KP4 net coding gain | **6.05 dB** |

### Loss / power inventory (integrated WDM photonics, ring-modulator, educational)

| element | dB |
|---|---:|
| comb source per-λ power `P_tx` | **0 dBm** (assumed) |
| ring modulator insertion loss | 1.5 |
| on-die waveguide routing | 2.0 |
| WDM mux (ring / AWG) | 2.0 |
| die ↔ fiber / interposer coupling (×2 facets) | 3.0 |
| WDM demux | 2.0 |
| adjacent-channel crosstalk penalty | 1.0 |
| aging + temperature margin | 2.0 |
| **total insertion loss** | **13.5 dB** |
| **received power at the photodiode** | **−13.5 dBm** |

Fiber propagation for a co-packaged / rack-scale fabric interconnect (< 50 m,
1310/1550 nm) is < 0.02 dB → treated as 0. Ring thermal-tuning power is **not**
in this budget (flagged below).

### Receiver sensitivity vs rate

Anchor: integrated Ge-PD + TIA, **−16 dBm OMA at 4.74 Gbps** for pre-FEC
BER 2.4 × 10⁻⁴ (educational mid-value; a real number needs the PIC process).
Sensitivity scales with noise bandwidth: `P_sens = −16 + 10·log10(R / 4.74)` dBm.

| line rate | required sensitivity |
|---|---:|
| 4.74 Gbps (Alt A INT8) | **−16.0 dBm** |
| 17.9 Gbps (Alt B P = 1) | **−10.2 dBm** |
| 35.8 Gbps (Alt B P = 2) | −7.2 dBm |
| 71.7 Gbps (Alt B P = 4) | **−4.2 dBm** |

---

## Alternative A (INT8, throughput mode) — link budget

```
received power           −13.5 dBm
required sensitivity      −16.0 dBm  (4.74 Gbps, 2-PAM, pre-FEC 2.4e-4)
--------------------------------------
link margin              +2.5 dB     -> LINK CLOSES
```

Sensitivity analysis: a **+3 dBm** comb line → **+5.5 dB** margin; low-loss
rings (−1 dB routing, −0.5 dB per mux) → **+4.5 dB**. **Alt A closes with
2.5 – 8 dB margin** across plausible integrated-photonics assumptions, on
**one wavelength**.

**V4 → CONTRACT HOLDS for the throughput regime.**

---

## Alternative B (K-split, latency mode) — link budget

At **per-tile granularity on one wavelength**:

| P | line rate / link | sensitivity | received | **margin** |
|---:|---:|---:|---:|---:|
| 1 | 17.9 Gbps | −10.2 dBm | −13.5 dBm | **−3.3 dB → does NOT close** |
| 2 | 35.8 Gbps | −7.2 dBm | −13.5 dBm | **−6.3 dB → does NOT close** |
| 4 | 71.7 Gbps | −4.2 dBm | −13.5 dBm | **−9.3 dB → does NOT close** |

**Alt B does not close at per-tile granularity on a single wavelength at any P.**
Closing it needs one of: a **+4 to +10 dBm** per-λ source (beyond an integrated
comb line), **> 8 dB** of insertion-loss reduction, or —

### The lever: spread the 1024 B over `N_λ` wavelengths

Per-λ rate = `17.9·P / N_λ` Gbps. Bring it back to the Alt-A regime
(≈ 4.74 Gbps/λ, +2.5 dB margin):

| regime | `N_λ` needed | vs Alt A (1 λ) |
|---|---:|---:|
| Alt B, P = 1 (single-link) | **4 λ** | 4× |
| Alt B, P = 4, per K-split link | **16 λ** | 16× |
| Alt B, P = 4, accumulator inbound (286 Gbps) | **≈ 60 λ** | **≈ 60×** |

60 λ on a 50 GHz C-band grid ≈ 3 THz — fits C-band (≈ 4.4 THz), *just*; on a
100 GHz grid it needs C + L. **Alt B P = 4 latency mode consumes most of a
single-band comb for one accumulator node.**

**V4 → CONTRACT HOLDS for the latency regime *conditionally*** — only by
provisioning **≈ 60× the wavelength capacity** the throughput mode needs. This
is the concrete number behind the dual-regime PHY mandate ([[GCB-034-LOOK-AROUND]]
C9): the PHY is sized by the latency mode's wavelength count, not the throughput
mode's.

---

## KP4 FEC is load-bearing, not just overhead

Without KP4, every sensitivity figure worsens by **6.05 dB**:

```
Alt A INT8 without FEC:  margin +2.5 − 6.05 = −3.6 dB  -> does NOT close
```

**KP4 is mandatory for link closure in both modes.** The V1/V2 decision to fold
in 64b/66b + KP4 was not just an overhead accounting choice — it is the 6 dB
that makes Alt A close at all.

## Modulation order — stay at 2-PAM / QPSK

Moving to PAM4 to shrink `N_λ` costs ≈ **4.8 dB** SNR (denser levels), 16-QAM
more. The Alt-A link that closes with +2.5 dB at 2-PAM **does not close at
PAM4** under this budget. Confirms V3: carry rate via **baud and wavelength
count**, never constellation order.

---

## V4 verdict

| regime | result |
|---|---|
| **Alt A** — INT8, full-K local, throughput | **LINK CLOSES** — 1 λ, 2-PAM/QPSK + KP4, +2.5 to +8 dB margin. **V4 HOLDS.** |
| **Alt B** — K-split, latency | **CLOSES ONLY BY SPENDING WAVELENGTHS** — does not close per-tile on 1 λ (−3.3 dB at P = 1 … −9.3 dB at P = 4); needs 4 λ (P = 1) → 16 λ / link → **≈ 60 λ** at the P = 4 accumulator. **V4 HOLDS conditionally** — PHY must provision ≈ 60× the throughput mode's λ count. |
| **FEC** | KP4 is **load-bearing** (6.05 dB); Alt A does not close without it. |
| **Modulation** | **2-PAM / QPSK only**; PAM4+ breaks closure. |

The contract does **not** ask for a link that cannot exist — but it asks for a
**dual-regime PHY whose wavelength provisioning is set by the latency mode**,
and whose closure depends on KP4 and the doctrine's low-order modulation.

---

## What V4 cannot resolve here

1. **Exact PIC-process loss / power** — modulator type (ring vs MZM), source
   (integrated comb vs per-λ DFB), mux technology, coupling scheme. These are
   `gcb-pic-core` / TKT-018 territory; V4 uses literature-typical educational
   values.
2. **`optical_mesh_dpi` is behavioural** — a real BER / eye figure needs it
   parameterised with the 13.5 dB loss + −16 dBm sensitivity + KP4 model above
   (a `TKT-019.x` build sub-story).
3. **Ring thermal-tuning power** — not budgeted; a real concern for the
   ring-based WDM assumed here, and it grows with `N_λ` (so the latency mode
   pays it ≈ 60×).

---

## What this feeds

* **TKT-019 V4** → **HOLDS** (throughput); **HOLDS conditionally** (latency,
  ≈ 60 λ). No "link that cannot close."
* **`GCB-034`** → add: link closes for Alt A on **1 λ** with **2.5–8 dB**
  margin; Alt B needs **≈ 4·P … 60 λ**; **KP4 mandatory**; **2-PAM/QPSK only**.
  Do not close — V5 (partitioning) is the last validation.
* **TKT-019 PHY-scaling sub-stories** → the swept λ regression must reach
  **≥ 60 λ** to cover the latency mode; the link-budget table uses these
  numbers; the `gcb-wiki/14` doctrine page records the dual-regime provisioning.
* **`GCB-034-LOOK-AROUND` C9** → quantified: the irreversible PHY commitment is
  a **≈ 60× wavelength-capacity** decision, plus ≈ 60× ring-tuning power for the
  latency mode.
* **`GCB-034` D3** → small-`K` layers (V2) at INT8 (V3) already demand
  super-tile aggregation; V4 adds that their per-tile line rate would need even
  more λ to close — reinforcing D3 = aggregate for small-K.

## Execution constraints honored

- [x] Required aggregate / per-λ rate from V1–V3: Alt A ≈ 4.74 Gbps (1 λ);
  Alt B ≈ 17.9·P Gbps/link, ≈ 17.9·P² Gbps at the accumulator.
- [x] Minimum modulation order / SNR: **2-PAM/QPSK**, `Eb/N0` ≥ 7.85 dB pre-FEC;
  PAM4+ breaks closure.
- [x] Framing/FEC: 64b/66b + KP4, **6.05 dB** net coding gain — load-bearing.
- [x] BER / eye margin vs a plausible link budget: **Alt A +2.5…8 dB → closes**;
  **Alt B −3.3…−9.3 dB per-tile on 1 λ → closes only via ≈ 4·P…60 λ**.
- [x] Assessed against the `optical_mesh_dpi` channel + `gcb-wiki/13` algebra
  (parameterisation deferred to a build sub-story).

---
## Telemetry & Evaluation
*(V4 execution for TKT-019 — no PBG vector, no PBG-O disposition; verdict feeds
the Falsification Test. `GCB-034` stays `open | pending`; V5 outstanding.)*
**Final State:** `open | pending`

**Update (2026-09-10, later the same evening):** V5 ([[GCB-038]]) ran
after this ticket and completed the Falsification Test; `GCB-034` was
then ratified (`done | green`), incorporating this V4 link-budget result
directly into its Ratified Dual-Regime Contract table. This ticket's own
`Final State` is left as originally recorded, per standing discipline
against rewriting locked history — it is a validation record, not the
decision ticket, and does not self-close.
