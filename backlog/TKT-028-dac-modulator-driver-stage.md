---
id: TKT-028
title: "DAC-to-modulator analog driver stage — close the gap task3_physical_bom.md surfaced with no candidate at all"
date_created: 2026-09-12
status: open
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

**Mode:** build, refine. The deliverable is a concrete driver-stage
candidate and its own parametric requirement, ready for a vendor quote —
explicitly not a simulation or RTL task.

## Task

1. Pin the actual DAC part (§1 of `task3_physical_bom.md` does not name one
   either — `greencoyote_dac_if.sv`'s header only cites "DAC5672/AD9767-class"
   as an *illustrative* timing analogy, not a selected part) that converts
   the 14-bit parallel digital bus into an analog voltage/current.
2. Derive the drive-level requirement the §1 modulator candidate (once
   selected — this may be blocked on that choice; if so, document the
   blocking dependency rather than guessing) actually needs: voltage swing,
   bandwidth, linearity.
3. Identify a candidate driver/amplifier stage (a line driver, a
   high-speed op-amp, or a dedicated modulator-driver IC, depending on what
   §1's modulator choice turns out to need) bridging the DAC's output to
   that requirement.
4. Record the result as a new §1 sub-entry in `task3_physical_bom.md`,
   using the same `[CANDIDATE — parametric fit]` / `[TBD]` honesty-tiering
   convention the rest of that document already uses — do not present a
   guessed part as settled.

## Deliverable

An updated `task3_physical_bom.md` §1 with the DAC part and driver-stage
candidate (or an explicitly documented blocking dependency on the §1
modulator down-select, if that's what actually blocks this).

## Out of scope

- Selecting the modulator itself (`task3_physical_bom.md` §1's own open
  item) — this ticket may depend on that choice; it does not make it.
- Any RTL change to `greencoyote_dac_if.sv`.

## Telemetry

No PBG grade — pre-procurement BOM-completion task, not a verified RTL
deliverable.

**Status:** `open | pending`.
