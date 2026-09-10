---
id: TKT-019
title: "EPIC — Optical WDM transport: validate or falsify the provisional GCB-034 transport contract, then scale the WDM PHY on it"
date_created: 2026-09-09
rechartered: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - epic
  - rtl
  - photonic
  - wdm
  - transport
  - orange-team
  - falsification
---

# Objective

**Re-chartered 2026-09-10 under the Orange-Team method ([[TKT-000]]).** The
first job of this Epic is **not** to build a bigger PHY — it is to
**validate or falsify the provisional [[GCB-034]] optical-transport contract**
before any WDM/QAM physics is committed. Only a contract that survives
falsification earns the PHY-scaling build described further down this ticket.

**The hypothesis under test (from [[GCB-034]], provisional):**

* **D1 = POST-REQUANTIZATION** — the optical boundary sits immediately after
  `gcb_tile_requantize`; the payload is the INT4/INT8 `q_tile` + block-float
  `q_scale` (≈ 140 B/tile at INT4).
* **D4 = FULL-K LOCAL REDUCTION** — the entire `K_TOTAL` contraction completes
  electrically on one node; the optical layer never carries an INT32 partial
  sum.
* **Cadence** — one transaction per `K_STEPS = K_TOTAL / K_MAX` advancing
  cycles (512 at the `gcb-wiki/06` production geometry), deterministically
  periodic (0 SRAM read stalls, [[TKT-025]]).
* **The Purple claim** — the electrical compute domain is an enormous
  compression boundary (local high-precision K-reduction + `32b→4/8b`
  requantization), so the optical transport can operate on a representation
  ~1000× smaller than the fabric's internal 256 GB/s operand bus.

If — and only if — these survive, this Epic then expands the transport layer
from the fixed dual-colour datapath to a parameterised **multi-wavelength DWDM
link** with a stated link budget and error rate, over the boundary **digital
bit-plane mapper → wavelength router → per-λ modulator drive / DWDM packager →
optical channel model → RX deskew / recombine → digital reconstruction**, on the
`gcb-wiki/13` bit-plane Tx doctrine (TKT-015) as the golden reconstruction
model. Sub-stories: the falsification pass (below) first; then λ-count
parameterisation, link-budget model, deskew scaling, channel/BER model, the
top-level link TB, a new wiki doctrine page.

## The Falsification Test (Story 1 gate)

`GCB-034` is a **testable hypothesis, not a fact**. This section is the test.
It runs *before* the PHY-scaling sub-stories and its outcome — **contract
survives** or **contract replaced** — is what moves `GCB-034` off
`open | pending`.

### Required validations

| # | validate | method | falsifies the contract if… |
|---|---|---|---|
| V1 | **Actual post-requantization payload size** — `q_tile` + `q_scale` + framing/metadata, not the idealised 128 B | bit-accurate wire-format layout from `gcb_tile_requantize` outputs at `SCALE_MODE ∈ {PER_TILE, PER_ROW, PER_COL}`; count every carried bit | the real transaction is materially larger than ≈ 140 B (e.g. scale + framing + sign/zero-point overhead pushes it toward the INT8 or `acc_tile` regime) |
| V2 | **Transaction cadence** at the target clock | derive `K_STEPS` for the production and test geometries; confirm the requantizer emits exactly one tile per `K_STEPS` with the [[GCB-028]] `MAXRED_REG_STAGES` latency; confirm 0-stall periodicity end-to-end (re-run `test_compute_e2e.py` instrumentation) | emission is not periodic, or the effective period is a small multiple of `K_STEPS` that changes the rate-averaged bandwidth by >2× |
| V3 | **Numeric consequences of `OUT_W`** (D2) | accuracy of a representative downstream layer fed INT4 vs INT8 `q_tile`; block-float dynamic-range headroom under real activation statistics | INT4 loses accuracy beyond the model's tolerance → the payload must be INT8 (or wider), moving the bandwidth and the minimum QAM order |
| V4 | **Optical PHY requirements implied by the contract** | from V1–V3: required aggregate Gb/s, per-λ rate, minimum QAM order / SNR, framing/FEC overhead, at the demo λ count, against the existing `optical_mesh_dpi` channel and the `gcb-wiki/13` reconstruction algebra | the implied PHY cannot hit the required BER / eye margin within a plausible link budget, i.e. the contract asks for a link that does not close |
| V5 | **Scaling / partitioning constraints** of D4 = full-K local | model workloads larger than one node's K-reduction capacity; quantify what full-K-local forces on tensor/pipeline/data partitioning and horizontal scale-out (see `GCB-034-LOOK-AROUND.md`) | full-K-local makes a required workload class un-partitionable or forces an unacceptable per-node SRAM / compute ceiling → Alternative B is mandatory for that class |

Each validation closes with a one-line **CONTRACT HOLDS** / **CONTRACT FAILS
(→ revise `GCB-034` decision Dx)** verdict and the number that decided it.

