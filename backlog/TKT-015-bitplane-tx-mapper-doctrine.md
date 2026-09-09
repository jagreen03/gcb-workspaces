---
id: TKT-015
title: "Bit-plane Tx mapper doctrine — document the INT4↔optical encoding TKT-014 found undocumented"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - doctrine
  - wiki
  - photonic
  - dwdm
---

# Objective

Plug the knowledge gap TKT-014 quantified: write `gcb-wiki/13_bitplane_tx_mapper.md`,
a mathematically complete account of the **INT4 → signed bit-plane optical
mapping** — the per-colour × I/Q lane assignment the transmit path drives and the
**algebraic INT16 reconstruction** the receive path inverts — exactly as
implemented by `gcb-wdm-transceiver/rtl/gcb_bitplane_tx_mapper.sv` and consumed by
`gcb_qam_datapath_top` / `gcb_wavelength_router`. The document reflects the
existing RTL; it does not redesign it.

## Context & Constraints

* **Current State:**
  * The TKT-014 spike (`scripts/kg_gap_analysis_spike.py`) found
    `gcb_bitplane_tx_mapper.sv` is the **loneliest RTL module in the design** —
    nearest doctrine chunk at `cos_dist 0.9289 / cos_sim 0.0711`, past the
    `τ = 0.92` gap threshold. `grep -niE 'bit[- ]?plane' gcb-wiki/*.md` returns
    **3 incidental one-line mentions** (a V2.0 drive-scheme row in
    `03_dual_mode_integration.md`, one line each in `goal.md` and `intent.md`)
    and **zero doctrine sections**.
  * The encoding is the **load-bearing bridge between the INT4 tensor datapath
    and the optical transport**: three RTL files depend on it
    (`gcb_bitplane_tx_mapper`, `gcb_qam_datapath_top`, `gcb_wavelength_router`)
    and it currently lives only in RTL header comments.
  * `gcb-wiki` is at doc 12 (`12_tensor_sram_allocation_strategy.md`); this is
    **doc 13**. Companion docs: `01_streaming_sequence.md`,
    `03_dual_mode_integration.md` (§ "Retained by V1.0" / the V2.0 bit-plane
    drive row), `05_photonic_memory_dataflow.md` (the bit-plane Tx buffer SRAM
    budget line), and the `gcb_dwdm_pkg.sv` lane/signal names.
  * `gcb_bitplane_tx_mapper.sv` is authoritative for this ticket — every claim
    in the doc must be traceable to a line of that file (or its two consumers).
* **Constraint:** Documentation-only, `gcb-wiki` only. The doc must be **derived
  from and verified against the RTL** — each equation, bit-field, lane name, and
  width tied to a specific `gcb_bitplane_tx_mapper.sv` line. **No RTL change**
  (if writing the doc surfaces an RTL defect, that is a separate ticket).
  Markdown-lint clean (`gcb-wiki/10` / the `architecture-doctrine` workspace
  lint task). House style of the existing `NN_title.md` notes: `**Level:**`
  header, companion-docs line, a fixed-quantities table, ASCII diagrams only
  where they clarify.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-015 is Green** — a knowledge gap TKT-014 measured, closed
cleanly and verifiably.

* **Green (target):** `13_bitplane_tx_mapper.md` that is *mathematically
  complete*: the INT4 → signed bit-plane plane-extraction (operand width, plane
  count, sign handling) with its governing equation; the full per-colour × I/Q
  lane-assignment table (`a_c0_i`, `a_c0_q`, `a_c1_i`, `a_c1_q` and the B-side
  equivalents) tied to the mapper's ports; the algebraic INT16 reconstruction
  (weighted plane sum) with a worked numeric example carried end-to-end
  (INT4/INT16 value → planes → lanes → decode); and a **traceability table**
  mapping each claim to `gcb_bitplane_tx_mapper.sv:<line>`. Reviewed against the
  RTL; markdown-lint clean.

* **Blue:** the above, plus the cross-references reconciled — `03`'s V2.0 row,
  `05`'s SRAM budget line, and the `goal.md` / `intent.md` mentions all updated
  to point at doc 13, and the bit-plane buffer sizing shown consistent across
  `05` and `13`.

* **Yellow (reject):** a prose sketch with no equations, no lane table, and no
  RTL line references — documentation theatre that a re-run of the TKT-014 scan
  would still flag as thin.

* **Red (reject):** editing `gcb_bitplane_tx_mapper.sv` (or a consumer) to match
  a doc the author guessed at; or documenting an idealised encoding that
  diverges from the shipped RTL.

* **Purple / Light-gray:** an RTL-comment-extraction doc generator is Purple / a
  later ticket. Leaving the mapping undocumented (Light-gray) is exactly the gap
  TKT-014 already quantified.

**Explicitly out of scope (separate tickets):**
1. Any RTL change to `gcb_bitplane_tx_mapper` or its consumers.
2. The receive-side QAM slicer's internal math (`02_receiver_architecture.md`
   territory) beyond the reconstruction formula this doc must state.
3. A doc-generation / RTL-comment-extraction tool.
4. Re-documenting the wider DWDM-PHY cluster (`gcb_color_mux`, `gcb_dwdm_deskew`,
   `gcb_wavelength_router`) — this ticket is the bit-plane mapping only.

## The "Green" Target

1. `gcb-wiki/13_bitplane_tx_mapper.md` in house style (`**Level:**`, companion
   docs, a fixed-quantities table parameterised on `gcb_dwdm_pkg` / the mapper).
2. **INT4 → signed bit-plane decomposition:** the exact plane extraction the RTL
   performs — operand width, number of planes, sign / two's-complement handling
   — with the governing equation.
3. **Per-colour × I/Q lane-assignment table:** every transmit drive signal
   (`a_c0_i`, `a_c0_q`, `a_c1_i`, `a_c1_q`, B-side equivalents) mapped to its
   `(colour, component, bit-plane)` tuple exactly as `gcb_bitplane_tx_mapper.sv`
   wires it.
4. **Algebraic INT16 reconstruction:** the weighted-sum formula the receive path
   inverts, plus a worked example taking one concrete INT4 (and one INT16) value
   through encode → lanes → decode and back.
5. **Traceability table:** each equation / lane / width → a
   `gcb_bitplane_tx_mapper.sv:<line>` reference (and `gcb_qam_datapath_top` /
   `gcb_wavelength_router` where they consume the encoding).
6. Cross-references wired: `03`'s V2.0 row, `05`'s SRAM budget line, and the
   `goal.md` / `intent.md` mentions now link to doc 13.
7. Markdown-lint clean; reads consistently with docs `11` / `12`.
8. **Falsifiable close:** a re-run of `scripts/kg_gap_analysis_spike.py` shows
   `gcb_bitplane_tx_mapper.sv` is no longer the loneliest module — its nearest
   cross-type `cos_dist` drops below `τ` — i.e. the gap is measurably closed.

---
## Execution Log
*(To be populated during execution)*
* **Agent ID:**
* **Commands Run:**
* **Artifacts Touched:**

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
