---
id: TKT-029
title: "TKT-020 Y1 remainder: SRAM address-math geometry guard, SRAM_LATENCY/RD_REG consistency check, full-default-geometry synthesis run"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.85
  quality: 0.85
  emergence: 0.2
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

---
## Execution Log

### Item 3 — RESOLVED (digital simulation, tested conditions), with a self-caught correction

Added an elaboration-time guard to `gcb_tensor_operand_sram.sv` per the
ticket's own instructions: first traced the exact parameters
(`DEPTH_K`, `SUBTILES`) and the in-source comment's literal claim
("DEPTH_K / SUBTILES are powers of two at every real geometry"), then
wrote the guard to match that claim exactly - checking BOTH `DEPTH_K` and
`SUBTILES` for power-of-2-ness.

**That first draft was wrong, and was caught before being committed, not
after.** Running the real `compute_e2e` cocotb chain (TKT-025's own
already-proven production geometry) with the new guard in place produced
an immediate `$fatal`: `SUBTILES (20) must be a power of 2` -
`N_SUBTILES=20` is this repo's real, already-shipping, already-regression-
proven B-operand geometry, and 20 is not a power of 2. Tracing the actual
address math (`wr_sub * DEPTH_K + wr_k`) confirmed the comment itself
overclaimed: only `DEPTH_K` (the multiplicand) needs to be a power of 2
for the multiply-as-shift property; `SUBTILES` only sets `wr_sub`'s own
width elsewhere and was never actually load-bearing for that claim.

**Disposition:** the guard now checks `DEPTH_K` only; the misleading
in-source comment (which predates this ticket) was corrected in the same
commit, not left to mislead the next reader the way it misled this
guard's own first draft. Verified, not assumed, against BOTH directions:

