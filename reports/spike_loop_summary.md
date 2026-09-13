# Spike Loop Summary — autonomous backlog-clearing run

Started 2026-09-12, session `01Rpa9VJGe7xypzp5FkukSco`. Append one dated
section per loop iteration below this line; never edit a prior iteration's
entry (the program's own convention — correct forward, don't rewrite
history). Epistemic labels are preserved exactly as used in the ticket
files themselves; this report does not re-grade anything.

---

## Iteration 1 — 2026-09-12

**Target selected:** `TKT-020` Y1 ("zero CDC scaffolding... no SDC exists
anywhere"), specifically verifying and then acting on whether `TKT-018`
actually closed Y1 items 1/2/4 as a prior recommendation in `TKT-020`
itself claimed it would.

**Pre-check (not skipped):** confirmed `TKT-020` R2 is already closed
(`gcb-wdm-transceiver@5cba81b`, `gcb-workspaces@1023cd8`, `result_fault`
present and live in `gcb_rx_digital_recombiner.sv`) before starting, so
this iteration did not re-execute it.

**Finding:** the "TKT-018 gate... (closes Y1 items 1/2/4)" line in
`TKT-020`'s own "Recommended gate tickets" section was a pre-`TKT-018`
*recommendation*, not a retrospective closure claim, and `TKT-018` as
actually executed did not fulfill it in full. Verified directly: `find .
-iname "*.sdc" -o -iname "*.xdc"` returned **zero files** anywhere in
`gcb-wdm-transceiver` before this iteration. Item 2 (`gcb_max_reduce`
`REG_STAGES`) genuinely was closed, by `GCB-031`/`.032`'s real physical
validation (`WNS 0.00 ps`, `fmax 1.519 GHz`) — not by `TKT-018`'s own
framing of item 3 specifically, but the underlying work exists and counts.
Items 1 and 4 were not closed.

**Work done:**
1. `gcb_dwdm_async_skew_fifo.sv` — marked all six 2-flop CDC synchronizer
   register pairs (gray-code pointer crossings + `TKT-019.21`'s
   cross-coupled reset tree) `(* ASYNC_REG = "TRUE" *) (* keep = "true" *)`.
   Verified the attributes survive `sv2v` (the real Yosys-path frontend)
   per-declaration, not merely that Verilator accepts the syntax.
2. `constraints/gcb_dwdm_async_skew_fifo_cdc.tcl` (new) — the first
   `.sdc`/constraint artifact of any kind in `gcb-wdm-transceiver`: a
   sourceable `set_clock_groups -asynchronous` procedure for the
   `wr_clk`/`rd_clk` boundary, documented as a per-lane-callable template
   (this module owns no fixed clock names of its own — `gcb_dwdm_deskew_cdc`
   instantiates `NUM_COLORS` copies, each with its own `wr_clk`).
3. `backlog/TKT-020-red-yellow-audit.md` — appended a dated disposition
   note correcting the overstated closure claim, documenting exactly what
   was and wasn't closed, with the evidence above.
4. `backlog/TKT-029-sram-geometry-and-fullscale-synth-hardening.md` (new) —
   a fully actionable ticket for Y1's genuine remainder: item 3
   (power-of-two SRAM address-math guard), item 5 (`SRAM_LATENCY`/`RD_REG`
   consistency check), item 4 (full-default-geometry Yosys run — a
   measurement task, explicitly not graded per the `TKT-019.9` precedent).
   Each has its own acceptance criteria and is independently actionable.
5. `README.md` (gcb-workspaces) — updated `TKT-020`'s summary line with the
   disposition finding, added `TKT-029`'s filetree entry and table row.

**Test results (actual, not assumed):** the RTL change is
synthesis-attribute-only (zero behavioral change), confirmed rather than
merely expected:
- `sim/lint.sh`: **38/38 clean**
- `test_wdm_deskew_cdc.py`: **TESTS=10 PASS=10 FAIL=0**
- `test_wdm_link_integration.py`: **TESTS=22 PASS=22 FAIL=0**
- `test_wdm_payload_mux.py`: **TESTS=3 PASS=3 FAIL=0**

**Epistemic status:** the CDC attribute/constraint addition is
**PROVEN — DIGITAL SIMULATION, TESTED CONDITIONS** for "introduces zero
behavioral regression" (regression-confirmed). It is explicitly **NOT** a
claim that the synchronizer's physical MTBF/latency assumptions
(`TKT-019.3`'s own `MAX_SKEW_CYCLES` placeholder) are validated, nor that
any real synthesis tool's specific retiming behavior was tested end-to-end
— only that the attribute and constraint now exist and correctly express
intent to whichever tool reads them. Item 1's remainder (GDDR7 PHY / optical
SerDes domains) stays **OPEN DEFECT** — no RTL exists yet to constrain.
`TKT-029`'s three items are **UNPROVEN / not yet attempted** — ticket
creation only this iteration, no execution.

**Commits:**

- `gcb-wdm-transceiver`: `f36e460`
- `gcb-workspaces`: PENDING (this file + TKT-020/TKT-029/README land in the
  same commit that records this hash — see the commit that touches this
  file for the actual hash; written before that commit exists)

**Ticket status changes:** `TKT-020` — still `open | pending` overall (an
audit deliverable, per its own Objective), disposition note appended.
`TKT-029` — created, `open | pending`.

**Next candidate for iteration 2:** `TKT-029` item 3 or item 5 (both are
small, bounded, elaboration-time guards — good next single-iteration
targets), or `TKT-020` R3 (Cyclopter scavenger validation — lower priority,
software/data-pipeline tier, not silicon/RTL).

---

## Iteration 2 — 2026-09-12

**Target selected:** `TKT-029` items 3 and 5 (both small, bounded
elaboration-time guards, as flagged at the end of iteration 1).

**Item 3 — a real mistake, caught before it shipped.** First draft of the
guard faithfully encoded `gcb_tensor_operand_sram.sv`'s own in-source
comment ("DEPTH_K / SUBTILES are powers of two at every real geometry")
and checked BOTH parameters. Running the real `compute_e2e` cocotb chain
(this repo's own already-proven TKT-025 production geometry) with that
guard in place produced an immediate, unexpected `$fatal`:
`SUBTILES (20) must be a power of 2` — `N_SUBTILES=20` is the real,
already-shipping B-operand geometry, and 20 is not a power of 2. Traced
the actual address math (`wr_sub * DEPTH_K + wr_k`) and found the
in-source comment itself had overclaimed: only `DEPTH_K` (the
multiplicand) is load-bearing for the multiply-as-shift property —
`SUBTILES` was never actually required to be a power of 2 for that reason.
**Corrected both the guard (DEPTH_K only) and the misleading comment**,
then re-verified in both directions: a deliberately bad `DEPTH_K=17`
(with the real `SUBTILES=20`) correctly fires; a deliberately bad
`SUBTILES=3` (with the real `DEPTH_K=256`) correctly does NOT fire; the
real `compute_e2e` chain passes clean (`TESTS=1 PASS=1`,
`MATCH | 40 output tiles bit-exact`). This is exactly the kind of mistake
this program's own discipline ("never assume a mechanism is correct
before proving it") exists to catch — it was caught in-session, before
any commit, by actually running the real regression rather than trusting
the first draft.

**Item 5 — scope narrowed by direct trace, not assumed.** `RD_REG` is not
an independently-instantiable controller parameter as the original Y1
finding's phrasing might suggest — it is `SRAM_RD_REG`, a hardcoded local
constant (`=0`) with an in-source comment instructing a future human to
manually co-adjust `SRAM_LATENCY` if it's ever changed. No live mismatch
exists in committed code today. Added a guard locking the currently-
validated value (`SRAM_RD_REG == 0`) rather than guessing at an unverified
general cross-adjustment formula for a hypothetical future value —
consistent with this program's standing "do not assert an equation that
has not actually been checked" discipline.

**Work done:**
1. `gcb_tensor_operand_sram.sv` — added the `DEPTH_K` power-of-2
   elaboration guard; corrected the pre-existing in-source comment that
   had incorrectly also claimed `SUBTILES` needed to be a power of 2.
2. `gcb_tensor_sram_controller.sv` — added the `SRAM_RD_REG == 0` lock
   guard.
3. `backlog/TKT-029-...md` — full Execution Log for items 3 and 5,
   including the self-correction, with epistemic labels.
4. `README.md` (gcb-workspaces) — updated `TKT-029`'s filetree entry and
   table row.

**Test results (actual):**
- `sim/lint.sh`: **38/38 clean**
- `tb_tensor_sram_controller.sv` (plain-SV, direct): **ALL CHECKS PASS**
- `test_wdm_*` suites: unaffected (this iteration touched no WDM RTL)
- `Makefile.compute_e2e` (cocotb, the real full chain): **TESTS=1 PASS=1**,
  `MATCH | 40 output tiles bit-exact | SRAM read stalls = 0`
- `Makefile.sram`: **TESTS=5 PASS=3 FAIL=0 SKIP=2** (SKIPs pre-existing,
  unrelated)
- `Makefile.sram_partial`: **TESTS=5 PASS=2 FAIL=0 SKIP=3** (same)

**Epistemic status:** both guards **PROVEN — DIGITAL SIMULATION, TESTED
CONDITIONS** for exactly the constructions tested (see `TKT-029`'s own
Execution Log for the full table). Item 5's guard explicitly does NOT
prove anything about a future `RD_REG != 0` configuration — that remains
**UNPROVEN**, now with a loud failure instead of silence guarding the
boundary. Item 4 (full-default-geometry Yosys run) remains **untouched**.

**Commits:**
- `gcb-wdm-transceiver`: `a0363e6`
- `gcb-workspaces`: this commit (see the commit that introduces this file
  section for its own hash)

**Ticket status changes:** `TKT-029` — items 3 and 5 resolved (Execution
Log appended, telemetry assigned `spec:0.7 quality:0.7 emergence:0.1` for
those two items); item 4 remains open; ticket stays `open | pending`
overall.

**Next candidate for iteration 3:** `TKT-029` item 4 (full-default-
geometry Yosys run — a measurement task, no RTL change), or re-scan the
backlog fresh per the loop's own step 1 before committing to that.

---

## Iteration 3 — 2026-09-12

**Target selected:** fresh backlog re-scan (per step 1) confirmed `TKT-029`
item 4 remains the best available silicon/RTL-tier target — the
`TKT-019.6`-`.18` chain is already executed-in-substance (confirmed in an
earlier session pass), `TKT-019.19` is off-limits, and `TKT-020` R3 /
`GCB-034`-`039` are software/architecture-tier, lower priority.

**What was done:** identified the real top-level modules
(`gcb_tensor_sram_controller`, `gcb_tensor_memory_engine` +
`gcb_tensor_broadcast_fabric`) and confirmed their RTL defaults are still
exactly what `TKT-020` Y1 item 4 described (`M_TOTAL=N_TOTAL=K_TOTAL=4096`,
`N_TILE=1024`, `GRID_DIM=16`, `NUM_CORES=256` - no drift). Ran the
identical `sim/yosys068_bless/` pipeline used throughout this repo, with
**zero `chparam` overrides** - i.e. at the real, un-shrunk default
geometry, bounded by a documented 10-minute timeout so a non-completion
would itself be a valid result.

**Result — a genuine surprise, reported as measured:** both elaborations
completed almost instantly (`gcb_tensor_sram_controller` alone: **0.08 s**;
the full `gcb_tensor_memory_engine` incl. the 256-core broadcast fabric:
**1.13 s**), 0 problems, latch-free. Cross-checked the memory-bit figure
(3.41×10⁷) by hand against the documented 64 KiB (A) + 4 MiB (B) sizing -
matches exactly, confirming this was genuinely the full geometry, not
something silently reduced. A notable secondary finding: the controller's
own LOCAL cell count at full scale (741) is nearly identical to its
already-blessed SHRUNK-geometry figure (740, from the pre-existing
`sim/yosys068_bless/` baseline) - because `stat`'s cell count tracks
control-plane logic width (logarithmic in geometry), not the memory bits
that actually scale with it.

**What this closes, and what it explicitly does not:** closes the
specific `TKT-020` Y1 item 4 claim that "no run has ever actually been
attempted at the real default size" for Yosys elaboration. Does **NOT**
close Y1's own separate, heavier claim about OpenROAD place-and-route at
this scale - that remains untouched and exactly as open as before; no
synthesis-to-gates, timing, or physical-layout claim is made here. Also
not claimed: that the *original* "too slow" finding was never true -
only that, with the current committed RTL, right now, it measurably is
not.

**Work done:**
1. `backlog/TKT-029-...md` — Execution Log for item 4, with the full
   before/after table and the cross-checked memory-bit arithmetic; all
   three items (3, 5, 4) now closed, ticket moved to `done | blue`
   (`spec:0.85 quality:0.85 emergence:0.2`).
2. `README.md` (gcb-workspaces) — updated `TKT-029`'s filetree entry and
   table row to `done | blue`.
3. No RTL changed this iteration - item 4 is a measurement only, per the
   `TKT-019.9` no-RTL-change precedent this ticket itself cited.

**Test results (actual):** two real Yosys runs (not estimates), both
exit code 0, `check -assert` clean, `select -assert-count 0
t:$dlatch t:$dlatchsr t:$sr` clean (0 latches) at both scopes.

**Epistemic status:** **PROVEN — DIGITAL SIMULATION (Yosys elaboration
only), TESTED CONDITIONS**, for exactly the two runs tabulated in
`TKT-029`'s own Execution Log. No claim of any kind about OpenROAD P&R,
timing closure, or physical layout at this scale.

**Commits:**
- `gcb-wdm-transceiver`: none (no RTL touched this iteration)
- `gcb-workspaces`: PENDING (to be filled before push)

**Ticket status changes:** `TKT-029` — `open | pending` → **`done | blue`**
(all three items closed). No new tickets created this iteration (the
fresh re-scan did not surface an uncaptured gap ranking above the already
-queued work).

**Next candidate for iteration 4:** a fresh backlog re-scan is needed
before picking anything further - with `TKT-029` fully closed and the
`TKT-019.6`-`.18` chain already substantively done, the remaining
silicon/RTL-tier candidates visible right now are thin (`TKT-020` R3 is
software-tier; `GCB-034`-`039` are architecture-only findings with no
queued RTL action). This may be close to genuine diminishing returns for
the silicon/RTL tier specifically - worth an honest evaluate-limits check
at the start of iteration 4 rather than manufacturing a lower-value
ticket just to keep looping.

---

## Iteration 4 — 2026-09-12

**Target selected:** not a pre-existing ticket - the honest "diminishing
returns" flag at the end of iteration 3 prompted checking whether the
backlog scan itself had been complete. It had not: `D:\R\S\H\` contains
several repos never surveyed this session at all, including two that are
genuinely **more** silicon-tier than anything touched so far -
`gcb-pic-core` (Component 4, the actual photonic IC layout) and
`gcb-analog-rx` (Component 5, the Rx quantizer/analog front-end). Neither
had ever had a ticket in this backlog. This is exactly the loop's own
step 1 ("scan for open high-priority tickets... create a new ticket for
any uncaptured structural gap") working as intended - the gap was the
scan's own scope, not the backlog's content.

**gcb-pic-core findings (`TKT-030`, new):**
- `gdsfactory` is not installed system-wide anywhere in this dev
  environment, but installs cleanly in ~90 s into a dedicated venv
  (`~/.venvs/gdsfactory`, version `9.50.0`) - a real toolchain-
  availability fact that was simply unknown before being tested.
- The existing `layout_homodyne.py` (previously un-run against any
  confirmed toolchain) builds correctly: a single balanced-homodyne
  MMI/photodiode cell, `117.75 x 53.75 um`, ports `['A','B']`, valid GDS
  written.
- The repo's own stated "K=16 tile" goal is NOT what the current script
  builds (one cell, not sixteen) - and, checked against this program's
  own `sim/optical_mesh_dpi.cpp` semantics, a real K=16 tile needs a WDM
  multi-channel input stage feeding ONE photodiode pair, not sixteen
  duplicated cells. Flagged as the real next step; not attempted (a
  materially bigger, more domain-specialized design task than this
  loop's other iterations).

**gcb-analog-rx findings (`TKT-031`, new) - the most consequential finding
this loop has produced:**
- `switched_charge_model.py` runs correctly and its own physics (exact
  Boltzmann constant, kT/C noise, flash-ADC quantization) checks out in
  isolation.
- Cross-checking it against `TKT-026`'s own already-computed nominal
  photocurrent (112.5 uA) - never done before - found it drives that
  model's own default 8-bit ADC to full-scale saturation (`255/255`,
  `V_signal=1125 mV` against `V_FS=600 mV`).
- Tracing why surfaced something bigger than a constant mismatch:
  **`TKT-026` assumed a transimpedance-amplifier front-end
  (`R_f≈13.33 kOhm`, continuous-time, `V=I*R_f`); `gcb-analog-rx`'s own
  README and model assume a switched-charge-integrator front-end
  (sampled, `V=I*T_int/C_int`, kT/C noise mechanism).** These are two
  different circuit topologies for the same physical signal, asserted
  independently in two different tickets, neither aware of the other.
  **Not resolved here** - reported for Architect disposition, consistent
  with this program's own standing discipline for architecture conflicts
  (`TKT-019.6`/`.7`'s own precedent).

**Work done:**
1. `backlog/TKT-030-pic-core-homodyne-tile-layout.md` (new) - full ticket
   with verified toolchain/layout state and the K=16 scope-gap finding.
2. `backlog/TKT-031-analog-rx-frontend-architecture-conflict.md` (new) -
   full ticket reporting the TIA-vs-integrator conflict, explicitly held
   for Architect disposition rather than resolved.
3. `README.md` (gcb-workspaces) - filetree entries + table rows for both.
4. No RTL changed - this iteration was discovery + ticket creation, per
   the loop's own step 1.

**Test results (actual):** `gdsfactory 9.50.0` install verified (exit 0,
real packages resolved and installed); `layout_homodyne.py` executed
successfully (real GDS written, size/ports printed and matched);
`switched_charge_model.py` executed successfully (both its own demo sweep
and a targeted re-computation at the real 112.5 uA operating point).

**Epistemic status:** the toolchain-availability and both scripts-run
findings are **PROVEN — DIGITAL SIMULATION/MODEL EXECUTION, TESTED
CONDITIONS** (each was actually run, not assumed). The architecture-
conflict finding is **OPEN DEFECT** in the sense that the program's own
records genuinely disagree with each other right now - it is not a
silicon or physical claim of any kind, only a cross-document consistency
finding.

**Commits:**
- `gcb-wdm-transceiver`: none (no RTL touched)
- `gcb-workspaces`: PENDING (to be filled before push)

**Ticket status changes:** `TKT-030` created (`open | pending`); `TKT-031`
created (`open | pending`, held for Architect disposition).

**Next candidate for iteration 5:** `TKT-030`/`TKT-031` are not
single-iteration-sized (photonics layout design work, and an
architecture decision respectively) - re-scan the backlog (now including
the previously-missed repos) for the next right-sized actionable item,
or treat the Architect-disposition dependency in `TKT-031` as a genuine
stopping point for the autonomous portion of this loop pending human
input.

---

## Iteration 5 — 2026-09-12

**Target selected:** `TKT-031`'s Architect disposition arrived (human
input, the exact dependency iteration 4 flagged as a stopping point):
adopt the switched-charge integrator as the Phase I baseline, retain
`TKT-026`'s TIA math as a benchtop/continuous-wave fallback. This
iteration implements that directive.

**What was done, and what it found:** claims 1/2 (cadence alignment,
thermal/power efficiency) are the Architect's own systems-level
engineering judgment, accepted as given - not independently checkable by
this program's digital-simulation tooling. Claim 3 (dynamic-range scaling
via switchable `C_int`/integration-window) IS a checkable, quantitative
claim, and checking it (rather than taking it on faith) found it only
PARTIALLY true as first implemented: a new switchable-capacitor bank
(`C_INT_BANK`, 10-50 fF - the file's own already-documented realistic
on-die range) covers `TKT-026`'s nominal 112.5 uA operating point and a
-50% insertion-loss variation, but genuinely does NOT cover a +50%
variation (168.8 uA would need ~70 fF, beyond that range) using the
capacitor alone. Reported honestly rather than silently widened past the
documented range. The Architect's OWN disposition had named a second
knob ("variable integration intervals") that had not yet been
implemented - added it (`T_INT_BANK`, a joint `select_c_int_t_int()`
search) and re-verified: the +50% case closes using both knobs together
(`C_int=40 fF`, `T_int=100 ps`), with `+32.4 dB` margin vs. the 30 dB
budget. `phase1_baseline_check()` (new, runs as part of the script's own
`__main__`, exits nonzero on any uncovered point) now reports
`PHASE I BASELINE VERIFIED` for all three test points.

**Work done:**
1. `gcb-analog-rx/switched_charge_model.py` - `C_INT_BANK`,
   `T_INT_BANK`, `select_c_int()`, `select_c_int_t_int()`,
   `phase1_baseline_check()` (new); header updated recording the
   Architect's disposition verbatim; `__main__` now runs the baseline
   check and exits nonzero on failure.
2. `gcb-analog-rx/README.md` - records the Phase I baseline decision.
3. `backlog/TKT-031-...md` - full Execution Log with the Architect's
   disposition recorded verbatim, the partial-failure-then-fix narrative,
   the verification table, and epistemic labels; moved to `done | blue`.
4. `backlog/TKT-026-photocurrent-budget.md` - appended a role-update
   section (not overwritten): TIA math retained as benchtop/CW fallback,
   no longer the Phase I baseline; its own 112.5 uA figure unaffected and
   confirmed as the exact value `TKT-031`'s verification used.
5. `README.md` (gcb-workspaces) - updated `TKT-026`/`TKT-031` entries.

**Test results (actual):** `switched_charge_model.py` executed end to
end, `phase1_baseline_check()` returns `True` / script exits 0 - all
three test points (nominal, -50%, +50% insertion-loss variation) covered
by a real, run-verified `(C_int, T_int)` combination within each bank's
documented range.

**Epistemic status:** **PROVEN — DIGITAL SIMULATION (Python/numpy
behavioral model), TESTED CONDITIONS** for claim 3 exactly as implemented
(both knobs together). Explicitly NOT claimed: that the Architect's
systems-level claims 1/2 were independently verified (they weren't - they
are accepted engineering judgment, correctly not something this program's
tooling can check); that +-50% is a measured insertion-loss uncertainty
(it is a round stand-in, flagged as such); that `T_INT_BANK`'s specific
divider ratios are a committed clock-tree decision; or any physical/
silicon measurement of any kind.

**Commits:**
- `gcb-analog-rx`: `5290e72`
- `gcb-workspaces`: PENDING (to be filled before push)
- `gcb-wdm-transceiver`: none (no RTL touched)

**Ticket status changes:** `TKT-031` — `open | pending` → **`done | blue`**.
`TKT-026` — stays `done`, role annotated (not re-graded).

**Next candidate for iteration 6:** `TKT-030` (the gcb-pic-core K=16 WDM-
tile layout) remains the most substantial still-open item from this
loop's own discoveries, but is explicitly flagged as too large/domain-
specialized for this loop's pace - a fresh backlog re-scan (including a
check of the remaining un-surveyed repos: gcb-host, gcb-grants,
gcb-papers, vortex, sv2v-Linux, AI-session) is the honest next step
before committing to anything further.

---

## Iteration 6 — 2026-09-12 (brief)

**Target selected:** the remaining un-surveyed repos, per iteration 5's
own flagged next step. `gcb-grants`, `gcb-papers`, `AI-session` are
funding/academic/session-log content - correctly out of scope under this
program's own Silicon > RTL > hardware-connectivity > software/tooling
priority. `vortex` and `sv2v-Linux` are upstream third-party projects
(license/changelog/contributing-file structure, not GCB-authored
components) - out of scope as dependencies, not program deliverables.
`gcb-host` ("C++ pilot driver, FastAPI MMIO proxy, model manifest
tooling") IS genuinely hardware-connectivity tier and had never been
ticketed.

**Work done:** created `backlog/TKT-032-gcb-host-intake.md` as a
**deliberately lightweight placeholder**, not a completed survey (unlike
`TKT-030`/`TKT-031`) - a real C++ driver + FastAPI proxy deserves the same
actually-build-and-run verification those two got, which is its own
bounded task for a future iteration, not a rushed add-on at the end of
an already-long run. Updated `README.md`'s filetree/table entries.

**Commits:**
- `gcb-workspaces`: PENDING (to be filled before push)

**Ticket status changes:** `TKT-032` created (`open | pending`).

**STOPPING HERE.** See the Conclude & Handoff report delivered in-chat
for the full rollup, stopping reason, and Gemini handoff prompt.

---

## Iteration 7 — 2026-09-12

**Target selected:** independent re-verification of `TKT-031`'s
`phase1_baseline_check()` (requested directly), then `TKT-030`
(gcb-pic-core K=16 layout) - routed by name as "the primary open
technical target" after a fresh backlog scan confirmed nothing
higher-priority had appeared.

**Re-verification:** re-ran `switched_charge_model.py` fresh (the exact
`--run-verification` flag requested does not exist - the script has no
argparse, `phase1_baseline_check()` already runs unconditionally in
`__main__`; used the real `~/.venvs/gdsfactory` venv since plain `python`
does not resolve in this environment). Confirmed independently:
`PHASE I BASELINE VERIFIED`, exit 0, the +50% insertion-loss case lands
at ADC code `180/255` - comfortably inside the [10%,80%] window, no
clipping, no rail saturation.

**TKT-030 first real attempt - a genuine diagnostic advance, not a
working layout:** identified `gf.components.awg()` (a real Arrayed
Waveguide Grating) as the architecturally correct component (wavelength-
selective combining, not an MMI power-splitter). Read its docstring
before using it: the library default is non-dispersive
(`length_increment=0`); confirmed no real channel-spacing value exists
anywhere in this program's own docs to derive a correct value from
(`gcb-wiki/16`'s own "Missing" list names it explicitly) - used a clearly
-labeled placeholder `length_increment=0.1` for feasibility only. Built
`awg(arms=20, outputs=16, length_increment=0.1)`: it returned without
raising, but the library's own internal router threw 15/16 arm-to-FPR
routing failures (minimum-bend-radius violation) - a `Component` object
without a Python exception is NOT the same as a valid layout, caught by
reading the actual warnings. First fix attempt (`arm_spacing=25.0`)
verified to have **zero effect** - identical failures, identical output
size, re-run and compared directly rather than assumed to have worked;
traced why: the docstring already on hand says `arm_spacing` is "used
when `length_increment == 0`," which a dispersive AWG cannot use. Traced
the real likely lever (the free-propagation-region's own `width1`/
`width2`/`length`) but did not try it - stopped at the exact photonics-
layout-domain-expertise threshold `TKT-030` itself predicted in advance,
rather than guessing further through unfamiliar AWG internals.

**Work done:**
1. `backlog/TKT-030-...md` - Execution Log appended with the full
   diagnostic narrative (component choice, the two checked-and-verified
   attempts, the one genuinely FAILED construction, the next untried
   lever), epistemic labels (`FAILED` for the attempted construction,
   `UNPROVEN` for the untried fix).
2. `README.md` (gcb-workspaces) - updated `TKT-030`'s entries with the
   same honest accounting.
3. No change to `gcb-pic-core` itself - no file was written there (the
   attempts were interactive Python calls, not saved to
   `layout_homodyne.py` or a new script, since none produced a valid
   result worth committing).

**Test results (actual):** `switched_charge_model.py` re-run, confirmed
`PHASE I BASELINE VERIFIED`, exit 0 (independent re-verification).
`gf.components.awg()` calls: both returned `Component` objects (no
exception) but with confirmed, logged internal routing failures - NOT a
passing result, reported as such.

**Epistemic status:** the re-verification is **PROVEN — DIGITAL
SIMULATION (model execution), TESTED CONDITIONS**, confirmed
independently. The AWG attempt is **FAILED** for the specific
construction tried (not a working layout); **UNPROVEN** for whether the
untried FPR-geometry fix would resolve it.

**Commits:**
- `gcb-workspaces`: PENDING (to be filled before push)
- `gcb-analog-rx`, `gcb-wdm-transceiver`, `gcb-pic-core`: none this
  iteration (re-verification only; the AWG attempts produced nothing
  worth committing)

**Ticket status changes:** `TKT-030` stays `open | pending` - real
diagnostic progress recorded, the K=16 layout itself remains unresolved.

**Next step:** `TKT-030`'s remaining path (adjust
`free_propagation_region_output_function`'s `width1`/`width2`/`length`)
is a plausible next lever but requires either dedicated photonics-
layout-domain attention or continued careful iteration - this loop has
now hit a genuine domain-expertise boundary on its one remaining
substantial open target. Honest stopping point.

---

## Iteration 8 — 2026-09-12 (restructured /loop: planning-first, prolonged
iterations)

**Structural change, requested directly**: prior iterations stopped too
readily after one blocked attempt. This run (and forward) builds an
explicit, ordered roadmap per ticket BEFORE executing, and treats a
blocked roadmap STEP as a logged finding that advances to the next step
or the next ticket - not a reason to end the loop.

**`TKT-030` roadmap worked (steps 1-2), a clean, precise, unresolved
result:** Step 1 (widen `free_propagation_region_output_function`'s
`width1`/`width2`/`length`) had **zero effect** - re-run and compared
byte-for-byte against the un-widened baseline, not assumed fixed. Step 2
(sweep `outputs` in {4,8,12,16}) found **identical 19 failures at every
value** - the original "16-channel density" hypothesis this step was
designed to test was wrong, found by running it. Followed the lead:
swept `arms` instead, found **`routing_failures = arms-1` exactly**,
independent of `outputs`/FPR-geometry/`length_increment`. **Caught and
rejected a false positive along the way**: a same-process sweep briefly
showed one value as "fixed," contradicted by a prior result at
textually-identical parameters - re-ran in a fresh, isolated process and
confirmed the "fix" was `gdsfactory`'s own component-caching returning a
stale object, not a real result. Points to a version-specific
`gdsfactory 9.50.0` `awg()` limitation, not a tunable parameter. Step 3
(manual waveguide construction or a ring/MZI alternative) explicitly
deferred as categorically bigger work - logged, not rushed, and not a
reason to stop the loop.

**`TKT-032` roadmap added**, ready for execution next.

**Commit:** `gcb-workspaces@35510e7`.

---

## Iteration 9 — 2026-09-12

**Target:** `TKT-032`'s 5-step roadmap, worked in full.

**Step 1 (read source):** `include/greencoyote_pilot.hpp` is a real,
substantial (~800-line) header-only C++ driver - not a stub - targeting
an Alveo U55C FPGA via XRT, opening an IP literally named
`"greencoyote_top"`. Full register surface read: `PRECISION_MODE`,
`GLOBAL_CAL`, `CH_GAIN_TRIM`, `REDUCTION_CTRL`, `IRQ_CTRL`, an 8-port
crossbar (tensor/pipeline/MoE routing), training/LoRA/gradient-reduce
registers, task scheduling, and `SS_TDC_CTRL`/`SS_CAL_*` (matching
`gcb-rtl`'s single-slope TDC readout by name - the first clue to Step 5).

**Step 2 (C++ build):** `src/` and `tests/` are BOTH completely empty -
no build system exists anywhere in this repo. Reported as a real finding
(nothing to build), not a blocked attempt.

**Step 3 (tests), redirected to the real surface:** `gcb-host/tests/` is
empty, but Step 5 confirmed the real counterpart lives in `gcb-rtl` -
ran its existing Icarus regression fresh: `tb_cs_fifo_path` (the pilot
testbench) **ALL CHECKS PASS**, `tb_dma_integration` **ALL CHECKS PASS**
(`fire_seen=1018 errors=0`), `tb_ss_calib` **10000/10000 PASS**,
`tb_ss_tdc` **ALL CHECKS PASS**. The RTL side is genuinely healthy; the
gap is entirely host-side.

**Step 4 (proxy smoke test) - a real documentation inaccuracy found:**
`gcb_proxy.py` contains **zero** FastAPI code anywhere (confirmed by
direct grep) - it is a self-contained, self-checking pure-Python MMIO
register simulator, not an HTTP proxy. Ran it directly: exercises a DMA
descriptor push + doorbell + arm + reduction trigger, asserts w1p strobes
self-clear correctly - **exit 0, passed**. `gcb-host`'s own README
("FastAPI MMIO proxy") is stale/inaccurate for what this file actually
is - flagged, not silently corrected.

**Step 5 (relate to RTL) - this ticket's own starting hypothesis was
WRONG, found by checking:** the roadmap guessed `gcb_dwdm_ctrl_axi.sv`
(`gcb-wdm-transceiver`). Refuted. The real connection is
`gcb-rtl/rtl/greencoyote_top.sv` + `greencoyote_pilot_regs.sv` -
confirmed two ways: the C++ driver's own XRT IP name, and a genuinely
synchronized register map (`map_version: 0.6.0` matches exactly, every
checked offset matches exactly on both sides). A real, previously-
undocumented cross-repo link, found only by actually reading both sides.

**Work done:** `backlog/TKT-032-...md` - full Execution Log for all 5
steps; moved to `done | blue`. `README.md` updated. No RTL/code changed
in `gcb-host` or `gcb-rtl` - this was a survey, per its own scope.

**Test results (actual):** `gcb-rtl`: `tb_cs_fifo_path`,
`tb_dma_integration`, `tb_ss_calib` (10000/10000), `tb_ss_tdc` - all
re-run fresh, all pass. `gcb-host/proxy/gcb_proxy.py` - run fresh, exit 0.

**Epistemic status: PROVEN — DIGITAL SIMULATION, TESTED CONDITIONS** for
every pass/fail result reported (all re-run this session, not read from
a prior log). The cross-repo register-map match is a direct, verified
textual/numeric comparison, not an inference from naming alone.

**Commits:**
- `gcb-workspaces`: PENDING (to be filled before push)
- `gcb-rtl`, `gcb-host`: none (survey only, no code changed)

**Ticket status changes:** `TKT-032` — `open | pending` → **`done | blue`**.

**Next candidate:** `TKT-030` Step 3 (manual AWG waveguide construction,
or research a ring/MZI alternative) remains the one deferred item across
both active roadmaps - continuing the loop into it, or a fresh backlog
scan, per the restructured "keep going" discipline.

---

## Iteration 10 — 2026-09-12

**Target:** `TKT-030` Step 3(b) - research whether a cascaded ring/MZI
filter bank is a viable alternative to the AWG, the one remaining
deferred roadmap item across both active tickets.

**Finding - a genuinely encouraging, not conclusive, result:** checked
`gf.components.mzi_lattice_mmi()`, a real Mach-Zehnder lattice filter -
the building block for a 16-to-1 BINARY TREE of 15 two-port combiners
(8+4+2+1 stages), which structurally avoids the AWG's whole 16-way
single-device fan-out problem by construction, not by parameter tuning.
The basic single-stage unit (`delta_lengths=(10.0,)`, a placeholder -
same "no real channel-spacing spec exists" caveat as the AWG attempt)
**builds perfectly cleanly: 0 routing failures**, verified by direct run.
Attempting a 2-stage cascade hit only an ORDINARY parameter-length-
matching error ("All MMI-related argument lists must be the same
length") - a clear, actionable API requirement, categorically different
from the AWG's silent/opaque internal routing bug. Did not build the
full 16-channel tree (real further work, not committed to here, per this
step's own "research, don't commit" instruction) - but the basic-unit
result is real, positive evidence this path is more tractable than the
AWG's dead end.

**Work done:** `backlog/TKT-030-...md` - Step 3(a) marked deferred
(logged with reasons), Step 3(b) marked attempted with the finding above;
final Telemetry section updated to reflect the roadmap is now fully
worked (two characterized paths, neither yet a working layout).
`README.md` updated.

**Test results (actual):** `mzi_lattice_mmi(delta_lengths=(10.0,))` built
and checked for routing-failure warnings directly - 0 found. The 2-stage
attempt's exception was read and reported verbatim, not paraphrased.

**Epistemic status: PROVEN — DIGITAL SIMULATION (gdsfactory build),
TESTED CONDITIONS** for the single-stage unit's clean build. **UNPROVEN**
for whether the full 16-channel tree (4 stages, correctly-matched
per-stage parameter tuples) actually builds clean end to end - not yet
attempted.

**Commit:** `gcb-workspaces` (this commit).

---

## CONCLUDING THIS EXTENDED RUN (iterations 8-10, restructured /loop)

**Fresh backlog re-scan** (final, before stopping): `TKT-031`/`TKT-032`
closed this run. `TKT-030` remains open with BOTH roadmap steps either
completed or deliberately, explicitly deferred with reasons - no step
left silently untried. `TKT-019.6`-`.18` remain already executed-in-
substance (confirmed in an earlier pass this session); `TKT-019.19`
off-limits; `TKT-020` R3 and `GCB-034`-`039` are software/architecture-
tier, correctly lower priority. **No new silicon/RTL-tier gap surfaced.**

**Stopping reason, against this run's own narrowed criteria:** criterion
(a) met - every roadmap step for every active ticket (`TKT-030`,
`TKT-031`, `TKT-032`) has been attempted and exhausted (blocked, deferred
with reasons, or completed), with results recorded at each step, not
just the first one tried. The remaining real next step (building
`TKT-030`'s full 16-channel MZI-lattice tree) is itself a new, substantial
task that would need its own roadmap - the same "categorically bigger
than a loop iteration" boundary this run correctly identified for the
AWG path's own Step 3(a), now reached again for the alternative's own
natural conclusion. This is a genuine stopping point, not a premature one
- three iterations' worth of real, verified, mostly-successful work
(TKT-031 and TKT-032 fully closed; TKT-030 materially advanced with two
characterized paths) separate this stop from iteration 7's.

---

## Post-loop directed continuation — 2026-09-12 (TKT-030, Architect-directed)

**Context:** the extended loop run above concluded at iteration 10 with
`TKT-030` open, both its roadmap branches (AWG dead-end, MZI-lattice
single-unit verified) recorded. The Architect then gave an explicit
follow-on instruction ("try less than 16 which will be greater than 1"),
directing a specific next step - build and verify an intermediate-N
binary tree before attempting the full N=16 - rather than a new
autonomous loop iteration. Executed directly, not via `/loop`.

**Target:** `TKT-030` - generalize the single `lattice_unit()` (already
clean at 0 routing failures) into a real `binary_tree_n(n)` construction,
verify at intermediate N, then N=16.

**What was done:**
1. Built `binary_tree_n(n)` in the session scratchpad: N inputs, N/2
   `lattice_unit()`s at stage 0, halving each stage via real
   `route_single` port-to-port routing (not just instantiation) across
   `log2(n)` stages.
2. Swept N in {2, 4, 8, 16} with a first placement scheme (Y offset
   scaled by `pitch * 2**stage`). All four reported `routing_failures=0`
   by the `route_single`-warning check - re-verified for N=16 alone in a
   second, fresh process (ruling out the exact component-cache false
   positive this investigation already caught once, in Iteration 2/Step
   2 above).
3. **Ran a second, deeper check not yet used in this ticket:
   `Component.get_netlist()`.** It immediately threw on the same "0
   routing failures" N=16 component: `More than two ports overlapping at
   (101.000, 10.625)`, naming three specific sub-ports. This is a real
   finding reported immediately, not smoothed over: the `route_single`
   warning check (which this entire ticket's AWG investigation relied on)
   only watches for bend-radius violations, not coincident routed
   segments - "0 routing failures" by that check alone is **not**
   sufficient to certify a valid, non-overlapping layout.
4. Root-caused: the scaled-offset placement let a later stage's unit land
   on the same Y row as an earlier stage's still-occupied unit. Fixed by
   placing each stage's unit at the average Y of its two feeding ports
   (standard balanced-tree convention) instead of a scaled offset.
5. Re-swept N in {2, 4, 8, 16} with BOTH checks (`route_single` warnings
   AND `get_netlist()`) run together: clean for all four N. Re-verified
   N=16 alone in its own solo fresh process a second time (size, port
   count, and netlist instance count all matched the sweep's own result
   exactly) - ruling out the caching trap again, on the corrected
   construction this time.
6. Wrote the verified construction as `wdm_combiner_tree.py` in
   `gcb-pic-core`, matching `layout_homodyne.py`'s existing docstring/
   style conventions, running both checks together in its own `__main__`
   for the same reason found in step 3. Ran the committed file itself
   (not just the scratchpad copy) fresh, confirmed identical output.

**Test results (actual):**
```
N= 2  size= 101.00x  50.75  ports=3  route_single_warnings=0  get_netlist_ok=True
N= 4  size= 301.00x 200.75  ports=5  route_single_warnings=0  get_netlist_ok=True
N= 8  size= 501.00x 500.75  ports=9  route_single_warnings=0  get_netlist_ok=True
N=16  size= 701.00x1100.75  ports=17  route_single_warnings=0  get_netlist_ok=True
```
N=16 solo-process re-check: identical size/ports/0-warnings, plus
`get_netlist()` returning 71 netlist instances with no exception.

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED CONDITIONS**
for `wdm_combiner_tree(n)` producing a `gdsfactory` `Component` with zero
`route_single` warnings AND a valid (`get_netlist()`-clean) layout for N
in {2, 4, 8, 16}. **UNPROVEN**: real channel spacing, insertion loss,
crosstalk, or any optical-physics property (`delta_lengths` remain
`ESTIMATE-ASSUMPTION` placeholders, same status as the AWG's
`length_increment` and `layout_homodyne.py`'s own geometric
placeholders); whether `get_netlist()` is itself an exhaustive validity
check (not ruled out that a third, deeper check could still find
something - reported as the best verification performed, not an absolute
guarantee); full tile integration with `balanced_homodyne_cell()`
(not attempted).

**Commits:**
- `gcb-pic-core@391d6bd` - `wdm_combiner_tree.py` added, pushed,
  `HEAD == origin/main` verified.
- `gcb-workspaces` (this commit) - `TKT-030` continuation Execution Log +
  telemetry, `README.md` TKT-030 entries (filetree + status table)
  updated, this summary entry appended.

**Ticket status changes:** `TKT-030` remains `open | pending` - the
combiner-architecture sub-problem is now closed (binary-tree verified
clean at N up to 16, both checks), but the ticket's overall objective
(a real, integrated K=16 tile combining this combiner with
`balanced_homodyne_cell()`) is not yet done.

**Next candidate:** wire `wdm_combiner_tree(16)`'s single `OUT` port into
`balanced_homodyne_cell()`'s `A`/`B` inputs (two trees would be needed -
one per operand colour - to form the actual K=16 tile per the original
scope-gap note), and/or pursue real channel-spacing/`delta_lengths`
values against `gcb-wiki`'s Invariant #6 once that data exists (still
listed Missing as of this entry).

---

## Post-loop directed continuation 2 — 2026-09-12 (TKT-030, Architect-directed: "wiring the tree into balanced_homodyne_cell")

**Context:** continuing directly from the previous entry's binary-tree
combiner work. The Architect directed the next concrete step: wire that
verified combiner into the existing `balanced_homodyne_cell()`, closing
the integration gap this ticket named at creation (a true K=16 tile
needs 16 wavelength-multiplexed channels PER OPERAND, A and B, landing on
ONE MMI/photodiode pair - meaning two trees, not one).

**Target:** `TKT-030` - assemble `k16_tile(n)`: two `wdm_combiner_tree(n)`
instances, one per operand colour, routed into `balanced_homodyne_cell()`'s
existing `A`/`B` inputs.

**What was done:**
1. Prototyped in the scratchpad first (same workflow as the combiner
   tree itself), then wrote the final version as `k16_tile.py` in
   `gcb-pic-core`, matching `layout_homodyne.py`/`wdm_combiner_tree.py`'s
   existing style.
2. **Real layout problem solved by construction, not a tuned guess**:
   the cell's `A`/`B` ports are only ~12 um apart, but each N=16 tree's
   own bounding box is ~701x1100 um - naively aligning both trees' `OUT`
   ports to `A`'s/`B`'s Y would collide the two trees almost entirely.
   Solved by computing `tree_b`'s placement so its ENTIRE bounding box
   sits fully west of `tree_a`'s (disjoint X ranges, derived from the
   tree's own measured `xsize`), guaranteeing no overlap regardless of
   how close the two target Y values are; `route_single` then bridges
   the resulting small Y offset with an S-bend.
3. Ran BOTH validity checks this ticket's prior continuation established
   as necessary (`route_single` warnings AND `get_netlist()`) for N=16:
   0 warnings, `get_netlist()` exception-free (5 top-level netlist
   instances: cell + tree_a + tree_b + 2 routes).
4. **Reproduced byte-identically across two fully independent process
   invocations** before committing - same discipline applied throughout
   this investigation, even though nothing here actually triggered the
   component-cache false-positive pattern (the two `wdm_combiner_tree(n)`
   calls inside `k16_tile()` are intentionally the same cached component
   placed as two separate references - the correct, intended use of that
   cache, not the trap caught earlier in this ticket).
5. Committed `k16_tile.py` to `gcb-pic-core` (`a3e1525`, pushed,
   `HEAD == origin/main` verified). Ran the committed file itself fresh
   and confirmed identical output to the scratchpad prototype.

**Test results (actual):**
```
N=16  size=3018.50x1114.00  ports=32  route_single_warnings=0  get_netlist_ok=True
```
32 exposed ports: `A_IN0..A_IN15` (16 A-colour channel inputs),
`B_IN0..B_IN15` (16 B-colour channel inputs).

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED
CONDITIONS** that `k16_tile(16)` produces a `gdsfactory` `Component` with
zero `route_single` warnings AND a valid `get_netlist()`, reproduced
byte-identically across two independent processes. **UNPROVEN**: real
channel spacing, insertion loss, crosstalk, or any other optical-physics
property (`delta_lengths` remain `ESTIMATE-ASSUMPTION` placeholders
throughout); foundry-specific DRC (generic PDK only, no DRC deck run).

**Commits:**
- `gcb-pic-core@a3e1525` - `k16_tile.py` added, pushed,
  `HEAD == origin/main` verified.
- `gcb-workspaces` (this commit) - `TKT-030` continuation-2 Execution Log
  + telemetry, frontmatter status flipped `open|pending` → `done|blue`
  (near-term goal #1 - the tile's own named objective - is now achieved
  and verified; goals #2/#3 and DRC remain explicitly out of scope per
  the ticket's own original text), `README.md` TKT-030 entries updated,
  this summary entry appended.

**Ticket status changes:** `TKT-030`: `open | pending` → `done | blue`.
Closing note, not a silent upgrade: this closes the *layout-feasibility*
objective only - real optical design (channel spacing, insertion loss,
crosstalk, foundry DRC) remains genuinely open future work, named as
such in the ticket's own "Out of scope" section since its creation.

**Next candidate:** real channel-spacing/`delta_lengths` design values
(blocked on the still-Missing spec in `gcb-wiki`); FDTD/EME tooling
availability survey (needed before any real insertion-loss/crosstalk
claim, itself a new intake-style ticket, same shape as `TKT-032`'s own
intake); or returning to the broader backlog for the next priority item
if no Architect-directed follow-on is given.

---

## Post-loop directed continuation 3 — 2026-09-12 (channel spacing + FDTD/EME survey, new ticket TKT-033)

**Context:** the Architect named the next priority explicitly — "channel
spacing and FDTD/EME insertion-loss extraction... bridges the gap between
structural layout geometry and validated physical simulation data" —
with a sequenced second target (TKT-032's build-and-run pass) to follow.
Executed the first target directly.

**Target:** formalize real channel-spacing values for `gcb-pic-core`'s
K=16 tile and survey/attempt FDTD/EME insertion-loss extraction, per the
Architect's own framing.

**What was done - Part A (channel spacing):**
1. Cross-read every existing channel-spacing/wavelength claim across
   `gcb-wiki` and `gcb-spec` before touching any delta_lengths value.
2. **Found a real, previously-undetected conflict**: `gcb-wiki/16` Part 9
   (the "DWDM laser/modulator bank... 8x8 unitary mesh," Phase II)
   explicitly lists channel spacing as `Missing`, with its own doctrine
   note against fabricating a figure. But `gcb-wiki/15` (the
   `gcb_wavelength_router` DWDM digital-transport RTL) DOES already
   carry an existing `ASSUMPTION` figure: 50 GHz grid, for a 60λ
   link-budget estimate vs. a 64-lane RTL test ceiling. A THIRD document,
   `gcb-spec/bench_emulation_parameters.md` (the doc `gcb-wiki/16` itself
   names as Part 9's nominal parameter owner), describes something
   structurally different again: a single O-band wavelength combined via
   a fused-fiber power/intensity coupler tree - not WDM at all. None of
   the three match `gcb-pic-core`'s own K=16 binary-tree assumption
   (channel count or combining mechanism), and no document anywhere
   states which of these `gcb-pic-core`'s tile actually is.
3. **Did not pick a number.** Per this program's own standing discipline
   and `TKT-031`'s own precedent (an architecture conflict escalated to
   the Architect, not resolved by the loop), wrote this up as a new
   ticket (`TKT-033`) with four named candidate framings for the
   Architect to choose among, left genuinely open.

**What was done - Part B (FDTD/EME survey):**
1. Checked what this environment can actually run, per `TKT-030`'s own
   "not yet confirmed available" flag. `pip index versions meep`
   resolves and downloads a 4.3 KB wheel - **unzipped it and read its own
   METADATA rather than trusting the package name**: it is an unrelated
   CI/CD task runner ("Very light-weight task runner... triggered by VCS
   hooks"), NOT the MIT FDTD simulator (which is conda-forge-only, not on
   PyPI, under this name). Caught exactly like the AWG's own "builds
   without raising an exception" trap - reading actual content, not
   absence of an error.
2. `tidy3d` is real cloud-hosted FDTD but needs an external account/API
   key - flagged, NOT created, pending Architect authorization (an
   external-service signup is outward-facing and hard to reverse).
3. `femwell` (pure-Python FEM mode solver/EME, open-source, no license)
   installed cleanly into its own dedicated venv (`~/.venvs/femwell`,
   kept separate from `~/.venvs/gdsfactory` - heavier, partially
   overlapping dependency tree: VTK, `cadquery-ocp`, `gmsh`,
   `scikit-fem`), ~90s, zero native build failures.
4. Built and ran a real FEM mode-solve for a 500x220nm silicon strip
   waveguide cross-section at 1.31 um (O-band, the one concrete
   wavelength this program's docs commit to anywhere). First attempt hit
   a real, ordinary API error (`mesh_from_OrderedDict` returns a
   `meshio.Mesh`, not an skfem-native mesh - needed
   `skfem.io.meshio.from_meshio()` conversion), fixed and re-run.
5. Reproduced the result byte-identically across two independent fresh
   process invocations before committing.

**Test results (actual):**
```
n_eff (real): 2.684623
n_eff (imag): ~1e-16 (numerical noise, not a loss measurement - no Im(n) input)
```
Textbook-consistent for these dimensions/wavelength.

**Epistemic status: PROVEN — DIGITAL FEM SIMULATION, TESTED CONDITIONS**
for `n_eff`'s real part at the stated geometry/wavelength/index
assumptions (reproduced twice independently). **UNPROVEN/escalated**:
which physical subsystem `gcb-pic-core`'s K=16 tile represents (Part A,
held for Architect disposition); any real channel spacing, insertion
loss, or crosstalk figure for the actual MZI-lattice combiner (out of
scope this session - materially bigger 3D/coupled-mode work, same
caution `TKT-030` used before attempting the full K=16 layout).

**Commits:**
- `gcb-pic-core@23ec5dd` - `mode_solve_strip.py` +
  `requirements-femwell.txt` added, pushed, `HEAD == origin/main`
  verified.
- `gcb-workspaces` (this commit) - new ticket
  `TKT-033-channel-spacing-conflict-and-fdtd-eme-survey.md` (`open |
  pending`, no PBG grade per architecture-conflict-ticket doctrine),
  `README.md` filetree + status table entries added, this summary entry
  appended.

**Ticket status changes:** New ticket `TKT-033` created, `open |
pending`. Does not close `TKT-030` (already `done | blue`) or any other
existing ticket.

**Next candidate (per the Architect's own stated sequencing):** `TKT-032`
(gcb-host) build-and-run verification pass - **note for whoever picks
this up**: `TKT-032` was already closed this same session
(`done | blue`) with a full 5-step survey; Step 2 found `src/`/`tests/`
both completely empty (nothing to build), and Step 3 redirected to
`gcb-rtl`'s own regression, which passed clean. Re-opening it for a
"build-and-run pass" should start by reading `TKT-032`'s existing
Execution Log rather than repeating the survey - the one real gap it
flagged but did not pursue is `tools/hf_manifest_gen.py`, not yet read in
detail.

---

## Post-loop directed continuation 4 — 2026-09-12 (TKT-032 build-and-run pass, sequenced second target)

**Context:** the Architect's sequencing named TKT-032's "build-and-run
verification pass" as the second target, after the channel-
spacing/FDTD-EME phase (previous entry). Checked first, per this
program's own discipline, rather than assuming the premise: `TKT-032` was
already closed this same session (`done | blue`, full 5-step survey).
Re-confirmed the closure still held (src/tests still empty, no build
system had appeared), then pursued the one real gap that survey itself
flagged but did not pursue: `tools/hf_manifest_gen.py` had been read, but
never run.

**What was done:**
1. Read `hf_manifest_gen.py` in full - a real, substantial (~725-line)
   HuggingFace config -> GreenCoyote hardware-manifest generator +
   negotiation engine.
2. Ran it for real (`--local`, no network dependency) against a
   synthetic 70B-dense-model config (Llama-3.1-70B-Instruct-shaped) and a
   small dense config. Large model: correctly `REJECTED` (384 tiles
   needed vs. the 16-tile prototype default, real warnings about
   attention/feed-forward tiling and long-context KV cache). Small
   model: correctly `DEGRADED`/accepted-with-warnings.
3. **Caught and corrected a false lead in my own verification, not the
   tool**: reading `$?` immediately inside the same `wsl bash -c '...'`
   invocation that ran the script showed `0` for the `REJECTED` case -
   looked like a real bug against the script's own documented
   `exit_codes` mapping (`REJECTED -> 1`). Ran a minimal control
   (`false; echo $?`, no Python at all) inside the identical invocation
   shape and reproduced the same wrong `0` - proving this is a WSL
   `$?`-inside-invocation quirk, unrelated to `hf_manifest_gen.py`.
   Re-checked the real exit code from OUTSIDE the `wsl` call: genuinely
   `1` for `REJECTED`, `0` for `DEGRADED` - correct, as documented. Not
   reported as a tool bug.
4. Added `gcb-host/tests/test_hf_manifest_gen.py` - the first real test
   in that previously-empty directory: 3 scenarios (large dense, small
   dense, a DeepSeek-V3-shaped MoE config for expert-count/active-expert
   extraction), 13 self-checking assertions, driven by direct import
   (sidesteps the exit-code quirk entirely rather than working around
   it indirectly). All 13 pass, reproduced across two independent runs.
5. Committed to `gcb-host@d4be571`, pushed, `HEAD == origin/main`
   verified.

**Test results (actual):**
```
test_dense_large_model_rejected:  5/5 PASS (REJECTED, needs 384 tiles)
test_small_dense_model_degraded:  3/3 PASS (DEGRADED, fits with tiling)
test_moe_expert_count_detected:   4/4 PASS (256 experts, 8 active, extracted correctly)
ALL CHECKS PASS
```

**Epistemic status: PROVEN — DIGITAL SIMULATION (direct Python
execution), TESTED CONDITIONS** for the 3 scenarios' negotiation-logic
outcomes and real exit codes, reproduced twice. No claim about the actual
FPGA/XRT hardware path - `HardwareManifest.from_fpga()` returns a
hardcoded prototype default, not a live register read, unchanged and not
exercised here.

**Commits:**
- `gcb-host@d4be571` - `tests/test_hf_manifest_gen.py` added, pushed,
  `HEAD == origin/main` verified.
- `gcb-workspaces` (this commit) - `TKT-032` follow-up Execution Log
  appended (status unchanged, `done | blue`), `README.md` TKT-032
  entries updated, this summary entry appended.

**Ticket status changes:** None - `TKT-032` remains `done | blue`; this
is incremental follow-up closing its own previously-flagged gap, not a
reopening.

**Next candidate:** per `TKT-033`'s own "Required work," the Architect's
disposition on which physical subsystem `gcb-pic-core`'s K=16 tile
represents (Part A) is the highest-leverage next item - it blocks any
real channel-spacing value from being committed. Absent that, the next
self-directed candidate would be extending `mode_solve_strip.py`'s FEM
approach toward the actual MZI-lattice coupler geometry (materially
bigger work, flagged as deferred in `TKT-033` Part B finding #5).

---

## Architect correction — 2026-09-12 (gcb-wiki is not source of truth; TKT-033 resolved decisively; TKT-030 corrected)

**Context:** after reporting TKT-033 as a "four-way architecture conflict
held for Architect disposition," the Architect corrected the underlying
methodology: `gcb-wiki` is the human-readable view OF `gcb-spec`, not a
parallel source of truth. Escalating a wiki-vs-spec divergence as an
unresolved conflict between co-equal sources was itself the error - the
real resolution path was to check `gcb-spec` directly. Instructed to
apply this and make the TKT-033 decision directly, and to retain the
correction for future sessions.

**What was done:**
1. Saved a standing methodology memory (`gcb-wiki-not-source-of-truth`)
   capturing the correction for future application on this program (and
   generalized: any project with a derived human wiki alongside an
   authoritative spec/model directory should default to the spec as
   ground truth).
2. Checked `gcb-spec` directly, exhaustively (grep across its full
   working tree, not a sampled read): "Component 4," "balanced-homodyne,"
   "multiplier tile," "K=16" appear **nowhere** in it. The entire K=16
   WDM framing `TKT-030` spent most of this session building toward
   traces to `gcb-wiki` alone - and `gcb-pic-core`'s own `README.md`
   cites `../gcb-wiki` `goal.md`, not `gcb-spec`, as its source - the
   root cause.
3. Found what `gcb-spec` actually says instead: `gcb-spec/task3_physical_bom.md`
   (Phase I BOM) specifies a single O-band 1310nm CW laser with one
   linear VOA modulator; `gcb-rtl/sim/mmi_tree_model.py` (Task 1's own
   numerical model) explicitly describes "a SINGLE 8-input cell... The
   MMI tree is a POWER-SUMMING combiner" - single wavelength, no
   WDM/dispersive element anywhere, `n_inputs=8` by default. That
   model's own `K` means a cascade-stage count (`8^K` units through `K`
   stages), a second, independent terminology collision with this
   session's "K=16 = 16 simultaneous wavelengths" assumption.
4. **Resolved `TKT-033` Part A decisively**: channel spacing is not
   merely unresolved for `gcb-pic-core`'s tile - it is not the right
   concept, because the tile's WDM premise itself has no `gcb-spec`
   grounding. Flipped `TKT-033` from `open|pending` to `done|blue`.
5. Flagged both divergent `gcb-wiki` passages (doc 15's 50GHz-grid
   `ASSUMPTION`, doc 16 Part 9's DWDM-mesh framing) for human maintainer
   review - not corrected unilaterally, since either could be a genuine,
   separate future-phase concept missing its `gcb-spec` citation, or
   stale text (`gcb-wiki@3f8a319`, pushed).
6. Built the real, spec-grounded replacement: `mmi_power_tree.py` in
   `gcb-pic-core` - a binary tree of plain, non-dispersive `mmi1x2()`
   power combiners (no wavelength-dependent parameter at all), `n=8`
   matching `mmi_tree_model.py`'s default. Reused `wdm_combiner_tree.py`'s
   own balanced-tree Y-placement fix, but had to re-sweep spacing
   constants empirically - the smaller `mmi1x2` footprint reproduced the
   exact same class of `get_netlist()` port-overlap defect at the
   original spacing. Verified for N in {2,4,8,16}, zero `route_single`
   warnings AND clean `get_netlist()`, reproduced byte-identically across
   two independent fresh processes. Caught and fixed a real latent bug in
   the `route()` helper's dead fallback branch (undefined name) before
   running it. Committed `gcb-pic-core@5063bb2`, pushed,
   `HEAD == origin/main` verified.
7. Corrected `gcb-pic-core/README.md`'s "Near-term goals" to cite the
   real component and flag the `gcb-wiki` citation as root cause
   (`e08defd`). Did NOT delete `wdm_combiner_tree.py`/`k16_tile.py` - kept
   as real, working WDM-combiner code, explicitly flagged as not
   currently targeted.
8. **Found, flagged, did NOT fix** (explicit scope boundary, not an
   oversight): the same grep check applied to `gcb-pic-core`'s own core
   "Role" description (the A+B/A-B homodyne multiply, "Invariant #6")
   also finds zero readable matches in `gcb-spec`'s working tree - a
   materially bigger question than K=16 alone (the original multiply
   operation, not new-this-session work). Opened `TKT-034` as an intake
   placeholder, matching `TKT-032`'s own original precedent for a bounded
   first pass - not investigated further this session.
9. Corrected `TKT-030`'s own record honestly: appended a full correction
   section rather than silently editing its prior claims, updated its
   telemetry (spec 0.95->0.7, emergence 0.45->0.7 - the methodology
   finding is worth more than the layout work it corrects).

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED
CONDITIONS** for `mmi_power_tree(8)`'s two-check validation, reproduced
twice. **RESOLVED BY DIRECT SPEC CHECK** (not an estimate or a disposition
held open) for TKT-033's channel-spacing question. **OPEN, FLAGGED, NOT
INVESTIGATED**: whether `balanced_homodyne_cell()`'s own multiply
operation is `gcb-spec`-grounded (`TKT-034`).

**Commits:**
- `gcb-pic-core@5063bb2` - `mmi_power_tree.py` added, pushed.
- `gcb-pic-core@e08defd` - `README.md` near-term goals corrected, pushed.
- `gcb-wiki@3f8a319` - two divergent passages flagged for human review, pushed.
- `gcb-workspaces` (this commit) - `TKT-030` correction appended,
  `TKT-033` resolved (`open|pending` -> `done|blue`), new `TKT-034`
  intake ticket, `README.md` entries updated, this summary entry
  appended.
- Local memory: `gcb-wiki-not-source-of-truth.md` + `MEMORY.md` index
  created (not a repo commit - session-persistent memory for future
  sessions on this program).

**Ticket status changes:** `TKT-033`: `open|pending` -> `done|blue`.
`TKT-030`: remains `done|blue`, corrected in place (telemetry updated).
New `TKT-034`: `open|pending`.

**Next candidate:** `TKT-034`'s own investigation (whether the core
multiply operation is spec-grounded) is the natural next step, same
family as this correction. Absent that, extending `mode_solve_strip.py`'s
FEM approach toward the real MMI power-combiner geometry (not just a bare
waveguide) to get a genuine insertion-loss figure for `mmi_power_tree.py`
remains the other open thread from `TKT-033` Part B.

---

## Directed continuation — 2026-09-12 (TKT-035: full system hardware inventory reconstruction, Pass 1)

**Context:** the Architect supplied a standing reconstruction prompt
(`GCB System Hardware Inventory — Gemini + Orange-Team Prompt.md`) and
asked whether `TKT-034` was close to it; if not, to open it as a new
ticket and work it. Checked: not close (`TKT-034` is a narrow single-
component grounding check; the prompt is an 11-section, program-wide
reconstruction with strict Orange-Team evidence-category discipline).
Opened `TKT-035` and executed Pass 1 directly.

**Treated the source prompt itself per this program's own standing
doctrine**: AI-facing framing ("Gemini + Orange-Team," "may be passed to
another LLM") - a task specification, not evidence. `gcb-wiki/15` and
`/16` appear to be prior output from this same (or a closely related)
prompt, and this session already found real ungrounded content in both
(`TKT-033`) - so this reconstruction was done fresh from repo/`gcb-spec`
evidence directly, not as a touch-up of the existing docs.

**What was done:**
1. Surveyed all repos under `D:\R\S\H\` (READMEs + structure) for the
   functional parts inventory.
2. Found real, concrete evidence not previously surfaced this session:
   `gcb-rtl`'s `greencoyote_top` has an actual Vivado 2024.2 post-route
   checkpoint (`post_route.dcp`) targeting `xcu55c-fsvh2892-2L-e` (Alveo
   U55C), OOC mode, all timing constraints met (WNS +0.261 ns),
   real utilization (602 LUT, 8 DSP48E2) and a vectorless power estimate
   - a materially higher evidence tier than anything else found this
   session, confirmed by direct read of the checkpoint's own README.
3. Diffed `gcb_wavelength_router.sv` between `gcb-wdm-transceiver` and
   `gcb-photonic-qam-v2` (both contain a file of this name) - confirmed a
   real fork-divergence (124 vs. 99 lines, `N_LAMBDA` parameterization
   added in one copy only), exactly the "repository names that refer to
   different architectural generations" contradiction class the source
   prompt names.
4. Read `gcb-spec/architecture.md` directly - found it names exactly
   five canonical repos (`gcb-spec`, `gcb-rtl`, `gcb-host`,
   `gcb-dashboard`, `gcb-papers`) around a single-wavelength, power-
   summing optical cascade. **This does not include** `gcb-wdm-
   transceiver`, `gcb-photonic-qam-v2`, `gcb-pic-core`, `gcb-analog-rx`,
   or `gcb-python-orchestrator` - five repos with real, substantial work
   that all self-identify as part of the same program but describe a
   materially different (WDM/multi-channel) optical mechanism.
5. **Synthesized this into the session's biggest structural finding**:
   two largely separate architectural tracks coexist under one program
   name - Track A (`gcb-spec`-grounded, real FPGA P&R evidence, real host
   driver) and Track B (`gcb-wiki`-narrated, no dedicated spec repo of
   its own, no FPGA/ASIC evidence). This plausibly EXPLAINS `TKT-033`'s
   earlier finding: the 60λ/50GHz-grid figures most likely belong to
   Track B's `gcb-wdm-transceiver` (a real, separate, regression-tested
   DWDM component), not `gcb-pic-core`'s tile - two genuinely separate,
   both-real optical subsystems previously conflated by `gcb-wiki`'s own
   cross-references.
6. Built and committed `reports/system_hardware_inventory_pass1.md`: a
   master hardware inventory (evidence-category-labeled per the source
   prompt's own taxonomy, both tracks), a 4-entry contradiction register,
   a system-boundary statement (Vortex confirmed as real, substantial,
   independently-maintained upstream IP - no GCB-specific files found
   inside the vendored `vortex/` tree itself), functional-completeness
   gaps, and a dependency map for Track A.
7. Created `TKT-035` recording the task, honestly scoped as "Pass 1, not
   exhaustive" - flagged three repos (`gcb-python-orchestrator`,
   `gcb-dashboard`, `vortex`'s non-TCU surface) as shallow-pass only, and
   several prompt deliverable sections (equipment matrix, DFT matrix) as
   deferred rather than rebuilt from scratch this pass.

**Epistemic status: PROVEN — DIRECT EVIDENCE** for every concrete claim
in the report (the Vivado checkpoint's real contents, the file diff, the
architecture.md text, the repo structure survey) - all read/checked
directly this pass, not inferred. **UNKNOWN/OPEN**: which of the four
framings in Contradiction Register entry 1 (Track A/B relationship) is
correct - explicitly left open per the source prompt's own "do not
choose a winner silently" rule.

**Commits:**
- `gcb-workspaces` (this commit) - new ticket `TKT-035`, new report
  `reports/system_hardware_inventory_pass1.md`, `README.md` entries
  added, this summary entry appended.

**Ticket status changes:** New ticket `TKT-035`: `open | pending`
(Pass 1 delivered, explicitly not exhaustive).

**Next candidate:** deepen the three shallow-pass repos, or pursue
Contradiction Register entry 1 directly with the Architect (is Track B
superseded by, parallel to, or meant to merge with Track A?) - the
highest-leverage open question this pass surfaced.

---

## Directed /loop — 2026-09-12 (simplify and resolve TKT-035's Track A/B split)

**Context:** the Architect asked for a simpler answer and the best
solution, implemented and verified, not just decided in prose - while
keeping existing real work intact ("don't throw the baby out with the
bath water").

**Simple answer**: Track A is Phase I (the real, current system). The
"Track B" repos are mostly Phase II (this program's own forward roadmap),
not a rival architecture - the confusion was a citation gap.

**Implemented and verified**: found `gcb-spec/docs/optical_geometry_spec.md`
(LOCKED v1.0.0, missed in the earlier check) - it sizes a Phase-II
integrated array at `L=16` contraction lanes/channel/fire, single
wavelength, no channel mux. That is the real number behind
`gcb-pic-core`'s "K=16" - the WDM label was wrong, the number wasn't.
Updated `mmi_power_tree.py` to build+verify both real targets (N=8
Phase-I bench, N=16 Phase-II - the real "K=16"), reproduced clean across
two independent processes, committed (`gcb-pic-core@79e9c58`, `87de269`,
pushed, `HEAD==origin/main` verified).

Checked (not yet confirmed) the other four "Track B" repos against Track
A's real architecture: `gcb-python-orchestrator` plausibly matches too
(its compiler targets "the Photonic + Vortex hybrid fabric" - Track A's
exact data path); `gcb-wdm-transceiver`/`gcb-photonic-qam-v2` most likely
genuinely separate, real subsystems (Track A is explicitly single-
wavelength); `gcb-analog-rx` needs a direct check against ADR-005's
retired delta-sigma branch.

**Commits:** `gcb-pic-core@79e9c58`/`87de269` (pushed, verified);
`gcb-workspaces` (this commit) - `TKT-030` refinement, `TKT-035`
resolution section, `README.md` updated, this entry appended.

**Ticket status changes:** none flipped - `TKT-030` stays `done|blue`
(refined), `TKT-035` stays `open|pending` (one of five repos confirmed
reconciled, four with a stated best guess, not yet confirmed).

**Next candidate:** confirm `gcb-python-orchestrator` and `gcb-analog-rx`
against Track A directly (both plausible, neither confirmed).

---

## Directed continuation — 2026-09-12 (confirm gcb-analog-rx against ADR-005)

**Directed task:** check `gcb-analog-rx`'s switched-charge integrator
against `gcb-spec/docs/adr/ADR-005-Single-Slope-Readout.md` directly -
the one remaining concrete check flagged in the prior entry.

**Answer: neither ADR-005 candidate - a genuinely separate, third Rx
variant, not reconciled.**
- NOT the retired ΔΣ branch: no feedback-nulling loop, no 1-bit
  quantizer, no decimated bitstream.
- NOT the winning Single-Slope CIS either: shares the same passive-
  integration-onto-`C_int` front end, but uses a flash/comparator-bank
  ADC back-end instead of Single-Slope's ramp + shared 6GHz Gray-counter
  TDC; modeled window (`T_int`=200ps, `F_CLK`=5GHz) doesn't match
  ADR-005's own LOCKED window (`T_obs`=256ns) by over 1000x - built
  independently of ADR-005's real numbers, not calibrated against them.

**Consequence**: `TKT-031`'s own "Phase I BASELINE" disposition was made
without checking that `ADR-005` (Accepted 2026-09-07, before `TKT-031`'s
disposition) already locked a different, already-synthesized circuit
for the same role. `TKT-031`'s own dynamic-range verification stands on
its own terms - not overridden - but the ticket now carries a flag for
the Architect, not a silent reconciliation.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (both documents read in
full, mechanisms compared point by point: front-end physics, back-end
quantizer type, window timing).

**Commits:** `gcb-workspaces` (this commit) - `TKT-031` flag appended,
`TKT-035` resolution section updated (4 of 5 "Track B" repos now
checked), `README.md` updated, this entry appended. No code changes this
turn - this was a documentation/spec cross-check only.

**Ticket status changes:** none flipped - `TKT-031` stays `done|blue`
(flagged in place), `TKT-035` stays `open|pending` (`gcb-python-
orchestrator` is now the one remaining unchecked item).

---

## Open-ended continuation — 2026-09-12 (confirm gcb-python-orchestrator; TKT-034 resolved; self-correction of same-day overreach)

**Context:** directed to continue open-ended, not stopping on my own
judgment. Started with the one remaining TKT-035 item
(`gcb-python-orchestrator` vs. Track A), then followed the evidence
where it actually led - including back into my own immediately-prior
conclusion.

**What was done:**
1. Read `gcb-python-orchestrator/scheduler.py`'s own comment: it tiles
   contractions at `K <= 16`, citing `gcb-photonic-qam-v2/intent.md`'s
   "Software Tiling Constraint" - NOT `gcb-spec`.
2. Read that constraint directly: derived from a balanced-homodyne
   SNR/phase-noise budget, for the SAME A+B/A-B multiply mechanism
   `gcb-pic-core`'s own `balanced_homodyne_cell()` implements -
   `intent.md`'s own words: "square-law photodiodes extract... 4Re(AB*),
   the physical basis of the MAC." Word-for-word match, not a guess.
3. Read `gcb-wdm-transceiver/rtl/gcb_dwdm_pkg.sv`: `K_MAX = 16`, real
   synthesizable RTL, commented "a HARD cross-architecture invariant."
4. Confirmed `packer.py` (the compiler's INT4 byte-packer) explicitly
   copies `gcb_dwdm_pkg::pack_int4`'s bit convention "not reinvented" -
   `gcb-python-orchestrator` is this program's own compiler.
5. Noticed both `gcb-pic-core` and `gcb-analog-rx` self-describe, in
   their own README headers, as **"the GCB Photonic QAM Accelerator"** -
   a real, named second program I had not registered on an earlier pass.
6. **Caught and corrected my own immediately-prior conclusion**: the
   previous turn matched `gcb-pic-core`'s K=16 to `gcb-spec`'s
   `L_CONTRACT=16` (Track A) on numeric coincidence, without checking
   this far more specific, mechanism-matching source. Corrected on
   `TKT-030` (a new "Correction of the above" section, not a silent
   edit), resolved `TKT-034` with the real answer, and rewrote `TKT-035`
   around a simpler, final "two named programs" structure. Simplified
   the `TKT-031`/`ADR-005` flag from the prior entry: it was never a
   real conflict needing reconciliation - `gcb-analog-rx` belongs to the
   QAM Accelerator program, `ADR-005` to the other one; they were never
   competing.

**Epistemic status: PROVEN — DIRECT EVIDENCE** for every claim (RTL
comments, `intent.md` text, README self-descriptions, all read directly,
word-for-word mechanism matches confirmed, not inferred). The new
topology hypothesis (16 multiply cells + 2 summing trees + 1 shared PD
pair) remains **UNPROVEN** - a strong, specific, evidence-backed lead,
not yet built.

**Commits:** `gcb-workspaces` (this commit) - `TKT-030` correction-of-
correction, `TKT-034` resolved (`open|pending` -> `done|blue`), `TKT-035`
rewritten around the two-program structure, `TKT-031` simplified,
`README.md` updated throughout, this entry appended. No code changes
this turn - continuing into the real topology build next.

**Ticket status changes:** `TKT-034`: `open|pending` -> `done|blue`.
`TKT-030`, `TKT-031`, `TKT-035`: status unchanged, content corrected.

**Next candidate:** build the real topology (16 `balanced_homodyne_cell()`
multiply units -> two `mmi_power_tree`-style summing trees -> one shared
PD pair) in `gcb-pic-core`, verified the same way as every other layout
this session - continuing now, per the open-ended directive.

---

## Open-ended continuation — 2026-09-12 (built the real topology: qam_reduction_cell.py)

**What was done:** built `gcb-pic-core/qam_reduction_cell.py` -
16 `multiply_tap()`s (the MMI-coupler half of `balanced_homodyne_cell()`,
SUM/DIFF outputs left optical, no photodiodes yet) feeding two
`power_tree()`s (one per SUM/DIFF family, reusing `mmi_power_tree.py`'s
binary-tree technique) feeding one shared photodiode pair at the end -
the exact topology `TKT-030`'s own correction hypothesized. Clean on the
first real attempt (0 `route_single` warnings, `get_netlist()` OK);
re-verified per this program's own established discipline anyway, not
trusted on one pass - byte-identical across two independent fresh
processes and across a full N in {2,4,8,16} sweep.

**Epistemic status: PROVEN — DIGITAL LAYOUT SIMULATION, TESTED
CONDITIONS** for the route_single + get_netlist() results, reproduced
twice. **UNPROVEN**: real insertion loss/crosstalk, or Architect
confirmation this is the final topology.

**Commits:** `gcb-pic-core@50845b6` (pushed, `HEAD==origin/main`
verified); `gcb-workspaces` (this commit) - `TKT-030` build record,
`README.md`, this entry.

**Next candidate (continuing open-ended, per the Architect's own
directive):** deepen the remaining shallow-pass repos from `TKT-035`
(`gcb-dashboard`, `vortex`'s non-TCU surface).

---

## Open-ended continuation — 2026-09-12 (deepened gcb-dashboard + vortex, closing TKT-035's last shallow-pass items)

**What was done:**
1. Read `gcb-dashboard`'s `Makefile` comment directly: it explicitly
   renders RTL tops from BOTH named programs (`gcb-rtl` + `gcb-photonic-
   qam-v2`), deliberately excluding `gcb-wdm-transceiver` - confirms
   this repo is cross-cutting infrastructure, not evidence for either
   program.
2. **Ran `make doctor` for real** (not assumed): passes cleanly - full
   render toolchain genuinely installed and functional (`sv2v v0.0.12`,
   `Yosys 0.68`, `node v22.22.1`, `yosys2digitaljs`, `elkjs`), `outputs/`
   holds 17 fresh SVGs.
3. Checked the React dashboard directly: `GreenCoyoteDashboard.jsx` is
   real, substantial code (514 lines, genuine hooks + default export),
   but `package.json` declares no `react`/`react-dom` dependency and no
   build/dev/start script anywhere - IMPLEMENTED, not buildable as
   configured. A real, previously-unrecorded gap.
4. Confirmed `vortex`'s System Boundary conclusively, not by inference:
   `git remote -v` shows the real upstream origin
   (`vortexgpgpu/vortex.git`), `git log` shows genuinely unrelated
   upstream commits, and an exhaustive grep for "greencoyote"/
   "GreenCoyote"/"ODIN_Bridge" across the entire tree returns zero
   matches.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (a real command run with
real output, `git remote`/`git log`/exhaustive grep, direct file reads -
none of this inferred from naming or absence alone).

**Commits:** `gcb-workspaces` (this commit) - `TKT-035` deepening
section, Pass-1 report updated (depth note, inventory table corrections
including the now-superseded "K=16 revoked" row), `README.md`, this
entry. No code changes - documentation/verification only.

**Ticket status changes:** none flipped - `TKT-035` stays `open|pending`
(equipment/DFT deliverable sections remain the one genuinely open item
from the original 11-section prompt).

**Next candidate:** the equipment/DFT matrices (`TKT-035`'s own last
open item), or pull the next real priority item from the broader
backlog per the open-ended directive.

---

## Open-ended continuation — 2026-09-12 (TKT-019.8 stale cross-reference corrected)

**What was done:** picked up `TKT-019.8` (a genuinely open integrity-
mitigation story, found by checking actual ticket content rather than
trusting frontmatter status, per this session's own established
discipline). Its own "Not yet done, pending disposition of Findings A
and B" text was stale - `TKT-019.10` already resolved both (Finding A:
a deterministic length-count gate; Finding B: a CDC watchdog-arming FSM,
Candidate 2, after Candidate 1 was implemented, found by a purpose-built
adversarial test to introduce a WORSE regression, and cleanly reverted).
Independently re-ran `test_wdm_link_integration.py` fresh:
`TESTS=22 PASS=22 FAIL=0 SKIP=0`.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (read `TKT-019.10` in
full, re-ran the real regression suite myself rather than trusting its
quoted numbers).

**Commits:** `gcb-workspaces@295c742` (pushed, verified) - `TKT-019.8`
corrected (status unchanged, per this epic's own convention).

**Next candidate:** continuing open-ended per the Architect's directive.

---

## Open-ended continuation — 2026-09-12 (consistency sweep: everything touched this session re-verified fresh)

**What was done:** re-ran every real test/build this session has depended
on, fresh, to confirm nothing was left broken: `gcb-rtl`'s full
regression (`tb_cs_fifo_path`, `tb_dma_integration`, `tb_ss_calib`
10000/10000, `tb_ss_tdc` - all PASS); all five `gcb-pic-core` gdsfactory
scripts (`layout_homodyne.py`, `wdm_combiner_tree.py`, `k16_tile.py`,
`mmi_power_tree.py`, `qam_reduction_cell.py` - all clean, identical
output to their last recorded results); `gcb-host`'s
`test_hf_manifest_gen.py` (13/13 PASS).

**Epistemic status: PROVEN — DIRECT EVIDENCE**, fresh re-run, not
re-stated from memory.

**No commits** (verification only, nothing changed). Continuing
open-ended to the next backlog item.

---

## Open-ended continuation — 2026-09-12 (capstone: gcb-papers resolves the "16 vs channel-spacing" pattern)

**What was done:** checked `gcb-papers` - one of `gcb-spec`'s own five
canonical Track-A repos, never actually inspected despite all the
reconciliation work this session. Found a real 3-paper research arc
that cleanly explains the whole pattern chased across `TKT-030`/`TKT-033`/
`TKT-034`: Paper 1 (cascaded reduction) matches Track A's real model;
**Paper 2 (Reduction Fabric Interface) is explicitly a coherent-QAM/WDM
interconnect replacing PCIe between compute units, with its own real
channel plan (8 channels, 200 GHz C-band spacing)**; Paper 3 unifies
multiply+reduce in the photonic domain, citing Paper 2's QAM as the
transport between units, not the compute mechanism itself.

**Resolution**: reduction-depth ("16," compute layer) and channel
spacing (transport layer) are two genuinely different parameters for two
genuinely different layers of one overall vision - never the same
number, never a coincidence, never fabricated. This revises (does not
reverse) `TKT-033`'s finding: `gcb-pic-core`'s K=16 still has no WDM
requirement of its own; the broader program's real channel-spacing
numbers belong to a genuinely separate transport layer that always
needed one.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (all three papers read
directly; cited as evidence of intent/architecture, not verified
silicon - these are draft arXiv papers).

**Commits:** `gcb-workspaces` (this commit) - `TKT-035` capstone section,
`README.md`, this entry.

**Ticket status changes:** none - `TKT-035` remains `open|pending`
(equipment/DFT matrices still the one stated remaining item).

---

## Open-ended continuation — 2026-09-12 (resolved gcb-wiki's own flagged UNVERIFIED provenance item)

**What was done:** `gcb-wiki/15`'s own §1/§11 had already, correctly,
flagged the `gcb_bitplane_tx_mapper.sv` fork-provenance claim as
`UNVERIFIED` in an earlier session - this session's own direct evidence
(the `gcb-wdm-transceiver` README's explicit fork statement + the
`gcb_wavelength_router.sv` diff, both already gathered for `TKT-035`)
resolves it. Updated both locations in doc 15 to CONFIRMED.

**Commits:** `gcb-wiki@ded1367` (pushed, verified).

**Next candidate:** checking whether the Cyclopter/pgvector deployment
(`gcb-python-orchestrator/deploy/cyclopter/`) - referenced repeatedly
this session as "real" infrastructure - is actually running, not just
described.

---

## Open-ended continuation — 2026-09-12 (Cyclopter/pgvector execution status: could not verify)

**What was done:** checked whether `gcb-python-orchestrator/deploy/
cyclopter/`'s PostgreSQL+pgvector deployment (referenced repeatedly this
session, subject of `GCB-039` Objective B) is actually running or has
ever actually been run. `docker` is not installed in either WSL or the
Windows host - could not verify by running it myself. No exported data/
logs/artifacts from a past run exist anywhere in the git-tracked repo.
Did not install Docker to force a check (too large an environment
change to make unilaterally). A real, thoughtful config detail (port
5433 "avoids the Windows PG17 on 5432") suggests it probably was run at
least once on a real machine - just not leaving git-tracked evidence.

**Recorded as**: CONFIG EXISTS (real, well-documented) / EXECUTION
STATUS UNKNOWN - not overclaimed either way. Matches a pattern found
repeatedly this session: real config/code rarely actually executed
end-to-end in a way that leaves evidence (the React dashboard build gap,
`gcb-host`'s empty src/tests).

**Commits:** `gcb-workspaces` (this commit) - `TKT-035` section, this
entry. No code changes.

---

## Open-ended continuation — 2026-09-12 (toolchain availability checks, README fix, doctrine-consistency confirmed clean)

**What was done:**
1. Checked OpenROAD/ORFS availability (relevant to `TKT-020`'s still-
   open "heavier OpenROAD place-and-route question"): not installed in
   this environment (only `yosys` found) - meaning `GCB-027/029/030/032`'s
   physical-synthesis findings (dated two days before this session,
   same session ID) ran in a different environment than this one. Noted,
   not forced - did not attempt to install OpenROAD.
2. Fixed a real, simple, previously-flagged-but-never-corrected
   documentation defect: `gcb-host/README.md` still said "FastAPI MMIO
   proxy" - `TKT-032` found and flagged this exact inaccuracy earlier
   this same session, but the README line itself was never actually
   updated. Corrected now (`gcb-host@79dbba1`, pushed, verified).
3. Read `gcb-spec/ai-agents/` (the "paved road" persona-prompt triad,
   referenced by `gcb-spec`'s own README as required reading, never
   actually inspected until now). Found a minor, cosmetic discrepancy
   (architecture.md says "Five repositories," this doc says "six" -
   adds `gcb-wiki`) - not contradictory, not urgent. Checked the
   maintenance-mandated "GCB STATE COMPRESSION" block consistency
   across all three agent files for real drift: **clean** - every key
   number checked (53 µV comparator noise, 56 dB SNDR, 0.55 fJ/MAC)
   matches exactly across all three, confirming this program's own
   doctrine-sync discipline is genuinely being followed, not just
   described.

**Epistemic status: PROVEN — DIRECT EVIDENCE** throughout (toolchain
checks run for real, README read and fixed directly, doctrine files
cross-checked by grep across all three, not sampled).

**Commits:** `gcb-host@79dbba1` (pushed, verified). No `gcb-workspaces`
commit needed for items 1/3 (no ticket claims were found stale enough
to require correction beyond what's recorded here).

**Assessment at this point in the open-ended run:** this tick's sweep
(toolchain availability, README audit, doctrine consistency) found one
real fix and two clean confirmations, in contrast to earlier ticks'
denser finding rate. The readily-accessible, safely-actionable surface
of this workspace has now been swept broadly: architecture reconciliation
(Track A/B, `TKT-033`/`034`/`035`, the `gcb-papers` capstone), multiple
ticket corrections, several new verified `gcb-pic-core` components, a
regression re-run confirming `TKT-019.8`'s stale text, toolchain
availability checks (Docker and OpenROAD both found unavailable here),
and now a documentation/doctrine-consistency audit. Continuing
open-ended per the Architect's own standing instruction not to stop on
my own judgment - the next tick will look for newly-available signal
(a fresh backlog scan, or anything the Architect adds) rather than
re-sweeping ground already covered.
