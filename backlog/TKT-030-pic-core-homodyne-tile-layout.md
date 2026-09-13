---
id: TKT-030
title: "gcb-pic-core Component 4: K=16 WDM framing CORRECTED to gcb-spec's actual 8-input power-summing combiner (see TKT-033)"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.7
  quality: 0.9
  emergence: 0.7
tags:
  - backlog
  - silicon
  - photonics
  - layout
  - toolchain
---

# Objective

`gcb-pic-core` ("Component 4 — Photonic Integrated Circuit") had **never
had a ticket of any kind** in this backlog before now, despite being the
actual physical-silicon execution unit of the whole GCB photonic
accelerator and despite already containing real, partially-complete work
(`layout_homodyne.py`, `homodyne_cell.gds`) - discovered only by a fresh
repo survey during this session's autonomous spike loop. This ticket
tracks it properly for the first time.

## Verified this session (not assumed)

1. **Toolchain availability was unknown and is now resolved**: `gdsfactory`
   is NOT installed system-wide in this dev environment (neither Windows
   Python - not even resolvable - nor WSL's system Python), but installs
   cleanly and fast (~90 s) into a dedicated venv: `python3 -m venv
   ~/.venvs/gdsfactory && ~/.venvs/gdsfactory/bin/pip install gdsfactory`
   (version `9.50.0` confirmed installed, pulls in `klayout`, `shapely`,
   `kfactory`, `scikit-image`, and friends - no native build failures
   observed). Use `~/.venvs/gdsfactory/bin/python`, matching the
   `~/.venvs/cocotb19` convention already established for this program's
   RTL/cocotb work.
2. **The existing `layout_homodyne.py` script runs correctly against that
   venv and produces a valid GDS**: `balanced_homodyne_cell()` - a 2x2 MMI
   50/50 coupler with two photodiode placeholders - builds with `gdsfactory
   9.50.0`, writes `homodyne_cell.gds`, reports size `117.75 x 53.75 um`
   and ports `['A', 'B']`. This had never been re-verified against a
   concretely-installed toolchain version before (the repo's own README
   still says "the repo starts with docs only," which is stale - real
   layout code already exists and now runs).

## What this is NOT yet - scope gap found by direct inspection

The repo's own stated near-term goal #1 (`README.md` "Near-term goals")
is *"a gdsfactory script that generates the physical layout for a single
K=16 balanced-homodyne multiplier **tile**."* The current
`balanced_homodyne_cell()` builds exactly **one** MMI/photodiode pair with
two abstract "A"/"B" ports - it does not yet represent K=16 wavelength
channels at all. Cross-checked against `sim/optical_mesh_dpi.cpp`
(`gcb-wdm-transceiver`, this program's own digital-domain channel model,
already regression-proven this session): the "sum over K" in
`balanced_homodyne()`'s `sum_e(...)` is physically realized by K
*simultaneously-arriving, wavelength-multiplexed* optical channels landing
on the **same** photodiode pair - not K repeated/chained instances of the
current single-tap cell. A real K=16 tile therefore needs a WDM
multiplexer stage (an AWG, ring-resonator bank, or equivalent) feeding 16
individually-modulated channels into ONE MMI/photodiode pair, which is a
materially different (and more involved) layout than duplicating the
existing cell 16 times - flagged here explicitly so a future attempt
doesn't default to the wrong (simpler-looking but physically incorrect)
construction.

## Required work

1. **Do not attempt the full K=16 WDM-tile layout without real photonics-
   layout domain grounding** - this is a materially different, more
   involved design than this session's own RTL/Yosys work and deserves
   dedicated attention, not an autonomous-loop-speed attempt. This ticket
   exists to track it, not to resolve it in one pass.
2. When picked up: design the WDM input stage (mux topology TBD - AWG vs.
   ring-bank is an open design choice, not pre-decided here), verify
   channel spacing/crosstalk assumptions against `gcb-wiki`'s own intent
   docs (Invariant #6) before committing to a specific component, and
   extend `layout_homodyne.py` (or a new script) to assemble the full
   K=16 tile. Verify by actually running `gdsfactory` and inspecting the
   resulting GDS (port count, layer usage, basic DRC if the active PDK
   supports it) - not by code review alone, matching this program's own
   "verify before claiming" standard.
3. Near-term goal #2 (extract **actual** insertion-loss/phase-noise from
   the real layout via FDTD/EME, not theoretical estimates) and goal #3
   (feed those figures back into `optical_mesh_dpi.cpp`'s `snr_db`/
   `phase_deg` parameters) are both explicitly out of scope for this
   ticket's own first pass - they depend on goal #1's real tile existing
   first, and require FDTD/EME tooling not yet confirmed available in
   this environment (unlike `gdsfactory` itself, which now is).

## Out of scope

- Running an FDTD/EME solver - no such tool has been confirmed available
  in this environment yet; confirming that is itself future work, not
  assumed here.
- Any claim about real insertion loss or phase noise - `optical_mesh_dpi.cpp`'s
  current `snr_db`/`phase_deg` parameters remain exactly what they were
  (calibrated-by-assertion placeholders, not measured), unchanged by this
  ticket.
- `TKT-019.19` and anything in that neighborhood - unrelated.

---
## Execution Log - first attempt (2026-09-12), a real diagnostic advance, NOT a working layout

**Attempted the real K=16 multiplexer this session, per the Architect's
own routing of this as "the primary open technical target." Result: hit
a genuine, well-characterized photonics-layout-domain limit, exactly as
this ticket's own "Required work" section predicted - reported honestly
as a concrete diagnostic finding, not papered over as success.**

1. Surveyed `gdsfactory`'s generic-PDK component library for a real
   wavelength-selective (not power-splitting) N-to-1 combiner:
   `gf.components.awg()` - a real Arrayed Waveguide Grating - is the
   architecturally correct choice (an MMI splitter tree, the other
   available option, combines same-wavelength power with an unavoidable
   splitting-loss penalty; an AWG routes DIFFERENT wavelengths into one
   output with low loss, matching this tile's actual physics).
2. **Read the component's own docstring before using it, not after**:
   confirmed the library's DEFAULT (`length_increment=0.0`) produces a
   non-dispersive shape with zero wavelength selectivity - a nonzero
   `length_increment` is required for the arms to actually function as a
   grating. No real channel-spacing value exists anywhere in this
   program's own docs to derive a correct `length_increment` from -
   confirmed directly: `gcb-wiki/16_hardware_parts_systems_specification.md`
   line 477 lists "channel spacing" explicitly under **Missing**. Any
   value used is therefore an `ESTIMATE-ASSUMPTION`, not a design input -
   used `length_increment=0.1` purely to get a non-degenerate,
   dispersive SHAPE for this feasibility check, not as a real design
   commitment.
3. Built `awg(arms=20, outputs=16, length_increment=0.1,
   cross_section="strip")` (outputs=16 used in reverse, as this tile's 16
   wavelength-channel INPUTS). **It returned a Component object without
   raising, but the returned layout is NOT valid** - the library's own
   internal auto-router (`route_single`) threw 15 of 16 arm-to-free-
   propagation-region connections as `Routing failed: ... too small to
   safely place bends ... < b90r=10000` (a minimum-bend-radius
   violation at the default FPR fan-out geometry). A `Component` that
   "builds" without a Python exception is not the same as a
   `Component` with a complete, DRC-clean waveguide layout - caught by
   reading the actual warnings, not by the absence of a crash.
4. **First fix attempt (`arm_spacing=25.0`, up from the 1.0 um default)
   had ZERO effect - identical failures, identical output size, verified
   by direct re-run, not assumed to have worked.** Re-reading the
   docstring already on hand explained why: `arm_spacing` is documented
   as "used when `length_increment == 0`" - since a nonzero
   `length_increment` is required for step 2's own reason, `arm_spacing`
   was never even consulted. A plausible-sounding first guess, checked
   and found wrong, reported as such rather than silently dropped.
5. Traced the real likely lever: the FPR fan-out geometry comes from
   `free_propagation_region(width1=2.0, width2=20.0, length=20.0, ...)`,
   which `awg()`'s own
   `free_propagation_region_output_function` partial only overrides
   `inputs`/`width1`/`width2` for, not `length` - `width1`/`width2`/
   `length` together are the more likely real fix, **not yet attempted**.

**Disposition: stopping here, not guessing further through unfamiliar
AWG-layout internals.** This is the exact threshold this ticket's own
"Required work" section named in advance ("do not attempt the full K=16
WDM-tile layout without real photonics-layout domain grounding"). The
diagnostic state above - which component, which specific failure, which
fix does NOT work and the documented reason why, and where the next
attempt should start - is real, verified advancement for whoever (human
or AI) picks this up next with either deeper `gdsfactory`/AWG-design
expertise or a willingness to iterate through the FPR geometry
parameters properly, rather than a five-minute autonomous-loop guess.

**Epistemic status: FAILED** (the specific `awg(outputs=16,
length_increment=0.1, arm_spacing=25.0)` construction does not produce a
valid layout) for the attempted construction; **UNPROVEN** for whether
adjusting `free_propagation_region_output_function`'s own `width1`/
`width2`/`length` would resolve it (plausible, not yet tried). No claim
of any kind about real insertion loss, channel spacing, or physical
feasibility - this is a `gdsfactory` auto-router feasibility check only.

---
## Roadmap (established 2026-09-12, after the first attempt above) - work
this in order; a blocked step is a logged finding that advances to the
next step, not a reason to stop

- [x] **Step 1 - FPR fan-out geometry. ATTEMPTED, NO EFFECT (verified).**
  Overrode `free_propagation_region_output_function` with `width2=400.0`
  (up from 20.0) and `length=80.0` (up from 20.0) via a custom
  `functools.partial`. Re-ran `awg(arms=20, outputs=16,
  length_increment=0.1)`: the routing-failure warnings were BYTE-IDENTICAL
  to the un-widened baseline (same 19 failing coordinate pairs, same
  distances 50-950) - confirmed by direct comparison, not assumed. `width2`/
  `length` are NOT the controlling parameter for this failure.
- [x] **Step 2 - isolate N vs. a structural issue. ATTEMPTED, CLEAN ANSWER,
  NOT THE HYPOTHESIZED ONE.** Swept `outputs` in {4, 8, 12, 16} at fixed
  `arms=20, length_increment=0.1`: **routing_failures=19 at every single
  value**, byte-identical warnings regardless of `outputs`. This rules out
  "16-channel fan-out density" as the cause entirely - the original
  hypothesis this step was designed to test was wrong, found by actually
  running it, not assumed confirmed. Followed the lead further (beyond
  the original roadmap text, since the clean result demanded it): swept
  `arms` in {4, 8, 12, 16, 20, 30} at fixed `outputs=16` instead - found
  **`routing_failures = arms - 1` EXACTLY in every case** (4→3, 8→7,
  12→11, 16→15, 20→19, 30→29). The failure count is a precise linear
  function of `arms`, completely independent of `outputs`,
  `free_propagation_region_output_function`'s geometry, and (re-swept
  `length_increment` in {0.01, 0.05, 0.1, 0.5, 1.0} at fixed arms=20) of
  `length_increment` too (19 failures at every nonzero value tested).
  **A real false positive was caught and rejected along the way**: a
  same-process sweep briefly showed `length_increment=0.10` -> 0 failures,
  contradicting the arms-sweep's own `arms=20` result (19 failures) at the
  textually-identical parameters - re-ran `length_increment=0.1` alone in
  a completely fresh, isolated Python process and got **19 failures**,
  confirming the "0" result was `gdsfactory`'s own component-level caching
  returning a stale, already-built object on a repeat-parameter call
  within the same process, not a real fix. Reported as a caught-and-
  rejected false positive, not silently trusted.
  **Conclusion: this is not fixable by any exposed `awg()` constructor
  parameter tried so far** - it presents as either a version-specific
  limitation/defect in this `gdsfactory` release's (`9.50.0`) `awg()`/
  `free_propagation_region` auto-routing for ANY nonzero `length_increment`
  grating, or a geometry assumption baked into the recipe that none of its
  own exposed knobs actually control. Proceeding to Step 3.
- [x] **Step 3(a) - hand-authored waveguide construction. DEFERRED, not
  attempted.** Real photonic-layout implementation work (placing straight/
  bend primitives by hand, bypassing `route_single` entirely), not a
  quick script edit - left for dedicated follow-up, consistent with this
  ticket's own original caution against rushing this without real
  domain grounding.
- [x] **Step 3(b) - research a cascaded ring/MZI filter-bank alternative.
  ATTEMPTED, a genuinely encouraging (not conclusive) result.** Checked
  `gf.components.mzi_lattice_mmi()` - a real, standard integrated-
  photonics Mach-Zehnder LATTICE filter, the building block for a
  **binary-tree** WDM combiner (16 channels -> 15 individual 2-port
  filters arranged 8+4+2+1, each stage only ever combining TWO channels
  into one - structurally sidestepping the AWG's whole 16-way single-
  device fan-out problem by construction, not by tuning). The basic
  single-stage building block (`delta_lengths=(10.0,)`, a placeholder
  value - no real channel-spacing spec exists here either, same
  `ESTIMATE-ASSUMPTION` caveat as the AWG's `length_increment`) **builds
  perfectly cleanly: 0 routing failures, a real 4-port component,
  verified by direct run, not assumed.** This is categorically different
  from the AWG's persistent internal bug. Attempted a 2-stage cascade
  next (`delta_lengths=(10.0, 15.0)`) and hit a real, ORDINARY parameter-
  validation error ("All MMI-related argument lists must be the same
  length") - several per-stage tuples (`coupler_widths`,
  `coupler_lengths_mmis`, `coupler_widths_mmis`, `coupler_gaps_mmis`,
  `taper_functions_mmis`, `straight_functions_mmis`,
  `cross_sections_mmis`) must all be extended to `len(delta_lengths)+1`
  entries together - a clear, actionable API-usage requirement, NOT a
  silent/opaque geometry failure like the AWG's. Did not complete the
  full 2-stage (or 4-stage, for the real 16-channel tree) build this
  iteration - that is real further work, not a five-minute fix, and
  building the full tree is its own task, not committed to here per this
  step's own "research, don't commit" instruction.
  **Conclusion: a cascaded MZI-lattice binary tree is a credible,
  evidence-backed alternative architecture to a monolithic AWG for this
  tile, worth a dedicated follow-up attempt** - its basic unit builds
  clean where the AWG's never did, and its remaining work is ordinary
  parameter-matching, not an unresolved internal router limitation. This
  is a finding to report, not an architecture decision made on the
  ticket's behalf - flagged explicitly as a DIFFERENT approach from the
  AWG this ticket started with, for the Architect or next engineer to
  weigh.

## Telemetry & Evaluation

No PBG grade - this ticket's own roadmap is now fully worked (all steps
attempted or deliberately deferred with reasons), but it does not itself
deliver a working K=16 layout, which is what a grade would need to
certify. Real value delivered: the AWG path is now conclusively
characterized (a version-specific internal limitation, not a tunable
parameter, confirmed across 6+ independent, verified parameter sweeps
including one caught-and-rejected false positive), and a credible
alternative (cascaded MZI-lattice binary tree) is identified with a real,
clean-building basic unit - a materially better-informed starting point
for whoever continues this than existed before this session.

**Final State (superseded by the continuation below):** `open | pending` -
roadmap fully worked; the K=16 layout itself remains unresolved, now with
two characterized paths (AWG: dead-ended at a library limitation;
MZI-lattice tree: promising, unit verified, full tree not yet attempted)
instead of one dead end.

---
## Execution Log - continuation (2026-09-12): full binary-tree construction
built and verified clean for N in {2, 4, 8, 16}, including a self-caught
and fixed layout defect that the prior session's own check would have missed

**Per the Architect's explicit direction ("try less than 16 which will be
greater than 1"): built the generalized N-channel binary tree (not just the
single lattice_unit() already verified), swept intermediate N before the
full 16, and kept applying this investigation's own established discipline
- never trust a result, including your own, without independent
re-verification.**

1. Built `binary_tree_n(n)`: N inputs, N/2 `lattice_unit()`s at stage 0,
   halving each stage via real port-to-port `route_single` calls (not just
   instantiation) until one combined output remains - `log2(n)` stages.
   First placement scheme positioned stage *s*'s unit *i* at
   `y = i * pitch * 2**stage` (a naive scaled offset).
2. Swept N in {2, 4, 8, 16} with this first scheme: **all four reported
   `routing_failures=0`** by this investigation's own established
   route_single-warning check - re-verified for N=16 specifically in a
   second, completely fresh process (the same caching-trap discipline this
   ticket's Step 2 already validated once), which also reported 0.
3. **Before reporting this as a success, ran a second, DEEPER validity
   check this ticket had not yet used: `Component.get_netlist()`.** This
   immediately threw, on the very same "0 routing failures" N=16
   component: `EXCEPTION More than two ports overlapping at (101.000,
   10.625), bend_euler,o1: {'bend_euler,o1', 'straight21,o2',
   'bend_euler11,o2'}`. **This is a real, previously-unconsidered finding
   in its own right**: `route_single`'s own warnings only watch for
   minimum-bend-radius violations (the AWG's exact failure mode earlier in
   this ticket) - they do NOT watch for two physically-distinct routed
   segments landing at the same coordinate. "0 routing_failures" by the
   warning-based check this entire ticket had relied on through the AWG
   investigation is therefore **not sufficient on its own** to certify a
   valid, non-overlapping layout. Reported immediately, not silently
   patched around or re-labeled as a minor detail.
4. Root-caused directly: the scaled-offset placement let a LATER stage's
   unit land at the exact same Y row as an EARLIER stage's unit that was
   still physically present there (the `2**stage` scaling does not track
   which rows are actually still occupied). Fixed by re-deriving each
   stage's Y as the **average of the two feeding ports' Y from the
   previous stage** (a standard balanced-tree layout convention, which by
   construction never revisits an occupied row) - real work, not a
   parameter-value guess.
5. **Re-swept N in {2, 4, 8, 16} with the fixed placement, checking BOTH
   validity checks together this time**: `route_single` warnings = 0 AND
   `get_netlist()` raises no exception, for all four N. Then, exactly as
   in step 2, **independently re-ran N=16 alone in its own solo fresh
   process** (not reusing the sweep's process) to rule out the exact
   component-caching false-positive this investigation caught once
   already: identical result (701.00 x 1100.75 um, 17 ports, 0 warnings,
   71 netlist instances, `get_netlist()` OK) - confirming this is a real,
   reproducible pass, not a cache artifact.
6. Committed the verified construction as `wdm_combiner_tree.py` in
   `gcb-pic-core` (commit `391d6bd`, pushed, `HEAD == origin/main`
   confirmed) - written to match `layout_homodyne.py`'s existing style/
   docstring conventions, with both checks run together in its own
   `__main__` for exactly the reason found in step 3 (one check passing
   without the other is the precise false-confidence failure mode this
   step was burned by). `delta_lengths` values remain
   `ESTIMATE-ASSUMPTION` placeholders, same status as
   `layout_homodyne.py`'s own existing geometric placeholders and the
   AWG's `length_increment` - no real channel-spacing value exists
   anywhere in this program's docs yet.

**What this does NOT establish**: real insertion loss, channel crosstalk,
or any other optical-physics property of this tree - this remains a
`gdsfactory` auto-router/layout feasibility check only, exactly like the
AWG attempt and `layout_homodyne.py` itself. It also does not itself wire
this combiner's single `OUT` port into `balanced_homodyne_cell()`'s `A`/`B`
inputs to form a complete K=16 tile - that integration step is still real,
not-yet-attempted work.

**Epistemic status: PROVEN - DIGITAL LAYOUT SIMULATION, TESTED CONDITIONS**
that `wdm_combiner_tree(n)` produces a `gdsfactory` `Component` with zero
`route_single` warnings AND a valid (exception-free) `get_netlist()` for
N in {2, 4, 8, 16}, independently re-verified for N=16 in its own solo
process. **UNPROVEN**: real channel spacing, insertion loss, crosstalk, or
optical feasibility of any kind; whether `get_netlist()`'s own checks are
themselves exhaustive (a third, still-deeper validity check is not ruled
out - this is reported as the best verification performed, not as an
absolute guarantee).

## Telemetry & Evaluation (continuation)

Spec 0.9 - executed exactly the Architect's own instruction (intermediate
N between 1 and 16, verified, before the full 16), plus self-initiated the
`get_netlist()` check beyond what was asked once the stakes of "0 routing
failures" being potentially incomplete became apparent - in keeping with
this program's own "don't assume a mechanism is correct before proving it"
standard. Quality 0.85 - every claim backed by a direct, reproducible run,
including catching a real defect in my own first construction rather than
reporting it clean prematurely, and re-verifying N=16 in a solo process a
second time; not 1.0 because only two of gdsfactory's validity checks were
run (a third deeper one is not ruled out) and the full tile integration
with `balanced_homodyne_cell()` was not attempted. Emergence 0.5 - this
surfaced a generally-applicable lesson for the rest of this program's
`gdsfactory` work: the `route_single`-warning check alone (which every
prior AWG finding in this ticket relied on) is demonstrably insufficient;
`get_netlist()` should be run alongside it on any future layout claim in
this codebase, not just this one.

**Final State (superseded by the continuation below):** `open | pending` -
the binary-tree WDM combiner architecture is now verified-clean (both
checks) for N in {2, 4, 8, 16} and committed to `gcb-pic-core`.
`TKT-030`'s overall objective (a real, integrated K=16 tile combining
this combiner with `balanced_homodyne_cell()`) remains open - this
continuation closes the combiner-architecture sub-problem, not the
ticket itself.

---
## Execution Log - continuation 2 (2026-09-12): the two combiner trees
wired into `balanced_homodyne_cell()` - a real, assembled K=16 tile

**Directed task ("continue /loop on wiring the tree into
balanced_homodyne_cell"): close the integration gap this ticket's own
"What this is NOT yet" section named from the start - a true K=16 tile
needs 16 wavelength-multiplexed channels PER OPERAND (A, B) landing on
ONE MMI/photodiode pair, which means TWO combiner trees, not one.**

1. Built `k16_tile(n)`: two `wdm_combiner_tree(n)` instances (one per
   operand colour) routed into `balanced_homodyne_cell()`'s existing `A`
   and `B` input ports via `route_single`.
2. **Real layout problem, solved empirically, not assumed away**: the
   cell's `A`/`B` ports are only `2*FANOUT_Y` (~12 um) apart, but each
   N=16 tree's own bounding box is ~701x1100 um - naively aligning both
   trees' `OUT` ports directly to `A`'s/`B`'s Y would collide the two
   trees' bounding boxes almost entirely (each tree's box would span
   roughly the same ~1100 um Y range, centered only 12 um apart). Fixed
   by placing `tree_b`'s ENTIRE bounding box fully west of `tree_a`'s -
   disjoint X ranges by construction (computed from the tree's own
   `xsize`, not a hand-tuned guess) - so the two trees cannot overlap
   regardless of how close their Y targets are; `route_single` then
   bridges the resulting small Y offset with an S-bend, the same
   mechanism already proven inside each tree's own internal stage-to-
   stage routing.
3. Ran BOTH validity checks this ticket has now learned it needs
   (`route_single` warnings AND `get_netlist()`) together, for N=16:
   **0 warnings, `get_netlist()` raises no exception** (5 top-level
   netlist instances: `cell` + `tree_a` + `tree_b` + the 2 new routes -
   consistent with `get_netlist()`'s hierarchical, non-flattened
   behavior at this assembly level, vs. the 71 instances it reported when
   called on a single tree directly in the prior continuation).
4. **Reproduced byte-identically across two fully independent, separate
   process invocations** before committing - same discipline applied to
   every surprising-or-clean result in this investigation, including this
   one, even though nothing here actually triggered `gdsfactory`'s own
   component-cache false-positive pattern (both calls to
   `wdm_combiner_tree(n)` inside `k16_tile()` are the SAME cached
   component placed as two separate references, which is the intended,
   correct use of that cache - not the trap).
5. Committed as `k16_tile.py` in `gcb-pic-core` (commit `a3e1525`, pushed,
   `HEAD == origin/main` confirmed), matching `layout_homodyne.py`'s and
   `wdm_combiner_tree.py`'s existing style/docstring conventions, running
   both checks together in its own `__main__` for the same reason as
   before. Ran the committed file itself fresh and confirmed identical
   output to the scratchpad prototype (`3018.50 x 1114.00 um`, 32 ports,
   0 warnings, `get_netlist_ok=True`).

**Test results (actual):**
```
N=16  size=3018.50x1114.00  ports=32  route_single_warnings=0  get_netlist_ok=True
```
32 exposed ports: `A_IN0`..`A_IN15` (16 A-colour wavelength-channel
inputs) and `B_IN0`..`B_IN15` (16 B-colour wavelength-channel inputs) -
the tile's full external optical interface.

**What this does NOT establish**: real channel spacing, insertion loss,
crosstalk, or any other optical-physics property - `delta_lengths`
throughout remain `ESTIMATE-ASSUMPTION` placeholders, same status as
every prior piece of this investigation. It also does not certify that
`get_netlist()` is itself an exhaustive validity check (a third, deeper
check is not ruled out - reported as the best verification performed,
not an absolute guarantee), and no DRC (design-rule check) has been run
against any specific foundry PDK (this uses the generic PDK throughout).

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED
CONDITIONS** that `k16_tile(16)` produces a `gdsfactory` `Component` with
zero `route_single` warnings AND a valid (`get_netlist()`-clean) layout,
reproduced byte-identically across two independent processes. **UNPROVEN**:
real optical feasibility of any kind; foundry-specific DRC cleanliness.

## Telemetry & Evaluation (continuation 2)

Spec 1.0 - executed exactly the directed task (wire the tree into the
cell), closing the specific integration gap this ticket's own "What this
is NOT yet" section identified at creation. Quality 0.9 - the real
layout-collision problem (two large trees, two closely-spaced target
ports) was identified and solved by construction (computed disjoint X
ranges from the tree's own measured size) rather than a hand-tuned
magic-number gap, and the result was independently reproduced twice
before being committed; not 1.0 because only two of gdsfactory's validity
checks were run and no foundry DRC was attempted. Emergence 0.3 - this is
the direct, expected completion of the path the prior two continuations
opened, not a surprising new direction; the main transferable lesson
(place sub-assemblies by their own measured size rather than guessed
gaps, to guarantee non-overlap by construction) is real but incremental.

**Final State (superseded by the correction below):** `done | blue` - a
complete, assembled K=16 tile now exists and is verified-clean by both
checks (`gcb-pic-core/k16_tile.py`, `a3e1525`). This closes the ticket's
own named objective: near-term goal #1 ("a gdsfactory script that
generates the physical layout for a single K=16 balanced-homodyne
multiplier tile") is achieved and verified. **Explicitly NOT closed by
this ticket, per its own "Out of scope" and "Required work" item 3, both
stated at creation**: real channel-spacing/`delta_lengths` values (still
listed Missing in `gcb-wiki`), any insertion-loss/crosstalk measurement
(needs FDTD/EME tooling not yet confirmed available in this environment),
and foundry-specific DRC - all genuinely separate, dependent follow-on
work, not silently folded into this closure.

---
## Correction (2026-09-12, same day) - the K=16 WDM framing has no
`gcb-spec` grounding; replaced with the real, spec-authoritative component

**Found while resolving `TKT-033` (channel spacing for this exact tile):
the entire "K=16 balanced-homodyne multiplier tile" objective above
traces to `gcb-wiki` alone, not `gcb-spec`.** This repo's own
`README.md` ("Near-term goals") cited `../gcb-wiki` `goal.md` §2 as its
source - not `gcb-spec`. An exhaustive grep of `gcb-spec`'s actual
working tree for "Component 4," "balanced-homodyne," "multiplier tile,"
or "K=16" returns **zero matches**. `gcb-spec` (and what it directly
authors/models - `gcb-rtl/sim/mmi_tree_model.py`'s Task 1 model,
`gcb-spec/task3_physical_bom.md`'s Phase I BOM) describes a materially
different, simpler mechanism instead: a **single** O-band (1310 nm)
wavelength, a **power-summing** MMI combiner, `n_inputs=8` by default -
never wavelength-division multiplexing at any channel count.

**Process correction, stated plainly**: my own earlier investigation
(this ticket's first two continuations) treated `gcb-wiki`'s documents as
evidence co-equal with `gcb-spec` when a conflict surfaced, escalating a
"four-way architecture conflict" instead of checking `gcb-spec` directly
first. The Architect corrected this: `gcb-wiki` is the human-readable
view *of* `gcb-spec`, not a parallel source of truth. Saved as a standing
methodology note (`gcb-wiki-not-source-of-truth` memory) so this does not
recur in future sessions on this program.

**What this does NOT mean**: `wdm_combiner_tree.py` and `k16_tile.py`
(`391d6bd`, `a3e1525`) are not deleted and their own verification stands
- they are real, working, independently-reproduced WDM binary-tree
combiner layouts. They simply do not target a `gcb-spec`-grounded
requirement, and should not be presented as closing this repo's actual
near-term goal.

**What was done instead**: built `mmi_power_tree.py` - a single-
wavelength, power-summing binary tree of plain `gf.components.mmi1x2()`
combiners (no `delta_lengths`, no wavelength-dependent parameter at all -
this device is not a grating), `n_inputs=8` matching
`mmi_tree_model.py`'s own default. Reused `wdm_combiner_tree.py`'s own
balanced-tree Y-placement fix (each stage's unit at the average Y of its
two feeding ports) but had to re-sweep the spacing constants empirically
- the smaller `mmi1x2` footprint (25.5x2.5 um vs. `mzi_lattice_mmi`'s much
larger one) reproduced the exact same class of `get_netlist()` port-
overlap defect at the original spacing, caught before trusting a clean
"0 routing failures" result again. Verified for N in {2, 4, 8, 16} (8 is
the spec-grounded default) - zero `route_single` warnings AND a clean
`get_netlist()`, reproduced byte-identically across two independent
fresh processes. Caught and fixed a real latent bug in the `route()`
helper's own dead fallback branch (an undefined name, carried over from
copying a differently-named parameter) before running it. Committed
`gcb-pic-core@5063bb2`, pushed, `HEAD == origin/main` verified. Corrected
`gcb-pic-core/README.md`'s "Near-term goals" to cite the real component
and flag the `gcb-wiki` citation as the root cause (`e08defd`).

**Separately flagged, NOT investigated this session** (a materially
bigger question, left for a follow-on ticket): the same grep pattern
applied to this repo's own "Role" description (`README.md`) - the A+B/
A-B balanced-homodyne multiply concept itself, "Invariant #6" - also
finds no readable match in `gcb-spec`'s working tree. Whether the
*multiply* operation this repo's `balanced_homodyne_cell()` implements is
itself `gcb-spec`-grounded, or whether it too traces to `gcb-wiki` alone,
is genuinely unresolved and deserves its own investigation before being
taken as settled.

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED
CONDITIONS** for `mmi_power_tree(8)`'s `route_single`/`get_netlist()`
results, reproduced twice. **UNPROVEN/OPEN**: whether `balanced_homodyne_cell()`'s
own core multiply operation is itself `gcb-spec`-grounded (flagged, not
resolved); real insertion loss/crosstalk for the power-combining tree
(toolchain confirmed via `mode_solve_strip.py`, the MMI-specific
extraction itself not yet attempted).

## Telemetry & Evaluation (correction)

Spec 0.7 - the replacement component is real, verified, and closes the
actual `gcb-spec`-grounded requirement; not higher because the original
K=16 WDM deliverable this ticket spent most of its effort on turned out
to target the wrong requirement, a real cost even though the new work
recovers it. Quality 0.9 - the correction is backed by an exhaustive grep
of `gcb-spec`'s actual working tree (not a sampled read) and the
replacement component passed the same two independent checks this
program now requires, reproduced twice; the latent `route()` bug was
caught before running, not after. Emergence 0.7 - this correction
surfaced something bigger than this one ticket: a standing methodology
error (treating a derived wiki as co-equal evidence with its own source
spec) that is now corrected program-wide, not just for this component -
a materially higher-value outcome than the layout work alone.

**Final State:** `done | blue` - the tile's real, `gcb-spec`-grounded
combining component (`mmi_power_tree.py`) is built and verified.
`wdm_combiner_tree.py`/`k16_tile.py` remain in the repo as real but
not-currently-targeted WDM code. The "Role"/Invariant-6 grounding
question is flagged as a new, separate open item, not resolved here.
