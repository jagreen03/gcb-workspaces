---
id: TKT-027
title: "ADC SPI command-word verification — de-risk greencoyote_adc_if.sv's CMD_WORD default before procurement"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - hardware
  - phase-1-bench
  - rtl
  - spi
---

# Objective

`greencoyote_adc_if.sv` defaults `CMD_WORD = 16'h0000` and never meaningfully
encodes a command — it just clocks 16 SCLK pulses and samples MISO. This is
correct for some 12-bit SAR ADC families (no config register needed to
produce a conversion) and wrong for others (a real command/config word is
required, and `16'h0000` would be garbage on that bus). `task3_physical_bom.md`
§3.3 flags this explicitly as "the single highest-value item in this whole
BOM to verify before any purchase."

**Mode:** build, refine. The deliverable is a go/no-go on the RTL's current
default against one real datasheet, not a broader ADC architecture study.

## Task

1. Pull the datasheet for the §3.3 candidate SAR ADC family (the
   TI "ADS786x"-class candidate currently on file in
   `task3_physical_bom.md`, or whatever specific part the Architect has
   since selected).
2. Confirm whether that part's SPI-compatible read actually requires a
   non-zero command/configuration word, or whether a bare clock-and-sample
   sequence (matching `greencoyote_adc_if.sv`'s current behavior) is
   sufficient.
3. If a real command word is required: update `CMD_WORD` (and `FRAME_BITS`
   / `RESULT_BITS` if the part's frame shape differs from the current
   16-bit frame / 12-bit result assumption) to match, and re-run the
   existing `greencoyote_tb.sv` / `sim/run_pilot_tb.sh` regression to
   confirm the change doesn't break the DAC/ADC roundtrip test.
4. If no command word is required: close this ticket with that confirmation
   on file (the current default stands, verified rather than assumed).

## Deliverable

Either (a) an RTL diff to `greencoyote_adc_if.sv` + a passing
`sim/run_pilot_tb.sh` re-run, or (b) a documented confirmation that the
current `CMD_WORD=16'h0000` default is correct for the selected part, with
the datasheet section cited.

## Out of scope

- Selecting the ADC part itself if none has actually been chosen yet —
  this ticket verifies a specific candidate's protocol fit; it does not
  perform the down-select `task3_physical_bom.md` §3.3 itself left open.
- Any change to `FRAME_BITS`/`RESULT_BITS`/`SCLK_DIV`/`SETTLE_CYCLES`
  beyond what the selected part's own datasheet timing requires.

## Telemetry

No PBG grade on drafting — this is a pre-procurement verification task. If
it closes with an RTL change, a normal testbench-pass confirmation (not a
full PBG grade) is the bar, since this isn't a new falsification campaign.

**Status:** `open | pending`.
