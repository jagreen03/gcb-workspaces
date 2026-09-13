---
id: GCB-041
title: "Single-slope TDC/calibration digital back-end (Part 10/11): real, bit-exact-verified RTL, but never integrated into greencoyote_top.sv - SS_CAL coefficient BRAM has no RTL implementation anywhere"
date_created: 2026-09-13
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - register-map
  - adr-005
  - single-slope
  - architecture-conflict
---

# Objective

Found during the same open-ended sweep that produced [[GCB-040]], by
extending that ticket's spec-signal-vs-RTL cross-check from the two
`IRQ_CTRL` bits to every `signal:`-named field in `registers.yaml`.
**Unlike GCB-040, this is not a small, safe, unilaterally-fixable gap —
it is a real finding about the program's most rigorously-gated
subsystem, filed for disposition, not fixed here.**

## What was found, checked directly at every step

1. `registers.yaml` defines `SS_CAL_IDX` (0xB4), `SS_CAL_DATA` (0xB8),
   `SS_RAMP_TIMING` (0xBC) with real `signal:`/`output:` names
   (`r_ss_cal_ch`/`ss_cal_ch`, etc.) — confirmed present in the
   **generated** package too (`rtl/generated/greencoyote_regmap_pkg.sv`
   has real `ADDR_SS_CAL_IDX`/`ADDR_SS_CAL_DATA`/`ADDR_SS_RAMP_TIMING`
   localparams and field masks), so this is not a stale/abandoned spec
   draft — `regen.py`'s own output is current for these fields.
2. `greencoyote_pilot_regs.sv` (the hand-written register-decode module
   — see [[GCB-040]] for why it's hand-written, not generated) has
   **zero** implementation of any of these signals — no declaration,
   no reset, no write/read-decode, no output port. Confirmed by direct
   grep against the whole file, not one region of it.
3. `greencoyote_ss_calib.sv` itself carries a header comment asserting
   this BRAM lives in `greencoyote_pilot_regs.sv` ("SS_CAL coefficient
   BRAM (greencoyote_pilot_regs)") — the RTL's own comment describes a
   dependency that does not exist.
4. `greencoyote_ss_calib.sv`'s `c2`/`c1`/`c0` inputs (the per-channel
   calibration coefficients) are plain module ports with **no driver
   anywhere** — because:
5. **Neither `greencoyote_ss_tdc.sv` nor `greencoyote_ss_calib.sv` is
   instantiated anywhere in `gcb-rtl`**, `greencoyote_top.sv` included —
   confirmed by grep across every `.sv` file in `rtl/`, not just `top`.
   Both exist and are genuinely, rigorously verified **standalone**
   (`RTL_REPORT.md` §1: 10,000/10,000 bit-exact against
   `sim/golden_ss_readout.py`, via `sim/run_ss_tb.sh`) — the verification
   claim is real; the system-integration claim `gcb-wiki/16` made
   alongside it (now corrected, see below) was not.

## Why this is NOT necessarily a "bug" the way GCB-040 was

Phase I's currently-integrated bench receiver path uses
`greencoyote_adc_if`/`greencoyote_dac_if` (both genuinely instantiated
in `greencoyote_top.sv`, confirmed). `greencoyote_ss_tdc`/`_calib` are
explicitly documented (by `gcb-wiki/16` itself, pre-existing text, not
added by this ticket) as "the complete digitization back-end for the
**Phase II (silicon-target)** receiver path" — i.e., a future
integration target, not the active one. Never being wired into `top`
today is consistent with that framing, not necessarily an oversight.

**What IS a clear error, independent of the integration-timing
question:** `gcb-wiki/16` stated as present-tense fact that calibration
coefficients "arrive per-channel from the `SS_CAL` coefficient BRAM in
`greencoyote_pilot_regs.sv`" — that BRAM does not exist, in that file or
anywhere else. This part has been corrected in `gcb-wiki/16` directly
(see commit below) since it is a documentation-accuracy fix, not an
architectural decision.

## Why this ticket does not attempt an RTL fix

Implementing the `SS_CAL`/`SS_RAMP_TIMING` register block and wiring
`greencoyote_ss_tdc`/`_calib` into `greencoyote_top.sv` would mean:
adding a new clock domain (6 GHz Gray-counter / CML island) into the
integrated pilot top; deciding how 64 channels' worth of `fire[ch]`
strobes and indexed readout connect to the existing MMIO/interconnect
fabric; and doing this on the one subsystem `gcb-spec/ai-agents/README.md`
itself names as the most rigorously gated, `CONDITIONAL GO` part of the
entire program, explicitly held short of `GO` pending a commercial
noise-simulator closure this repository set does not have. This is
squarely an architectural decision requiring the System-Architect
persona's full state-compression context (per `gcb-spec/ai-agents/`'s
own triad discipline) and the Architect's own ratification of *when*
Phase II integration should happen — not a finding to act on
unilaterally during an open-ended documentation/backlog sweep.

## Execution Log

- Corrected `gcb-wiki/16_hardware_parts_systems_specification.md`'s
  Part 11 entry (Completion status, Interfaces, Dependencies) to state
  the real, verified-standalone-only status instead of the prior
  (incorrect) integrated-system claim.
- No RTL changed. No register-map changed. No integration attempted.

## Out of scope

- Implementing the `SS_CAL`/`SS_RAMP_TIMING` register block.
- Instantiating `greencoyote_ss_tdc`/`greencoyote_ss_calib` into
  `greencoyote_top.sv`.
- Any claim about whether ADR-005's `CONDITIONAL GO` should change —
  unaffected by this finding either way; this is about digital
  integration timing, not the analog noise-closure gate.
- A full audit of every remaining `registers.yaml` signal against RTL
  beyond what this pass and [[GCB-040]] already covered (the `r_dma_*`
  signals were also flagged by the same cross-check but resolved as a
  naming-convention difference, not a gap — `greencoyote_streaming_dma.sv`
  implements its own local register decoder under shorter local names;
  confirmed by direct read before concluding anything).

---
## Telemetry & Evaluation

No PBG grade — a finding reported for disposition, explicitly not a
build or a closed decision (same category as `TKT-019.6`/`.7`'s
architecture-only tickets).

**Final State:** `open | pending`. The one safe, unilaterally-correctable
part (the documentation overclaim) is fixed (`gcb-wiki@7555a92`, pushed,
verified). The substantive question — when/whether to integrate Phase
II's digital receiver backend into the pilot top — is the Architect's
to decide, not this ticket's.
