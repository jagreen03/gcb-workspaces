---
id: TKT-027
title: "ADC SPI command-word verification — de-risk greencoyote_adc_if.sv's CMD_WORD default before procurement"
date_created: 2026-09-12
status: done
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

## Findings (spike-mode resolution, 2026-09-12)

**Go — no RTL change required.** The TI ADS786x family
(ADS7866/7867/7868/7869 — single- and dual-channel, 12-bit SAR, the
candidate already on file in `task3_physical_bom.md` §3.3) is a
deliberately minimal-protocol part: it needs **no write/configuration
phase at all** for a basic single-channel conversion read. `CS` low begins
a conversion; the result is clocked out MSB-first on the data-out line
over the frame; there is no command byte the master must send to make
that happen. This is, functionally, exactly the "bare clock-and-sample"
protocol `greencoyote_adc_if.sv` already implements — `CMD_WORD`'s actual
value genuinely does not matter for this part, because the ADC never
interprets anything arriving on its input line as a command in the first
place. The frame shape also matches: `FRAME_BITS=16` / `RESULT_BITS=12`
(12 valid bits within a 16-SCLK-pulse frame) is consistent with this
family's standard framing.

**Confidence caveat, stated plainly:** this finding is based on this
family's well-established, publicly documented protocol as generally
known, not a line-by-line read of a freshly pulled datasheet PDF during
this session. Per `task3_physical_bom.md`'s own epistemic-tiering
convention, treat this as the engineering "go" call needed to unblock RTL
work now, **not** a substitute for a final datasheet cross-check at
incoming-inspection time once a specific ADS786x part number and package
are actually on an order — if that final check ever disagrees with this
finding, this ticket's own conclusion is what gets revised, not silently
worked around.

**Regression status:** no RTL was touched (none was needed). Re-ran the
existing baseline to confirm it still stands: `sim/run_pilot_tb.sh` →
`greencoyote_tb.sv`'s own `IO1: SPI SAR ADC roundtrip` and
`IO2: parallel DAC` checks both PASS, `tb_cs_fifo_path.sv` → `ALL CHECKS
PASS`. Note this confirms the RTL's *internal* consistency (the testbench's
own simulated ADC model necessarily matches whatever protocol the RTL
drives, by construction) — it does not, and cannot, independently prove a
real physical ADS786x part behaves identically; that's the datasheet
judgment call above, not something simulation alone can establish.

## Deliverable (closed)

(b) — a documented confirmation that the current `CMD_WORD=16'h0000`
default is correct for the `task3_physical_bom.md` §3.3 candidate family,
per the Findings above.

## Out of scope (unchanged)

- Selecting the ADC part itself beyond the family-level candidate already
  on file — a specific part number/package within ADS786x (and the final
  datasheet cross-check flagged above) remains open.
- Any change to `FRAME_BITS`/`RESULT_BITS`/`SCLK_DIV`/`SETTLE_CYCLES` —
  none was needed.

## Telemetry

No PBG grade — pre-procurement verification task, not a falsification
campaign or a new RTL deliverable.

**Status:** `done`.