### The Counterfactual — Alternative B (what we falsify against)

The provisional contract is only meaningful if there is a concrete alternative
it could lose to. **Alternative B: K-split + partial sums.**

* **Dataflow:** `K_TOTAL` is partitioned across `P` nodes; each node reduces its
  `K_TOTAL / P` slice locally and emits **INT32 `acc_tile`s** (1024 B each);
  the optical layer carries these partial sums to an accumulator node that sums
  the `P` contributions before requantization.
* **Transport consequence:** payload **1024 B** (vs ≈ 140 B) — **~7.3× wider**
  per transaction — at a cadence up to `P×` higher (`K_STEPS / P` cycles per
  emit). Rate-averaged optical bandwidth rises from ≈ 0.27 GB/s toward
  **≈ 2 GB/s × P** — the ~1000× compression collapses to roughly `140:1`
  (per node) and less across the aggregate.
* **What it buys:** workloads whose `K_TOTAL` exceeds one node's electrical
  reduction budget become tractable; horizontal scale-out along K is native;
  per-node SRAM / accumulator width is bounded. It re-introduces the wide-payload
  regime the [[GCB-032]] 38-max-slew-DRV observation warns about, at the
  transmit serializer.
* **The test:** for each workload class, does full-K-local (contract) close the
  link budget *and* fit the node, or does Alternative B's wider/faster transport
  become unavoidable? A workload class where Alternative B wins **falsifies D4**
  for that class and the contract must carry both regimes (a mode bit), or scope
  down to the class where full-K-local holds.

**Neither the contract nor Alternative B is adopted here.** This Epic measures
which one each workload class needs; `GCB-034` is updated with the result and
only then leaves `open | pending`.

## "Product Ready for Presentation" — PBG analysis

*The PBG analysis, Context, and "Green" Target below describe the **PHY-scaling
build that follows a surviving contract**. If the Falsification Test replaces a
provisional GCB-034 decision, revisit this section before the build sub-stories
start. PBG grading here is the standard R³ vector (Spec / Quality / Emergence);
the Orange method is how the Falsification Test is run, not a grade — see
[[TKT-000]] / [[GCB-034]] §"Methodology note".*

* **Green (target) — the artifact that proves it demos.** An end-to-end DWDM
  link simulation (Cocotb + the existing `optical_mesh_dpi` channel) that
  transports a full INT16 operand block over **N wavelengths** and reconstructs
  it **bit-exact** per the `gcb-wiki/13` `S_ij = (L_ij + 2·M_a[i] + 2·M_b[j] −
  K)/4`, `Y = Σ W_i·W_j·S_ij` algebra, accompanied by a link-budget table and a
  BER / eye-margin figure at the demo lane count. One `make link` printing
  `RECONSTRUCT OK`, aggregate Gb/s, and per-λ margin is the proof.

* **Blue (engineering) — the methodology that guarantees Green.** The
  `gcb-wiki/13` equations as a frozen Python reference; layered Cocotb TBs for
  each stage (`gcb_bitplane_tx_mapper` unchanged, `gcb_wavelength_router`,
  `gcb_dwdm_tx_packager`, `gcb_dwdm_deskew`, `gcb_rx_digital_recombiner`) each
  proven against it; then one top link TB over the channel model; the
  wavelength count a real parameter with a swept regression (2 → N λ); a new
  `gcb-wiki/14_wdm_transport_link_budget.md` with a line-number traceability
  table to the RTL, in the style of doc 13; `sim/lint.sh` + `sv2v`→Yosys
  elaboration as hard gates on every sub-story.

* **Purple (emergence) — Cyclopter / serendipitous reuse.** The scaled RX
  reuses the TKT-016 `gcb_max_reduce` for QAM constellation slicing and the
  TKT-015 signed-bitplane algebra for the per-λ operand mapping — **the same
  Tx doctrine that documented the 2-colour link now parameterises the N-colour
  link with no new encoding math**. Each sub-story closes with a PBG vector the
  Cyclopter scavenger (TKT-013) ingests, and the TKT-014 KG gap-analysis spike
  is re-run across the new transport RTL against doc 13 / doc 02 to catch
  undocumented silicon before the demo — the transport layer's readiness is a
  live pgvector query, not a checklist.

## Context & Constraints

* **Current State:**
  * `gcb-wdm-transceiver/rtl/` holds the fixed datapath: `gcb_bitplane_tx_mapper`
    (frozen, doc 13), `gcb_wavelength_router`, `gcb_dwdm_tx_packager`,
    `gcb_dwdm_deskew`, `gcb_dwdm_transceiver_top`, `gcb_qam_datapath_top`,
    `gcb_rx_digital_recombiner`. `sim/optical_mesh_dpi.cpp` is the channel model
    used by `tb_dwdm_dualmode_top`.
  * `gcb-wiki/13` (TKT-015) formalises the INT4→signed-bitplane Tx map and the
    algebraic INT16 reconstruction, with a worked `Y = 11` example and a
    line-number traceability table. `gcb-wiki/02` is the receiver architecture.
  * The colour / lane count is effectively hard-wired (color0/color1, I/Q
    plane0..3). There is no link-budget model and no BER instrumentation.
