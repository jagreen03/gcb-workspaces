---
id: TKT-019
title: "EPIC — Optical WDM transport: scale the WDM PHY and transceiver logic on the bitplane doctrine"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - epic
  - rtl
  - photonic
  - wdm
  - transport
---

# Objective

Expand the **optical transport layer** of GreenCoyote-Bay AI Fiber Math — the
WDM PHY and its transceiver logic — from the current fixed dual-colour datapath
to a parameterised **multi-wavelength DWDM link** with a stated link budget and
error rate. This Epic owns the system boundary **digital bit-plane mapper →
wavelength router → per-λ modulator drive / DWDM packager → optical channel
model → RX deskew / recombine → digital reconstruction**, and builds directly on
the `gcb-wiki/13` bit-plane Tx doctrine (TKT-015): the signed-bitplane antipodal
encoding and the `S_ij` / `Y` INT16 reconstruction algebra are the golden model
the scaled link must still satisfy. It spawns per-stage sub-stories (λ-count
parameterisation, link-budget model, deskew scaling, channel/BER model, the
top-level link TB, a new wiki doctrine page).

## "Product Ready for Presentation" — PBG analysis

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
*(To be populated during execution — spawns sub-stories TKT-019.x)*

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
