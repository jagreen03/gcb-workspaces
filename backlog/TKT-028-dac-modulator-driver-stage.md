---
id: TKT-028
title: "DAC-to-modulator analog driver stage — close the gap task3_physical_bom.md surfaced with no candidate at all"
date_created: 2026-09-12
status: done
telemetry_color: pending
tags:
  - backlog
  - hardware
  - phase-1-bench
  - photonics
  - analog
---

# Objective

`task3_physical_bom.md` §1 surfaced a gap with **no candidate of any kind**
on file: the analog stage between `greencoyote_dac_if.sv`'s 14-bit digital
word and whichever optical intensity modulator §1 eventually selects.
Today nothing bridges this — the RTL drives a digital parallel bus; a real
modulator needs an analog drive voltage at its own required level and
bandwidth. This ticket exists to put a first real candidate on file, not
to leave the gap open indefinitely.

**Scope note (spike mode, 2026-09-12):** this ticket's original "Out of
scope" explicitly excluded selecting the modulator itself. Under this
session's spike-mode authorization (principal-engineer autonomy to make
component decisions and unblock downstream work), that boundary is
deliberately lifted here — the modulator architecture decision is made
below as part of resolving this ticket, not deferred to a separate one.

## Engineering rationale (resolution, 2026-09-12)

### Decision 1 — Modulator: linear VOA, not LiNbO₃ Mach-Zehnder

**Chosen: a linear variable optical attenuator (VOA).** Reasoning:

1. `task3_physical_bom.md` §1 already establishes that this bench's
   modulator only needs to cover the `fire`-strobe cadence, **not** a
   high-speed telecom line rate. That removes an MZ modulator's one
   genuine advantage (GHz-class bandwidth) as relevant to this
   application at all.
2. An MZ modulator's transfer function is a cosine-squared interferometric
   response — getting any usable linear region out of it requires an
   active bias-point (quadrature) servo. That is a whole bias-stabilization
   subsystem Phase I does not otherwise need, and adding it runs directly
   against Phase I's own stated purpose: de-risking the summation/
   ratiometric-cancellation physics with the **fewest** new unknowns, not
   the most.
3. A VOA's attenuation-vs-control-voltage response is commonly a smooth,
   monotonic function over its usable range, with no interferometric lock
   required — a much more direct path to the §1 8-bit-linear target
   (directly, or via a straightforward calibration lookup table), and
   easier to drive from a COTS DAC as this ticket's own brief asked.

This is an architectural decision, not a vendor pick — the specific VOA
part number remains `[TBD — vendor survey not performed]`, consistent with
`task3_physical_bom.md`'s own honesty-tiering convention (specialty
photonics SKUs are not claimed with unearned confidence).

### Decision 2 — DAC-to-modulator driver stage

- **DAC candidate**: Analog Devices **AD9767** (dual 14-bit, parallel
  CMOS-input). `greencoyote_dac_if.sv`'s own header comment already
  anchors its bus timing on "DAC5672/AD9767-class" generic timing — that
  was an illustrative analogy when written, not a selection. This ticket
  elevates it to an actual `[CANDIDATE — parametric fit]`: a real,
  well-known part whose timing the RTL was already modeled on, matching
  the 14-bit parallel bus width exactly.
- **Driver candidate**: a precision, low-offset CMOS op-amp in the general
  class Analog Devices markets for DAC-output signal conditioning (e.g.,
  an AD8605-class part), configured as a current-to-voltage converter
  (AD9767 is current-output) followed by a scaling/level-shift stage onto
  the VOA's control-voltage range. **Not** a high-speed telecom
  modulator-driver IC — Decision 1 means the drive target is a low-bandwidth
  analog control voltage, not a GHz-class RF drive, so that class of part
  would be the wrong voltage range and unnecessary added noise risk.
- **Explicit blocking dependency, not an oversight**: the exact op-amp
  gain/scaling-resistor values depend on the selected VOA's own
  control-voltage range, which is still `[TBD]`. This is recorded as an
  honest, open blocker, not silently assumed.

## Deliverable (closed)

`task3_physical_bom.md` §1 updated with both decisions above: the
modulator row now reads "DECIDED: linear VOA" with rationale; a new row
documents the AD9767 DAC candidate and the op-amp driver candidate, with
the gain-calculation blocker stated explicitly. The document's summary
table and closing "Net effect" paragraph are updated to match.

## Out of scope (as amended)

- The specific VOA vendor/part number — remains `[TBD]`, per this
  program's standing honesty-tiering discipline; this ticket makes the
  architecture call, not the SKU pick.
- The exact driver op-amp gain/scaling values — blocked on the VOA
  part/range above.
- Any RTL change to `greencoyote_dac_if.sv` — none needed; this is a
  purely physical-layer decision.

## Telemetry

No PBG grade — pre-procurement BOM-completion task, not a verified RTL
deliverable.

**Status:** `done`.
