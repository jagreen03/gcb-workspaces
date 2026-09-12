---
id: TKT-029
title: "TKT-020 Y1 remainder: SRAM address-math geometry guard, SRAM_LATENCY/RD_REG consistency check, full-default-geometry synthesis run"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - audit-followup
  - rtl
  - sram
  - synthesis
---

# Objective

`TKT-020`'s Yellow Team finding Y1 ("Hard-coded assumptions that fracture at
5nm / OpenROAD") listed 5 items. Item 2 (`gcb_max_reduce` `REG_STAGES`) was
genuinely closed by `GCB-031`/`.032`. Item 1 was partially closed this
session (CDC synchronizer attributes + the first real SDC artifact in
`gcb-wdm-transceiver`, for the slice that has committed RTL - see
`TKT-020`'s own disposition note, 2026-09-12). **This ticket is the
remainder**: items 3, 4, and 5, none of which had their own ticket before
now. Each is independently actionable; this ticket does not require all
three to land together.

## Item 3 — power-of-two geometry baked into SRAM address math

**Finding (TKT-020 Y1 item 3, restated, not re-derived):**
`gcb_tensor_operand_sram.sv` computes an address as
`MACRO_AW'(wr_sub) * MACRO_AW'(DEPTH_K) + MACRO_AW'(wr_k)`, justified
in-source as "DEPTH_K / SUBTILES are powers of two, the multiply is a
shift." No elaboration-time check enforces that premise. A floorplan-driven
non-power-of-two tiling (reticle fit, SRAM-compiler aspect ratio, redundancy
columns) would silently turn that "free" shift into a real multiplier in
the address path with no warning, AND invalidates the "lossless cast"
reasoning elsewhere in the same file's comments.

**Required work:**
1. Confirm, by direct inspection of `gcb_tensor_operand_sram.sv` and
   `gcb_tensor_sram_controller.sv`, every parameter this "powers of two"
   premise actually depends on (at minimum `DEPTH_K`, and whatever
   `SUBTILES`-equivalent parameter the comment refers to - confirm the
   exact name before writing the guard, do not assume it matches the
   wording above verbatim).
2. Add an elaboration-time guard (`initial begin : g_assert ... $fatal ...
   end`, matching every other module in this repo's own established
   pattern - do not invent a new style) that checks each such parameter is
   a power of two and `$fatal`s with a clear message naming the offending
   parameter and its actual value if not.
3. Do **not** generalize the address math to handle non-power-of-two
   geometry speculatively - no concrete non-power-of-two requirement exists
   yet, and a speculative general multiplier would be solving a problem
   that does not exist while adding real area/timing cost to a path that
   TKT-020 Y1 item 3's own severity table rates as "present in locked
   baseline" but not yet load-bearing. A loud, explicit guard is the
   proportionate fix; silently accepting non-power-of-two geometry is not.

**Acceptance criteria:** the guard fires (verified by actually instantiating
with a non-power-of-two parameter value and observing the `$fatal`, not by
reading the code and assuming it would) for at least one deliberately
invalid geometry, and does not fire for the existing default/tested
geometries (confirmed via the existing regression suite, unmodified,
staying green).

## Item 5 — `SRAM_LATENCY` / `RD_REG` consistency

**Finding (TKT-020 Y1 item 5, restated):** `SRAM_LATENCY` (the controller's
own flop-pipe parameter) and `RD_REG` (the macro's own read-latency
parameter) are independent parameters with no consistency check between
them. The synthesizable path *requires* `RD_REG=1` synchronous macros at
5nm (a multi-MiB async register file is not physically realizable); nothing
forces `SRAM_LATENCY` to track the macro's true latency, and a real 1W1R
compiler macro may in fact be 2-cycle. A mismatch presents stale
`sram_rdata` to `gcb_tensor_broadcast_fabric` as if it were valid - silently,
with a matching `done`/`sram_valid`.

**Required work:**
1. Trace, by direct inspection (not assumption), exactly which modules own
   `SRAM_LATENCY` and `RD_REG` today, and confirm whether they are already
   required to be passed as the SAME value at instantiation anywhere, or
   are genuinely independent as the finding claims.
2. If genuinely independent: add an elaboration-time guard enforcing the
   real constraint between them (likely `SRAM_LATENCY == RD_REG`, but
   confirm the actual required relationship from the controller's own
   pipeline logic before asserting a specific equation - do not guess).
3. If a real SRAM compiler macro with `RD_REG` > 1 is ever targeted, this
   ticket does not itself add multi-cycle controller support - that is a
   separate, larger RTL change and explicitly out of scope here. This
   ticket's job is to make a *mismatch* loud (a guard), not to add support
   for every possible latency.

**Acceptance criteria:** same standard as item 3 - the guard is shown to
actually fire on a constructed mismatch, and the existing regression suite
stays green with the real (matched) values.

## Item 4 — full-default-geometry synthesis run

**Finding (TKT-020 Y1 item 4, restated):** the Doc 05/06/12 sizes are
*default parameters* (`M_TOTAL=4096`, `N_TILE=1024`, `K_STEPS=256`, a 4 MiB
B-tile). Every Yosys run in `TKT-012`/`TKT-016`'s own history used
`-chparam`/`chparam` to *shrink* the geometry (`K_TOTAL 512`, `N_TILE 64`)
because full geometry was reportedly too slow to elaborate. No run has ever
actually been attempted at the real default size.

**Required work:** this is a **measurement task, not an RTL change** (same
epistemic posture as `TKT-019.9`'s own cost-evaluation precedent - a
measurement ticket gets no PBG grade, per `gcb-wiki/14`).

1. Identify the real top-level module(s) and default parameter set Doc
   05/06/12 actually specify as the production geometry (do not assume -
   confirm against the docs and the RTL's own default parameter values,
   which may have drifted since Y1 was written).
2. Attempt the identical `sim/yosys068_bless/` pipeline
   (`read_verilog; chparam <real defaults>; hierarchy -check; proc;
   opt_clean; check -assert; select -assert-count 0 t:$dlatch t:$dlatchsr
   t:$sr; stat`) at that real default geometry, not a shrunk one.
3. Report the actual outcome honestly either way: if it completes, record
   real elaboration time and cell counts (this would be new, genuine
   evidence Y1 item 4's concern no longer holds - several modules in this
   program have had real elaboration-scaling fixes land since Y1 was
   written, e.g. `gcb_dwdm_payload_mux`/`demux`'s flat-vector fix,
   `gcb_rx_digital_recombiner`'s unrelated-but-similar-class fixes - it is
   plausible but NOT yet proven that those fixes also rescue this path).
   If it does not complete in a reasonable bound (document what bound was
   used and why), that CONFIRMS Y1 item 4 as still open and is itself a
   valid, reportable result - do not extend the timeout indefinitely
   chasing a "pass."

**Acceptance criteria:** a real run was attempted (not estimated) at the
real default geometry and its outcome - success with numbers, or a
documented, bounded non-completion - is recorded in this ticket's own
Execution Log, labeled with the correct epistemic tag (`PROVEN` only if it
actually completed and was checked; `OPEN DEFECT` if it did not).

## Out of scope

- Item 1's remaining piece (GDDR7 PHY / optical SerDes clock-domain
  constraints) - no committed RTL exists yet for those domains; tracked
  under `TKT-020` itself, not here.
- `TKT-019.19` (data-plane reset-aliasing) - explicitly not this ticket's
  concern, per standing Architect instruction to leave it alone.
- Any new feature work. This ticket hardens/measures the existing,
  already-committed baseline; it does not extend it.

## Telemetry & Evaluation

No PBG grade at creation - this ticket is open, unexecuted work. Telemetry
to be assigned per item as each is actually closed (items 3/5 are
correctness-hardening guards and can be graded normally once landed; item 4
is a measurement and should follow `TKT-019.9`'s no-grade precedent for
pure measurement work).

**Final State:** `open | pending`