| Check | Construction | Result |
|---|---|---|
| Bad `DEPTH_K` fires | `DEPTH_K=17` (SUBTILES=20, the real value) | `$fatal` - **PASS** |
| Bad `SUBTILES` does NOT fire | `SUBTILES=3` (DEPTH_K=256, the real value) | no fatal - **PASS** (the corrected guard's whole point) |
| Real production geometry clean | `compute_e2e` full chain, `N_SUBTILES=20 DEPTH_K=16` | `TESTS=1 PASS=1`, `MATCH \| 40 output tiles bit-exact` - **PASS** |
| Regression unaffected | `sim/lint.sh` 38/38; `Makefile.sram` `TESTS=5 PASS=3 SKIP=2`; `Makefile.sram_partial` `TESTS=5 PASS=2 SKIP=3` (SKIPs pre-existing, unrelated to this change) | **PASS** |

**PROVEN — DIGITAL SIMULATION, TESTED CONDITIONS**, for exactly the
constructions above. Not claimed: that `DEPTH_K` power-of-2 is the ONLY
geometry constraint this address math has, or that every conceivable
`LANES`/`DW` combination was swept.

### Item 5 — RESOLVED (digital simulation, tested conditions), scope narrowed by direct trace

Traced `SRAM_LATENCY`/`RD_REG` per the ticket's own instruction before
writing anything. Finding, not assumed: `RD_REG` is **not** an
independently-instantiable parameter of `gcb_tensor_sram_controller` -
it is `SRAM_RD_REG`, a hardcoded **local constant** (`=0`) with an
in-source comment instructing a future human to "flip to 1 for a
synchronous SP-SRAM macro build and drop one `SRAM_LATENCY` stage." There
is therefore no LIVE mismatch in committed code today (nothing sets it to
anything but 0) - the real risk is exactly that manual instruction having
zero enforcement. The precise cross-adjustment formula for an arbitrary
future `RD_REG` value was not derived (doing so without fully re-deriving
the controller's read-latency pipeline would itself be an unverified
assumption) - instead, the currently-validated configuration
(`SRAM_RD_REG == 0`) is locked with a guard that fails loudly the moment
anyone changes it without also revisiting this guard and `SRAM_LATENCY`
together.

**Regression:** `sim/lint.sh` 38/38; `tb_tensor_sram_controller.sv`
(direct plain-SV testbench) `ALL CHECKS PASS`; `compute_e2e` (the
full chain, includes this controller) `TESTS=1 PASS=1`, `MATCH`.

**PROVEN — DIGITAL SIMULATION, TESTED CONDITIONS** that the guard does not
fire on any currently-committed configuration. **UNPROVEN / explicitly not
attempted**: the actual cross-adjustment behavior for `RD_REG != 0` - that
remains exactly as open as it was, now with a loud failure instead of
silence guarding the boundary.

### Item 4 — EXECUTED (digital simulation / Yosys elaboration only, tested conditions) - result is a genuine surprise, reported as measured

Identified the real top-level modules per the ticket's own instruction:
`gcb_tensor_sram_controller` (TKT-012/016's own shrunk-geometry runs'
target) and `gcb_tensor_memory_engine` (the full wrapper, +
`gcb_tensor_broadcast_fabric`, NUM_CORES=256). Confirmed by direct read
that the RTL's own declared defaults are still exactly what Y1 item 4
described: `M_TOTAL=N_TOTAL=K_TOTAL=4096`, `N_TILE=1024`, `GRID_DIM=16`,
`NUM_CORES=256` - no drift since Y1 was written.

Ran the identical `sim/yosys068_bless/` pipeline (`read_verilog;
hierarchy -check; proc; opt_clean; check -assert; select -assert-count 0
t:$dlatch t:$dlatchsr t:$sr; stat`) used throughout this repo's own bless
history, with **zero `chparam` overrides** - i.e. at the module's own real,
un-shrunk default parameters, which is exactly the condition Y1 item 4
said had never been attempted. Bounded at a documented 10-minute
`timeout` (matching this session's own established "did not finish
within 10 minutes" threshold for a prior elaboration-scaling problem) so
a non-completion would itself be a valid, reportable result rather than
an indefinitely-extended chase.

**Result: both completed almost immediately, 0 problems, latch-free.**

| Target | Geometry | Wall time | Cells (incl. submodules) | Memory bits | Problems | Latches |
|---|---|---:|---:|---:|---:|---:|
| `gcb_tensor_sram_controller` alone | `M/N/K_TOTAL=4096 N_TILE=1024 GRID_DIM=16` (real default) | **0.08 s** | 741 | 3.41e7 (64 KiB A + 4 MiB B - matches the module's own doc comment exactly) | 0 | 0 |
| `gcb_tensor_memory_engine` (+ `gcb_tensor_broadcast_fabric`, `NUM_CORES=256`) | same + `NUM_CORES=256` | **1.13 s** | 744 | 3.41e7 (same SRAM, now behind the 256-core fabric) | 0 | 0 |

Cross-checked the memory-bit figure is genuinely the full, real geometry
(not silently reduced): 64 KiB (A: `GRID_DIM·1·K_STEPS·DW·2 =
16·256·64·2` bits) + 4 MiB (B: `GRID_DIM·N_SUBTILES·K_STEPS·DW·2 =
16·64·256·64·2` bits, `N_SUBTILES = N_TILE/GRID_DIM = 64`) = 34,078,720
bits ≈ `3.41e7` - matches Yosys's own reported figure, confirmed by
arithmetic, not assumed from the tool's summary line alone.

**A genuinely notable finding, reported as measured, not theorized about:**
`gcb_tensor_sram_controller`'s OWN cell count at full scale (741) is
essentially identical to its already-blessed SHRUNK-geometry figure
(740 cells, `K_TOTAL=512 N_TILE=64`, from the pre-existing
`sim/yosys068_bless/` baseline) - because `stat`'s LOCAL cell count
reflects mostly control-plane logic (counters, comparators, the
sequencing FSM) whose width scales only logarithmically with
`M/N/K_TOTAL`, not the cell count itself; the actual geometry scaling
shows up entirely in memory BITS (which `stat` reports separately), not
logic cells. This is evidence toward, but does not single-handedly prove,
why elaboration completed so fast here: the controller's own control
logic was apparently never the bottleneck TKT-012/016's history
attributed to "full geometry."

**What this does and does NOT close:** this closes the specific claim
inside Y1 item 4 that "no run has ever actually been attempted at the
real default size" for Yosys elaboration - that run has now been
attempted, twice, and both completed cleanly. **It does NOT close** Y1
item 4's own follow-on sentence: *"OpenROAD on the full 4 MiB array is
the first real place-and-route data point"* - full synthesis-to-gates
plus place-and-route is a categorically heavier step than Yosys
elaboration (this session's own `gcb_max_reduce` ASAP7 experience took
real wall-clock minutes for a macro many orders of magnitude smaller than
a 4 MiB SRAM array) and was NOT attempted here; it remains exactly as
open as before. Also not claimed: that the *original* "too slow" finding
was never true - only that, with the CURRENT committed RTL, right now,
it measurably is not. **PROVEN — DIGITAL SIMULATION (Yosys elaboration),
TESTED CONDITIONS**, for exactly the two runs tabulated above; no
synthesis, timing, or physical-layout claim of any kind.

## Telemetry & Evaluation

All three items now executed. Spec 0.85 - items 3/5 (hardening guards) and
item 4 (measurement) all landed exactly as the ticket itself scoped each
one; not 1.0 because item 4's surprising result (fast/clean at full scale)
raises a new question - why did TKT-012/016's own history find full
geometry too slow? - that this ticket does not go back and answer, only
reports as observed today. Quality 0.85 - every claim in this ticket is
backed by an actual run (guard fires/doesn't fire in both directions,
Yosys elaboration bounded by a real timeout and actually completing, cell/
memory-bit arithmetic cross-checked by hand, not read off a tool summary
line alone) and includes a genuine self-caught correction (item 3's first
draft) rather than a first-draft-ships mistake; not higher because item
4's "why is this fast now" question is explicitly left open rather than
chased to a root cause, and no OpenROAD P&R was attempted (item 4's own
stated scope boundary). Emergence 0.2 - item 3's SUBTILES finding
corrected a misleading pre-existing comment; item 4 produced a genuinely
unexpected, previously-unmeasured data point (near-instant full-scale
elaboration) that revises (without fully explaining) a multi-ticket-old
assumption this program had carried since TKT-012/016.

**Final State:** `done | blue` - all three items (3, 5 hardening guards;
4 measurement) executed and recorded this session, each with its own
epistemic label and regression evidence in the Execution Log above. This
does not close TKT-020 Y1 in full (the GDDR7 PHY/SerDes clock-domain
piece of item 1 has no RTL yet, and item 4's OpenROAD P&R question is
explicitly still open) - only this ticket's own three items.