* **Constraint:** `gcb_bitplane_tx_mapper` and any other frozen-list interface
  stay frozen — scaling happens around them, not through their ports. New RTL is
  pure SV-2017, `sim/lint.sh`-clean, Cocotb ≥ 1.9, `sv2v`→Yosys elaboration
  checked. The `gcb-wiki/13` reconstruction algebra is the invariant: any λ
  count must reconstruct bit-exact or the sub-story is Red. PBG / Cyclopter
  prompt-layer protocols stay out of the RTL repo (`gcb-wiki/04`).

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The Epic target is Green through Blue-grade engineering** — a parameterised
link that still satisfies the doc 13 algebra at every wavelength count.

* **Green (target):** the end-to-end N-λ link sim reconstructing bit-exact per
  doc 13, with a link-budget table and a BER/eye figure; every sub-story
  lint/elab/Cocotb-green; a new `gcb-wiki/14` doctrine page.
* **Blue:** the doc-13 reference model, layered per-stage TBs with the frozen
  mapper unmodified, the swept λ regression, the traceability table, sub-story
  PBG telemetry to Cyclopter.
* **Yellow (reject):** bumping the λ count with a magic constant and a TB that
  only checks 2 colours; a "link budget" with no channel model behind it.
* **Red (reject):** altering the frozen mapper's ports or the doc-13
  reconstruction algebra to make more wavelengths "fit"; a recombiner that
  passes only because the channel model is lossless and noiseless.
* **Purple / Light-gray:** a full coherent DSP RX with adaptive equalisation and
  carrier recovery is Purple / a later Epic; keeping the link hard-wired at two
  colours (Light-gray) caps the demo's transport story.

**Explicitly out of scope (separate tickets / Epics):**
1. The compute datapath upstream of the mapper — TKT-017.
2. Physical / photonic layout and the PIC GDS — TKT-018 / `gcb-pic-core`.
3. A full coherent-DSP receiver (CD/PMD equalisation, carrier phase recovery).
4. Forward-error-correction code design beyond a modelled BER hook.
5. Optical-domain device physics (laser, modulator, fibre) beyond the existing
   `optical_mesh_dpi` behavioural model.

## The "Green" Target

1. Wavelength count and per-λ I/Q lane assignment made real parameters across
   `gcb_wavelength_router`, `gcb_dwdm_tx_packager`, `gcb_dwdm_deskew`,
   `gcb_rx_digital_recombiner`; `gcb_bitplane_tx_mapper` untouched.
2. A frozen Python reference implementing the `gcb-wiki/13` `S_ij` / `Y`
   algebra; per-stage Cocotb TBs proving each module against it.
3. A top-level link Cocotb TB over `optical_mesh_dpi` that transports a full
   INT16 operand block over N wavelengths and asserts bit-exact reconstruction;
   λ swept 2 → N in a regression.
4. A link-budget table (per-λ power, insertion loss, crosstalk, margin) and a
   BER / eye-margin measurement at the demo λ count, checked in.
5. `gcb-wiki/14_wdm_transport_link_budget.md` — doctrine for the scaled link,
   LaTeX equations, a line-number traceability table to the RTL, one worked
   end-to-end multi-λ example; added to the `gcb-wiki/README.md` index with
   reciprocal links from docs 02 and 13.
6. `bash sim/lint.sh` exit 0 with every new/changed top; Cocotb
   `TESTS=… PASS=… FAIL=0`; wired into `sim/lint.sh` and the guarded
   `sim/run_tb.sh` stanza; `sv2v`→Yosys elaboration clean and latch-free.
7. One `make link` entry point printing `RECONSTRUCT OK`, aggregate Gb/s and
   per-λ margin — the presentation artifact. Diff confined to the transport RTL
   + TBs + sim-list edits + `gcb-wiki/14` + the doc 02/13 back-links.

---
## Execution Log

**Story order (re-charter 2026-09-10):**

1. **Falsification Test (this ticket, §"The Falsification Test")** — run V1–V5
   against the provisional [[GCB-034]] contract and the Alternative B
   counterfactual; each closes with `CONTRACT HOLDS` / `CONTRACT FAILS (→ revise
   Dx)`. Outcome updates `GCB-034` and moves it off `open | pending`.
2. `GCB-034-LOOK-AROUND.md` — the orthogonal-discovery pass feeds V5 and may
   surface further validations before the build.
3. **PHY-scaling build sub-stories `TKT-019.x`** — only after a surviving
   contract: λ-count parameterisation, link-budget model, deskew scaling,
   channel/BER model, top-level link TB, `gcb-wiki/14`.

*(Populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution — standard R³ PBG vector; the Orange method is
the Falsification Test's procedure, not a grade.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
