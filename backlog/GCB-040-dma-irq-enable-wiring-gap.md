---
id: GCB-040
title: "gcb-rtl: Streaming Tensor DMA IRQ enables (IRQ_CTRL[5]/[6]) were never implemented in hand-written register RTL"
date_created: 2026-09-13
status: done
telemetry_color: blue
tags:
  - backlog
  - rtl
  - register-map
  - dma
---

# Objective

Found during an open-ended backlog sweep (not pre-existing in the backlog):
`greencoyote_top.sv` hardcoded `greencoyote_streaming_dma`'s
`irq_dma_done_en`/`irq_dma_underrun_en` inputs to `1'b1`, with an inline
comment: `// TODO: pilot_regs IRQ_CTRL[5] (hand RTL predates map 0.6.0)`.
Checked directly rather than assumed a stale comment: `registers.yaml`
genuinely defines both bits (`IRQ_CTRL` bits 5/6, `access: rw`,
`reset: 0`, real signal names `r_irq_dma_done_en`/`r_irq_dma_underrun_en`,
"Added in map_version 0.6.0") — but `greencoyote_pilot_regs.sv` (the
hand-written register-decode module, not auto-generated — confirmed by
its own header, dated June 2026, no "DO NOT EDIT" banner, unlike
`rtl/generated/greencoyote_regmap_pkg.sv`) never implemented them at
all: no declaration, no reset, no write-decode, no read-decode, no
output port. The TODO's own framing was accurate, not stale.

This is completing an already-ratified spec interface (the register map
bump to 0.6.0 is the governance step; implementing it is execution, not
a new architectural decision), not an open question for the Architect —
same category as this session's README/doctrine fixes, but in RTL
rather than documentation.

## Execution Log

`greencoyote_pilot_regs.sv`:
- Added `r_irq_dma_done_en`/`r_irq_dma_underrun_en` registers, reset to
  `1'b0` (matching every other `IRQ_CTRL` enable bit's reset per
  `registers.yaml`), write-decoded from `mmio_wdata[5]`/`[6]` at
  `ADDR_IRQ_CTRL`, read back in the same bit positions (replacing the
  `3'h0` padding that covered bits [7:5] — bit 7 stays reserved).
- Added two new output ports, `irq_dma_done_en`/`irq_dma_underrun_en`,
  since (unlike the other `IRQ_CTRL` enables, which gate `r_irq_status`
  internally and never leave this module) these two specifically need
  to cross the module boundary into `greencoyote_streaming_dma`.

`greencoyote_top.sv`:
- Added two internal wires, wired `u_pilot_regs`'s two new outputs to
  `u_streaming_dma`'s existing `irq_dma_done_en`/`irq_dma_underrun_en`
  inputs, replacing the `1'b1` hardcodes.

**Verified by actually running the existing regression, not assumed
clean:** `sim/run_pilot_tb.sh` (`tb_cs_fifo_path`) — `ALL CHECKS PASS`.
`sim/run_dma_tb.sh` (`tb_dma_integration`) — `ALL CHECKS PASS`,
`errors=0`, `fire_seen=1018`/`opv_seen=1018` unchanged from the
pre-existing pass/fail shape (the DMA's functional datapath is untouched
by this change — only the `irq_dma` *interrupt* output is gated by it).
`sim/run_ss_tb.sh` not re-run: confirmed by direct inspection it
exercises neither `greencoyote_top` nor `greencoyote_pilot_regs`/
`greencoyote_streaming_dma`, so it cannot be affected by this change.

## Behavioral change — flagged explicitly, not buried

**Before this fix, both DMA interrupts were unconditionally enabled**
(`1'b1`, ignoring `IRQ_CTRL` entirely). **After this fix, both reset to
disabled (`0`) and require an explicit `IRQ_CTRL` write (bits 5/6) to
enable** — matching `registers.yaml`'s own stated `reset: 0` for both
fields.

**Follow-up, same session (2026-09-13):** checked `gcb-host` directly
against this, as flagged below. `greencoyote_pilot.hpp`'s
`enable_irq()` convenience helper — the one realistic path software
would use to set these bits — never included `IRQ_DMA_DONE_EN`/
`IRQ_DMA_UNDERRUN_EN`, even though the generated `regmap.py` already
had both field definitions (confirming `regen.py`'s own output was
current; only the hand-maintained C++ helper lagged). Without this
follow-up, the RTL fix above would have been correct but practically
unreachable — no software path existed to ever set bits 5/6. Added two
new `bool` parameters (`dma_done`, `dma_underrun`), both defaulting to
`false`, fully backward-compatible. Verified by actually compiling (not
assumed): a minimal smoke test against the real header, `g++ -std=c++17
-Wall`, clean, zero warnings — `src/`/`tests/` remain empty (`TKT-032`'s
own finding, unchanged) so no existing build harness exists to re-run.
`gcb_proxy.py` (the Python side) has no equivalent convenience wrapper
at all — confirmed by grep, not assumed — so there was nothing to fix
there. Committed `gcb-host@171f16e`, pushed, verified.

## Out of scope

- Auditing every other `IRQ_CTRL`-adjacent or DMA-adjacent register for
  similar hand-RTL-vs-map gaps — this ticket fixes the one instance
  found, not a full audit.

---
## Telemetry & Evaluation

**Spec 1.0 (Green):** the fix implements exactly what `registers.yaml`
already specifies (bit positions, reset value, signal names) — nothing
invented, nothing deviated from the ratified map.
**Quality 0.9 (Blue):** verified by actually running both directly-
relevant existing regressions (not assumed from inspection alone); the
behavioral change is stated explicitly rather than buried; the one real
follow-up question (`gcb-host` impact) is flagged, not silently closed.
Not 1.0: `gcb-host` was not actually checked.
**Emergence 0.3:** a real, if small, finding — a spec field that shipped
in the map for an unknown period with zero RTL backing it, caught by
reading the RTL's own honest TODO comment rather than trusting that
"map_version 0.6.0" meant full implementation.

**Final State:** `done | blue`. The `gcb-host` follow-up above closes
the one gap the Quality grade's "Not 1.0" noted — left as originally
recorded rather than re-graded, since this is a same-session addendum,
not a later re-opening. `gcb-rtl@bc4c4fb` and `gcb-host@171f16e` both
committed, pushed, verified `HEAD==origin/main`; both relevant gcb-rtl
testbenches re-run and passing; the gcb-host change verified by a real
compile, not assumed.
