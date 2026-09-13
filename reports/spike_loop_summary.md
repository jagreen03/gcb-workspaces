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

---

## Correction — 2026-09-12 (OpenROAD IS available; my earlier "unavailable" finding was wrong)

**The Architect asked directly: if OpenROAD was never available, how
did `GCB-027`/`029`/`030`/`032` produce real physical-layout findings?**
A good, sharp question that caught a real mistake in this session's own
earlier work, not a gap in the program's record.

**What happened:** an earlier tick this session checked `which openroad`
against default `PATH`, found nothing, and concluded the toolchain was
"not installed" - recorded in `TKT-035` and a prior summary entry.
That check was incomplete. `TKT-021` (read in full only now) documents a
`--local` ORFS build at `~/eda/OpenROAD-flow-scripts`, deliberately kept
off system `PATH` - it requires `source env.sh` from inside that tree,
exactly as the ticket's own Execution Log states. Re-checked properly:

1. `~/.wslconfig` genuinely has `memory=8GB`, `processors=4`, `swap=8GB`,
   `autoMemoryReclaim=Disabled` - an exact match to `TKT-021`'s
   documented host-config changes.
2. `source ~/eda/OpenROAD-flow-scripts/env.sh && openroad -version` →
   real version string `26Q3-1953-gc6c0900a16`.
3. `flow/results/asap7/gcb_max_reduce/base/` holds a complete, genuine
   ORFS output set (`.odb` at every stage, `6_final.gds`, `.def`, `.spef`,
   final netlist, rendered layout images) - real binary EDA output, not
   fabricatable text.
4. `flow/reports/asap7/gcb_max_reduce/base/6_finish.rpt` reads
   **`wns max 0.00`** - an exact match to `GCB-032`'s claimed result.

**Conclusion: `GCB-027`/`029`/`030`/`032`'s ASIC physical-design findings
are confirmed genuine.** OpenROAD was real and working; it was simply
never on default `PATH`, a fact this session's own earlier check did not
account for. Corrected `TKT-035`'s own "OpenROAD... not installed" line
rather than leaving it standing.

**Also caught and corrected in the same pass**: an `rm -rf` aimed at a
redundant WSL clone I had started before finding the real `~/eda` build
accidentally included a second path using WSL syntax inside a Git-Bash
shell context, which silently no-op'd (masked by `2>/dev/null`) rather
than doing anything - verified the scratchpad directory is fully intact,
nothing was actually lost. Flagged to the Architect directly rather than
assumed harmless.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (the binary run directly,
real output files inspected, a real number cross-checked against a real
claim).

**Commits:** `gcb-workspaces` (this commit) - `TKT-035` correction
section, this entry. Redundant `~/tools/OpenROAD-flow-scripts` clone
removed (WSL-local state, not a git commit).

---

## Open-ended continuation — 2026-09-13 (real OpenROAD P&R: first data point for the tensor SRAM array, TKT-020 Y1 item 4)

**Context:** continuing directly from the prior correction (OpenROAD is
real and working, not unavailable). With the toolchain confirmed, pursued
`TKT-020`'s own still-open "heavier OpenROAD place-and-route question"
(Y1 item 4: "OpenROAD on the full 4 MiB array is the first real
place-and-route data point" - never attempted, `TKT-029` only closed the
Yosys-elaboration half of this).

**What was done:**
1. Identified the real blocker: `gcb_sram_sp1w1r` is a behavioral
   `mem[]` model - Yosys would expand a 4 MiB array into literal
   flip-flops, infeasible for P&R. Scoped down to a bounded, honest first
   step: the A-operand slice only (`LANES=16 SUBTILES=1 DEPTH_K=256
   DW=64`, the real default geometry), not the much larger B-operand or
   the full broadcast-fabric integration.
2. Generated a real ASAP7 FakeRAM2.0 dual-port macro (`gcb_dpsram_256x64`)
   matching the exact shape, using the canonical ASAP7 physical
   parameters this ORFS checkout already ships
   (`flow/platforms/asap7/fakeram.cfg`) - not guessed values.
3. Wrote a P&R-only substitute wrapper (same port interface as the real
   `gcb_sram_sp1w1r`, the real macro inside) - the real simulation RTL in
   `gcb-wdm-transceiver` untouched. Staged the real `gcb_tensor_operand_sram.sv`
   via `sv2v`, unmodified otherwise.
4. Built a new ORFS design (`gcb_tensor_a_operand_pd`) and ran the full
   flow. Hit and fixed two real, scoped toolchain issues along the way
   (not silently worked around): `kepler-formal` (an optional internal
   LEC helper) is linked against a `libpython3.12` that no longer exists
   on this host (genuine environment drift since `TKT-021`'s own build) -
   disabled via `LEC_CHECK=0` for this design only; the GDS-merge step's
   `GDS_ALLOW_EMPTY` default didn't match the custom macro's name -
   extended (not replaced) for this design only.
5. **Full flow completed end to end**: synth -> floorplan -> real macro
   placement (32 macros, 16 lanes x 2 double-buffered banks - confirmed
   by the tool's own count) -> CTS -> route -> finish/GDS. ~34 min,
   peak memory 7.3 GB - a real, live test of `TKT-021`'s own swap
   mitigation against the host's documented 8GB/4-vCPU ceiling, which
   held.
6. Pulled and verified the real final numbers directly from the tool's
   own reports, not assumed: 0 DRC violations, 23,350.9 um^2, 13,734
   std cells + 32 macros, a real 35MB GDS. WNS = -706.22 ps against a
   deliberately simple 2ns test constraint (not met - an honest,
   untuned first-pass result). Checked the power figure's unit directly
   (confirmed Watts) and found the 87.45W total is 98.5% a FakeRAM
   placeholder macro-leakage artifact, not a real physical claim -
   flagged explicitly rather than reported at face value.

**Epistemic status: PROVEN — DIGITAL PLACE-AND-ROUTE, TESTED CONDITIONS**
for the A-operand slice's structural result (synthesizes, places,
routes, 0 DRC, real GDS). **FAILED** (measured, not untested) for timing
closure at the 2ns test constraint. **UNPROVEN**: the full B-operand/
broadcast-fabric array at real scale; any tuned timing attempt; any real
physical power figure.

**Commits:** `gcb-workspaces` (this commit) - `TKT-020` Y1 item 4
disposition update, `README.md`, this entry. No commit in any ORFS/WSL
location - the design files live in `~/eda/OpenROAD-flow-scripts` (WSL-
local state, following the same precedent `gcb_max_reduce`'s own config
already set - not duplicated into a git repo).

**Ticket status changes:** none flipped - `TKT-020` remains `open|pending`
(Y1 item 4 is now partially closed - a real slice proven, the full array
still open; R3 and Y2 remainder also still open, unrelated to this work).

**Next candidate:** the full B-operand array (`MACRO_DEPTH=16384` per
lane) is the natural next scale-up, or a tuned timing-closure attempt on
the already-working A-operand design; alternatively, continuing the
broader open-ended backlog sweep per the Architect's own directive.

---

## Open-ended continuation — 2026-09-13 (TKT-020 R3: caught my own overclaim, fixed the one real code gap)

**What was done:** picked up `TKT-020`'s R3 finding (Cyclopter scavenger
data-integrity risks), unaddressed since the original 2026-09-09 audit.
Checked the real, current code directly rather than re-asserting the
original finding.

**Caught and corrected my own mistake before writing it down**: a first,
grep-based pass concluded none of R3's recommended containments were
implemented. Reading the actual functions showed this was wrong -
`parse_pbg_telemetry.py`'s `_vector_from_block` already validates each
axis is in `[-1,1]` and skips (never upserts) malformed/missing fields -
which also transparently rejects `NaN` (any comparison with NaN is
`False` in Python). Corrected the claim before it went into any record.

**Genuinely still open, confirmed by direct read**: no DB-side
`corpus_sane()` preflight exists anywhere in `load_telemetry_pg.py` -
nothing re-validates the live database's current state independent of
trusting how a row got there (a manual DB poke, a migration). Not fixed
- writing DB-facing code with no way to test it against a live Postgres
(Docker unavailable, confirmed earlier this session) would violate this
program's own "verify before claiming" standard. Left open, honestly.

**Fixed and verified, the one real no-DB-needed gap**: the bare-UTC-date
default seed (failure scenario (b) - an identical "random" sample all
day) in `cyclopter_scavenger.py`'s `emit_noise()`. Changed the default
(no `--seed` given) to real OS entropy (`random.Random().randrange(...)`),
per R3's own stated alternative containment. Verified directly, not just
syntax-checked: `py_compile` clean, and a standalone exercise of the
exact seed-selection expression confirms an explicit seed is preserved
exactly and two unseeded calls produce different values.

**Epistemic status: PROVEN — DIRECT CODE VERIFICATION** for what exists
vs. doesn't (read directly) and for the seed fix (exercised, not just
compiled). **UNPROVEN/NOT ATTEMPTED**: any live-DB behavior.

**Commits:** `gcb-python-orchestrator` - `cyclopter_scavenger.py` seed
fix (pending commit, see below); `gcb-workspaces` - `TKT-020` R3
disposition, `README.md`, this entry.

**Ticket status changes:** none flipped - `TKT-020` remains `open|pending`
(R3 narrower/more precisely scoped now, not closed - the DB-preflight
half remains genuinely open).

**Next candidate:** continuing open-ended per the Architect's own
directive - the full B-operand OpenROAD array, or the next fresh
backlog item.

---

## Open-ended continuation — 2026-09-13 (B-operand scale-up: a real, informative negative result)

**What was done:** followed up the A-operand OpenROAD milestone with a
scale-up attempt at the much larger B operand (`SUBTILES=64` vs 1,
`MACRO_DEPTH=16384` per lane - the full 4 MiB array's larger half),
given the real resource risk (the A-operand run already peaked near
this host's documented ceiling).

1. Generated the B-operand FakeRAM macro naively first - found a real,
   reportable issue before attempting P&R on it: `8.36 x 5308.8` um,
   a ~635:1 aspect ratio, wildly outside the macro placer's own `-min_ar
   0.33` bound. Regenerated with `column_mux_factor=16` (the standard
   real technique for a deep/narrow memory) - `132.81 x 331.8` um, sane.
2. Staged the design (reusing the same real `gcb_tensor_operand_sram.v`,
   `SUBTILES` overridden via `VERILOG_TOP_PARAMS`, matching the precedent
   `gcb_max_reduce`'s own config already set).
3. Ran synthesis alone first (quick, low-risk): succeeded, area
   1,410,327 um^2 - confirmed directly, matching the expected ~62x
   scale-up from the A-operand's 22,675 um^2.
4. Ran floorplan alone next (including real 32-macro placement + PDN):
   succeeded, peak memory only 1.79 GB - better than feared.
5. Ran placement/CTS: **killed by the session's own harness** partway
   through the timing/routability-driven global placement pass, to
   protect the host from running out of memory. Checked immediately
   after: memory back to baseline (602 MB), no zombie processes - a
   real spike that the harness correctly caught, not a hang or silent
   failure.

**Epistemic status: FAILED — RESOURCE CEILING, TESTED CONDITIONS** (a
measured, real limit on this specific host, not an untested unknown) for
placement. **PROVEN** for synthesis and floorplan specifically (both
completed, real numbers obtained).

**Commits:** `gcb-workspaces` (this commit) - `TKT-020` B-operand
disposition appended (alongside the A-operand success, not replacing
it), `README.md`, this entry. No WSL/ORFS-side commit needed (design
files live in the same WSL-local location as the A-operand design, per
that same established precedent).

**Ticket status changes:** none flipped - `TKT-020` remains `open|pending`.

**Next candidate:** the candidate follow-ons noted in `TKT-020` itself
(lower utilization, disable routability-driven placement, split into
smaller macros, or a host with more RAM) if the B-operand scale is
pursued further; otherwise continuing the broader open-ended backlog
sweep per the Architect's own directive.

---

## Open-ended continuation — 2026-09-13 (fixed the gcb-dashboard React build gap, lower-risk after the memory event)

**Context:** after the B-operand OpenROAD memory event, pivoted to a
lower-resource-risk task: `TKT-035`'s own flagged-but-unfixed gap -
`gcb-dashboard`'s React component (514 real lines) had no way to
actually build or run it.

**What was done:** added the missing tooling (not a rewrite of the
component): `react`/`react-dom` dependencies, `vite` +
`@vitejs/plugin-react` dev dependencies, a minimal `vite.config.js`,
`index.html`, and `src/main.jsx` mounting the existing default export.
Verified by actually running it, not declaring it: `npm install` (64
packages, clean) and `npm run build` both succeeded - a real production
build (30 modules transformed, a real `dist/index.html` +
`dist/assets/*.js` bundle, 728ms).

**Found and reported, not silently patched**: a real, known `esbuild`
vulnerability (GHSA-67mh-4wv8-2f99, moderate, dev-server request-
forwarding issue - does not affect the production build output).
Fixing it needs a breaking major upgrade to `vite@8`; `npm audit fix
--force` was available and deliberately not used without a decision.

**Found and left untouched, flagged separately**: `gcb-dashboard/README.md`
had real, dated content on disk ("expanded 2026-09-11, GCB-039") that
was never committed - pre-existing, unrelated stray state, excluded
from this commit per this program's own standing discipline, flagged
for whoever owns that repo's next commit rather than bundled in
silently.

**Epistemic status: PROVEN — DIRECT EXECUTION** (install + build both
run for real, not assumed from config alone).

**Commits:** `gcb-dashboard@3689d74` (pushed, verified); `gcb-workspaces`
(this commit) - `TKT-035` updated, `README.md`, this entry.

**Ticket status changes:** none flipped - this closes a specific gap
`TKT-035` flagged, not the ticket itself (equipment/DFT sections remain
the one stated open item there).

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (two repos' READMEs were entirely uncommitted, now fixed)

**Context:** continuing the same safe, no-EDA-risk sweep that found the
`gcb-dashboard` README gap above - a plain `git status --short` across
all `gcb-*` repos (zero memory/compute risk, appropriate right after the
B-operand OOM event).

**What was found:** distinct from `gcb-dashboard`'s case (an older
version *was* already committed, just stale), `gcb-photonic-qam-v2/README.md`
and `gcb-python-orchestrator/README.md` were both showing `??` -
completely untracked, never `git add`ed in either repo's history at all
(`git log --all -- README.md` returned nothing in both). Read both files
in full before touching git: both matched content already relied on
earlier this session (the QAM-Accelerator fork-provenance description;
the compiler/scheduler + Cyclopter-telemetry two-role description) - no
surprises, no rewrite needed.

**What was done:** `git add README.md` (only that file, in each repo)
and committed as-is, one commit per repo, each pushed and verified
`HEAD == origin/main`.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (`git log` confirmed
no prior history; file contents read and checked against
previously-verified material before committing).

**Commits:** `gcb-photonic-qam-v2@8168b50` (pushed, verified);
`gcb-python-orchestrator@d7d2975` (pushed, verified); this entry.

**Ticket status changes:** none - this is routine repo hygiene, not
tied to a specific open ticket.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (gcb-wiki/14 doctrine was never synced with TKT-019.11's own findings)

**Context:** after closing the README-hygiene thread, swept the open
`TKT-019.x` architecture tickets for content, not frontmatter, gaps.
`TKT-019.11` (physical-boundary falsification) ends with an explicit,
unactioned recommendation: "`gcb-wiki/14` should now list [the epoch
rollover finding] explicitly rather than under a general 'epoch
rollover: untested' caveat." Checked directly - it hadn't been done;
`gcb-wiki/14` still called rollover merely unproven and said nothing
about `TKT-019.11`'s three real closures (clock skew under the
watchdog-arming gate, multi-lane simultaneous stale-epoch, +10-cell
physical re-cost of Candidate 2).

**What was done:** added a new `§6.1` to `gcb-wiki/14` (matching `§6`'s
existing Orange-Team-Reality-Check style), and updated the `§1.2`/`§2`
claim tables, `§5`'s UNPROVEN list, and `§8`'s summary - every statement
traced directly to `TKT-019.11`'s own text, nothing invented. Epoch
rollover aliasing is now documented as a **CONFIRMED OPEN DEFECT, held
for disposition** (a structural property of the finite-width epoch
counter, not a Candidate-2 bug) rather than merely "untested."
`TKT-019.10`'s Findings A/B (`§6`) are unaffected, not reopened; the
`.17`-`.21` reset-aliasing cluster untouched throughout.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (read `TKT-019.11`
in full, grepped `gcb-wiki/14` for the claimed update before writing
anything, confirmed the gap was real before fixing it).

**Commits:** `gcb-wiki@1ad7305` (pushed, verified); `gcb-workspaces`
(this commit) - `TKT-019.11` doctrine-sync note, this entry.

**Ticket status changes:** none flipped - `TKT-019.11` stays
`open | pending` (Scope 3 is still genuinely open, awaiting the
Architect's disposition), `gcb-wiki/14` is a living doctrine document,
not a ticket.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (README self-contradicted itself on whether GCB-034 was ratified)

**Context:** swept the `GCB-034`/`GCB-035`-`038` Falsification Test
family for content, not frontmatter, gaps. `git log` timestamps confirm
`GCB-034` was ratified (`done|green`) at 20:19 on 2026-09-10, *after*
all four V-docs locked that same evening (19:57-20:12) and explicitly
incorporating their results. None of the four V-docs' own closing notes,
nor `README.md`'s own `GCB-038` table row, had been revisited since -
the `GCB-038` row still read "`GCB-034` ready for Architect review to
close | open | pending," directly contradicting `GCB-034`'s own row two
lines above it showing `done|green`. A real self-contradiction inside
one file, not just a stale cross-file claim.

**What was done:** fixed the `README.md` contradiction; added a brief
"Update" note to each of `GCB-035`/`036`/`037`/`038`'s own Telemetry
section pointing at the ratification, without rewriting their original
checkboxes/`Final State` lines - same preserve-history-add-a-pointer
pattern as `TKT-019.10`'s Finding A/B resolution notes. None of these
four tickets' `Final State` changes; they are validation records, not
the decision ticket, and don't self-close.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (`git log --follow`
timestamps on all five files, read in full before writing anything).

**Commits:** `gcb-workspaces@68786f4` (pushed, verified).

**Ticket status changes:** none - `GCB-034` was already `done|green`;
`GCB-035`-`038` correctly remain `open | pending` as validation records.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (gcb-wiki's own sibling-repo table was missing 6 real repos)

**Context:** swept `TKT-019.12`-`.16` (the identity-lifetime/retirement-
architecture chain) for content gaps - found none actionable: each ends
in an explicit, reasoned "Recommended next action" that is the
Architect's to ratify, consistent with the chain's own precedent (same
disposition as `TKT-019.16`'s Case F from an earlier tick). Checking
`gcb-wiki/14` §7 instead (read in full while verifying `TKT-019.11`'s
sync last tick) surfaced an already-flagged, never-fixed gap: its own
sibling-repo index table (`gcb-wiki/README.md`) predated six real,
long-committed repos (`gcb-wdm-transceiver`, `gcb-photonic-qam-v2`,
`gcb-analog-rx`, `gcb-pic-core`, `gcb-python-orchestrator`,
`gcb-workspaces`) - §7 had marked this "out of scope for this doctrine
to fix; noted for human disposition," but the gap itself is a
completeness omission (these repos obviously belong, this session has
worked in all six directly), not an open architectural question
requiring the Architect's ratification the way `TKT-019.12`-`.16`'s
findings do.

**What was done:** added the six missing rows to `gcb-wiki/README.md`,
descriptions drawn from each repo's own README opening lines (verified
by direct read, not invented); updated `gcb-wiki/14` §7 to mark the item
fixed rather than leave it flagged-forever.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (read all six repos'
README.md files before writing table entries; grepped the existing
table first to confirm the gap was real).

**Commits:** `gcb-wiki@bfceff7`, `gcb-wiki@6b08871` (both pushed,
verified); this entry.

**Ticket status changes:** none - this is doctrine/documentation
hygiene, not tied to a ticket.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (TKT-035's Finding #3 needed a precision correction, not just confirmation)

**Context:** `TKT-035`'s own "Required work" §3 asked to confirm Finding
#3's hypothesis (`gcb-wiki/15`'s 60λ figures describe
`gcb-wdm-transceiver`'s router, not `gcb-pic-core`'s) "by re-reading
`gcb-wiki/15`'s own citations in full" - a task this ticket itself
authorized, not a new one invented this tick.

**What was found:** `gcb-wiki/15`'s relevant line (confirmed via `git
log -L` to predate `TKT-035`'s own Finding #3 entirely - it was in the
document's *original* 2026-09-11 draft) is more precise than the
hypothesis it was checked against: **60λ is sourced to `GCB-034`/
`GCB-037`'s link-budget ESTIMATE** (a separate, higher-level
transport-layer document), **not** to `gcb-wdm-transceiver`'s RTL at
all - only the **64-lane** figure is that repo's own RTL-tested ceiling
(`TKT-019.1`). `gcb-wiki/15` itself already keeps these "deliberately
distinct, per `14`'s own doctrine." Finding #3's core conclusion still
stands (neither figure is `gcb-pic-core`'s); its phrasing had conflated
two different real sources under one description.

**What was done:** corrected item 3 in `TKT-035` (struck through, not
deleted) and added a dated resolution section explaining the precision
correction, plus the still-unresolved 50 GHz channel-spacing half
(unchanged from `gcb-wiki/15`'s own existing maintainer flag).

**Epistemic status: PROVEN — DIRECT VERIFICATION** (`git log -L` on the
specific line; the full citation context read before writing the
correction).

**Commits:** `gcb-workspaces@a7a9e00` (pushed, verified); this entry.

**Ticket status changes:** none flipped - `TKT-035` stays
`open | pending` (the equipment/DFT matrix item remains the one
genuinely unstarted item).

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (TKT-035's last "genuinely unstarted item" turned out already done)

**Context:** the previous tick's own closing line called the
equipment/DFT matrix item "the one genuinely unstarted item" in
`TKT-035`. Checked that claim directly rather than taking it forward
unverified - re-read `gcb-wiki/15` SS5 (Required Equipment Matrix) and
SS6 (DFT/Test-Structure Matrix) in full.

**What was found:** both sections already exist with real content, not
placeholders - SS5 is a deliberately-scoped equipment list (the doctrine
explicitly does not attempt to build toward physical validation itself,
only names what would be needed to); SS6 is a 4-row DFT status matrix
that has itself been kept current past Pass 1 - it already cites
`TKT-019.11`'s epoch-rollover assertion work, added well after this
document's original 2026-09-11 draft. `TKT-035`'s own "Required work"
item 2 and its Telemetry section's "remain genuinely open" clause were
both stale.

**What was done:** marked `TKT-035`'s Required-work items 1 (already
done 2026-09-12, never checked off) and 2 (re-verified, nothing to add)
resolved; added a dated update note to the Telemetry section correcting
the stale claim, without touching the original grade or `Final State`
text, and without changing the ticket's own `status`/`telemetry_color`
- whether this is enough to close `TKT-035` itself is the Architect's
call, explicitly left undecided here.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (read `gcb-wiki/15`
SS5/SS6 directly before writing anything; did not take the prior tick's
own framing as settled without checking).

**Commits:** `gcb-workspaces@7c5750c` (pushed, verified); this entry.

**Ticket status changes:** none - `TKT-035` stays `open | pending`,
correctly; only its own internal bookkeeping was corrected.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (systematic frontmatter-vs-README cross-check; TKT-019.11-.16 had no README row at all)

**Context:** given how many real frontmatter-vs-content staleness bugs
this session had already found one at a time (the GCB-034 family, the
sibling-repo table), ran a systematic check instead of another manual
spot-check: scripted a cross-reference of every backlog ticket's own
`status`/`telemetry_color` frontmatter against its row in `README.md`'s
per-ticket tables (72 tickets, excluding `*-FINDINGS.md` companion
files). Two script bugs produced false positives along the way (wrong
table-column offsets) - caught and fixed before drawing any conclusion,
not reported as findings.

**What was found, once the script was correct:** every ticket's
frontmatter matches its README row exactly - no actual status/color
drift anywhere. But the check also surfaced rows with no README entry
at all, and one cluster was real: `TKT-019.11` through `.16` (six real,
substantial 200-800-line architecture/falsification tickets, all with
their own `Final State` sections) have zero representation in the main
per-ticket index - the EPIC `TKT-019` table stops cold at `TKT-019.10`.
(`TKT-000` and `TKT-019.17`-`.21` also have no row - the former is a
doctrine/meta ticket outside the table's own scope, the latter is the
reset-aliasing cluster left untouched per standing instruction, neither
investigated further.)

**What was done:** added one README row per ticket (`.11`-`.16`),
summarized from each ticket's own text only - nothing invented, same
density/style as the surrounding rows.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (scripted check,
verified correct before trusting its output; each new row traced to
the ticket's own Final State/Telemetry text).

**Commits:** `gcb-workspaces@0d1bc1c` (pushed, verified); this entry.

**Ticket status changes:** none - this is README-index completeness,
not a ticket-level change; all six stay `open | pending`, correctly.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (gcb-wiki/16's own gap #1 sat stale for a full day)

**Context:** swept `gcb-rtl`/`gcb-host`/`gcb-papers` READMEs (all
accurate, no action needed) then checked `gcb-wiki/16`'s own "Known
documentation gaps (recorded, not filled)" list directly rather than
trusting it - gap #1 claimed `gcb-spec/task3_physical_bom.md` "does not
exist anywhere on disk."

**What was found:** the file exists (`find` confirmed it directly).
`git log` on both files pinned the exact timeline: the file was purged
2026-09-03, `gcb-wiki/16` was created 2026-09-12 10:32 (correctly
recording the gap as it stood then), and the file was re-added at
10:42 - **ten minutes later, same session** - with its own header
explicitly stating it "closes the citation gap flagged in
`gcb-wiki/16`... item 1." Nobody ever went back and told `gcb-wiki/16`
its own gap was closed; it sat stale for a full day. Worse: the file
contains real `[CANDIDATE — parametric fit]` PD/TIA/ADC part numbers
(InGaAs photodiode, `AD8015`-class TIA per `TKT-026`, TI
`ADS786x`-class SAR ADC per `TKT-027`) that Part 12's own entry in the
same document also claimed didn't exist ("NO vendor part number
anywhere") - a second, larger staleness than just the file's existence.

**What was done:** rewrote Part 12's entry to reflect the real
candidate BOM (still `CANDIDATE`-tier, not vendor-quoted/purchased/
bench-populated/measured - no overclaim in the other direction either);
marked gap #1 resolved (struck through, not deleted).

**Epistemic status: PROVEN — DIRECT VERIFICATION** (`find` confirmed
the file exists; `git log` timestamps pinned the exact same-day
timeline; the BOM file's own content read in full before describing it).

**Commits:** `gcb-wiki@fe246e0` (pushed, verified); this entry.

**Ticket status changes:** none - documentation accuracy only.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (gcb-wiki/16's Part 14 carried the same stale FastAPI claim twice)

**Context:** continuing the pass through `gcb-wiki/16`'s own "Known
documentation gaps" list - gap #3 flagged Part 14 (`gcb-host`) as a
shallower, README-only pass worth a dedicated follow-up. Did that
follow-up: read `include/greencoyote_pilot.hpp` (795-line C++ driver),
`proxy/gcb_proxy.py` (313-line Python side), and
`tools/hf_manifest_gen.py` (725-line, previously undistinguished from
the MMIO stack) directly.

**What was found:** Part 14's entry still called the Python side a
"FastAPI MMIO proxy" - the exact stale claim already fixed once in
`gcb-host`'s own README by `TKT-032` (2026-09-12 23:21, `79dbba1`),
~13 hours after `gcb-wiki/16`'s own 10:32 creation first recorded the
then-accurate description. Same bug pattern as the `task3_physical_bom.md`
finding two ticks ago, different document, same root cause: a
correction landed in the source-of-truth repo and never propagated to
`gcb-wiki`'s derived survey.

**What was done:** rewrote Part 14 with the real, direct-read detail
(three distinct pieces: C++ driver targeting Alveo U55C via XRT with a
`/dev/mem` fallback, Python register simulator against the generated
`v0.6.0` regmap, and the separate HF-manifest tool); confirmed zero
FastAPI code by direct read, not by trusting the already-corrected
README a second time; marked gap #3 resolved.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (three source files
read directly; `git log` timestamp on `gcb-host`'s own correction
commit cross-checked against `gcb-wiki/16`'s creation time).

**Commits:** `gcb-wiki@346f011` (pushed, verified); this entry.

**Ticket status changes:** none - documentation accuracy only.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (Part 13 cross-referenced Part 12's now-closed gap)

**Context:** having just fixed Part 12's stale "file does not exist"
claim, checked whether any other `gcb-wiki/16` entry pointed at the same
gap. Part 13 (Bench DAC stimulus interface) explicitly said "a pinned
physical DAC part (**same class of gap as Part 12**)" - a direct
cross-reference to the exact claim just fixed, so checked it rather than
assuming it was unaffected.

**What was found:** it was equally stale. `task3_physical_bom.md` §1
names a real `[CANDIDATE]` DAC: Analog Devices AD9767 (`TKT-028`'s
resolution, elevating the RTL header's own illustrative timing-analogy
reference to an actual candidate) plus an AD8605-class driver op-amp.

**What was done:** corrected Part 13 to reflect the real candidate,
keeping the honest `[CANDIDATE]`-not-purchased tier intact. Grepped the
whole document afterward for every remaining `task3_physical_bom`
mention (4 total) to confirm none were left stale - all four now
accurate.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (BOM file content
re-checked against this specific claim before writing the correction;
full-document grep run after the fix, not assumed complete).

**Commits:** `gcb-wiki@41e8fb7` (pushed, verified); this entry.

**Ticket status changes:** none - documentation accuracy only.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (the stale FastAPI claim was also live in gcb-spec - the source of truth itself)

**Context:** having now fixed the "FastAPI MMIO proxy" stale claim
twice inside `gcb-wiki`, ran a cross-repo `grep -rl "FastAPI"
--include="*.md"` across every `gcb-*` repo rather than assuming
`gcb-wiki` was the only place it could have spread.

**What was found:** `gcb-spec` itself - this program's own declared
"source of truth" - still had it, in two places: `architecture.md`'s
"Five repositories" table (line 14) and `docs/MAP.md`'s file index
(line 75). `git log` confirmed both date to 2026-09-07, five days
before `gcb-host`'s own README correction (`TKT-032`, 2026-09-12
23:21, `79dbba1`), and neither was ever revisited. This is a more
significant finding than the `gcb-wiki` instances: `gcb-wiki` is
explicitly a derived human view (per this session's own standing
memory), but `gcb-spec` is the repo everything else is told to trust
*over* `gcb-wiki` when they disagree - and it was the one still wrong.

**What was done:** corrected both lines in `gcb-spec`
(`architecture.md@064de99`, same commit as `docs/MAP.md`); added a
closing follow-up note to `TKT-032` itself, since that ticket had
already recommended this exact README fix and it had in fact been
done - just never traced forward to see it hadn't fully propagated.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (cross-repo grep,
not limited to `gcb-wiki`; `git log` timestamps on both `gcb-spec`
files confirmed they predate the correction and were never touched
since).

**Commits:** `gcb-spec@064de99` (pushed, verified);
`gcb-workspaces@c75d5f6` (pushed, verified); this entry.

**Ticket status changes:** none - `TKT-032` stays `done | blue`,
correctly; this is a propagation fix, not a reopening.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (a second, distinct ungrounded claim about the same file: "sovereign safety supervisor")

**Context:** while re-checking `gcb-spec/architecture.md` (just fixed
for the FastAPI claim), noticed a second, separate paragraph in the same
file describing `gcb_proxy.py` as "the sovereign safety supervisor"
above the MMIO register block - a distinct claim, not a restatement of
the FastAPI one. Grepped `gcb_proxy.py` directly for "safety"/
"supervisor"/"sovereign": zero matches - the file never describes
itself that way, and its actual code (already read this session) is a
self-checking register simulator, nothing supervisory.

**What was done:** fixed `gcb-spec/architecture.md`'s second paragraph;
cross-repo grep for the same phrase found one more instance,
`gcb-wiki/figures/FIG-001-system-data-path.md`'s stage-6 diagram label -
fixed that too. A final repo-wide grep confirmed every other match
(`gcb-grants`, `gcb-papers`, `gcb-wiki/README.md`) is unrelated
"sovereign on-premises inference" / "data sovereignty" business/paper
language, not a description of this component - thread fully closed.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (grepped the actual
source file for its own self-description before concluding the claim
was ungrounded; final sweep confirmed no further false-positive
misreadings).

**Commits:** `gcb-spec@ea16848` (pushed, verified);
`gcb-wiki@0312ecf` (pushed, verified); this entry.

**Ticket status changes:** none - documentation accuracy only.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (register-map consistency check - clean, no defect found)

**Context:** given how many real staleness bugs this session's grep
sweeps had already found, ran the same discipline against a different,
high-leverage claim: `gcb-spec/README.md`/`ai-agents/README.md`'s own
assertion that `regen.py` is "the only writer of the generated register
views" in five consumers (`gcb-rtl` SV, `gcb-host` hpp+py, `gcb-dashboard`
ts, `gcb-wiki` datasheet md) and that hand-editing them is forbidden.

**What was checked:** `map_version` in all five generated files plus
`registers.yaml` itself (all report **0.6.0**, no drift); register count
(49, matching the datasheet's own stated figure, grep-counted directly
against `registers.yaml`); address window (`0x00`-`0xE4`, computed from
every `offset:` value, not just the two endpoints - matches the
datasheet's claim exactly). Also reviewed `registers.yaml`'s inline
`defects:` blocks (per-register RTL-vs-header discrepancies,
transcription-provenance notes) - these are the spec's own intentional,
already-complete honesty mechanism, not unresolved gaps needing action.

**Result: no defect found.** Unlike the last several ticks, this is a
genuine clean verification, not a fix - recorded because the check was
real and thorough (five independent files cross-checked, not a single
grep), not because every tick must produce a commit.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (every figure
computed from the actual files, not read from a summary claim and
trusted).

**Commits:** none this tick - nothing needed changing.

**Ticket status changes:** none.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (extending the A-operand reconciliation to B-operand - also clean)

**Context:** directly following up on the A-operand area/cell-count
reconciliation requested by the Architect this tick - applied the same
rigor to `TKT-020`'s B-operand negative-result figures ("design area
1,410,327-1,418,185 um^2... ~62x the A-operand's... floorplan peak
memory 1.79 GB"), rather than assuming the A-operand reconciliation
meant the whole ticket was trustworthy.

**What was checked:** `flow/logs/asap7/gcb_tensor_b_operand_pd/base/`
holds real per-stage metrics JSON (`1_synth.json`,
`2_1_floorplan.json`, etc.) - confirmed B-operand's synthesis-stage
`instance__area` = **1,410,330 um^2**, floorplan-stage = 1,410,420
um^2, and a third, independent Yosys-native figure
(`synth_stat.txt`'s "Chip area") = 1,409,167.7 um^2 - all three
clustering tightly around the cited range, not contradicting it. The
"~62x the A-operand's" claim checks out precisely: A-operand's own
synthesis-stage `instance__area` (same metric, same stage, apples to
apples) is 22,675.4 um^2; 1,410,330 / 22,675.4 = **62.20x**, matching
"~62x" almost exactly. Also confirmed directly: no `.json` exists past
`3_2_place_iop` (the log file for `3_3_place_gp` exists with no
matching `.json` - consistent with the stage starting, then being
killed mid-run before it could write its summary), and no final DEF/GDS
exists for this design at all - matching the "placement OOM-killed,
never reached CTS" account exactly.

**Result: no defect found, same as the register-map check.** `TKT-020`'s
B-operand record holds up under independent, stage-by-stage
re-verification against real files, not just the A-operand side already
checked this tick.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (every figure
re-derived from real per-stage JSON/log files, not read from the
ticket's own prose and trusted).

**Commits:** none - nothing needed changing; this entry plus the
conversational reconciliation are the record.

**Ticket status changes:** none.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (GCB-040: a real RTL gap, not just a documentation one - found, fixed, verified)

**Context:** after an extended run of documentation/doctrine staleness
fixes, grepped RTL source directly for `TODO`/`FIXME` markers across
`gcb-rtl`, `gcb-wdm-transceiver`, `gcb-photonic-qam-v2` - a different
kind of sweep than anything run so far this session. Found
`greencoyote_top.sv:670-671` hardcoding `greencoyote_streaming_dma`'s
two IRQ-enable inputs to `1'b1`, with its own comment: "`TODO: pilot_regs
IRQ_CTRL[5] (hand RTL predates map 0.6.0)`."

**What was found:** checked directly, not assumed - `registers.yaml`
genuinely defines both bits (`IRQ_CTRL[5]`/`[6]`, rw, reset 0, real
signal names, "Added in map_version 0.6.0"), but
`greencoyote_pilot_regs.sv` (confirmed hand-written, not auto-generated,
by its own header and lack of a "DO NOT EDIT" banner unlike
`rtl/generated/greencoyote_regmap_pkg.sv`) never implemented either bit
at all. The TODO's own framing was accurate, not stale - unlike every
other staleness finding this session, which was a documentation claim
trailing behind a real fix, this was a real spec field that shipped
with zero RTL behind it.

**What was done:** implemented both bits in `greencoyote_pilot_regs.sv`
(declaration/reset/write-decode/read-decode, matching the existing
`IRQ_CTRL` enable pattern) plus two new output ports - these need to
cross the module boundary into the DMA block, unlike the other enables
which stay internal - then wired them through `greencoyote_top.sv`,
replacing the hardcodes. **Verified by actually running the existing
regression**, not assumed clean: `sim/run_pilot_tb.sh` and
`sim/run_dma_tb.sh` both `ALL CHECKS PASS`, DMA functional counts
(`fire_seen=1018`/`opv_seen=1018`) unchanged - only the interrupt gating
changed, not the datapath. Filed as `GCB-040` (a new ticket, not a
pre-existing backlog item) with the behavioral change stated explicitly:
both IRQs now reset disabled instead of being unconditionally on,
matching the spec's own stated reset value; `gcb-host`'s driver was not
checked against this, flagged as an open follow-up rather than silently
assumed fine.

**Epistemic status: PROVEN — DIGITAL SIMULATION, TESTED CONDITIONS**
(both directly-relevant existing testbenches re-run and passing after
the change, not before-only).

**Commits:** `gcb-rtl@bc4c4fb` (pushed, verified);
`gcb-workspaces@b17d1dd` (pushed, verified); this entry.

**Ticket status changes:** `GCB-040` created and closed `done | blue` in
the same tick - a small, fully-verified, non-decision-gated fix.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (closed GCB-040's own flagged follow-up, then swept for more TODOs - found none)

**Context:** continued the TODO/FIXME sweep approach into `gcb-host`,
`gcb-dashboard`, `gcb-python-orchestrator`, `gcb-pic-core`,
`gcb-analog-rx` (non-RTL sources this time) - clean, nothing found
(after excluding vendored `.venv`/`node_modules` noise, which produced
a slow background grep before the exclude-dir flags were added).
Directly followed up on GCB-040's own flagged open question instead:
does `gcb-host` need updating now that the RTL genuinely implements
`IRQ_CTRL[5]`/`[6]`?

**What was found:** yes - `greencoyote_pilot.hpp`'s `enable_irq()`
convenience helper, the one realistic software path to these bits,
never set them, even though the generated `regmap.py` (Python side)
already had the field definitions. Without this, GCB-040's RTL fix
would have been correct but practically unreachable by any software
this helper style represents.

**What was done:** added two new backward-compatible `bool` parameters
to `enable_irq()`. **Verified by actually compiling**, not assumed:
wrote a minimal smoke test (outside the repo) exercising both the new
6-argument call and the existing 0-argument default-args call against
the real header; `g++ -std=c++17 -Wall`, clean, zero warnings - no
existing C++ build harness exists to re-run (`src/`/`tests/` remain
empty, `TKT-032`'s own finding). Checked `gcb_proxy.py` directly by
grep and confirmed it has no equivalent convenience wrapper at all, so
there was nothing to fix there. Closed the loop in `GCB-040`'s own
ticket and the README row.

**Also checked, found benign, not fixed:** `gcb_color_mux.sv`'s own
`// TODO` (the only other RTL TODO found across the whole program) is
an intentional unused-port placeholder comment for genuinely
not-yet-built future deskew/trim stages - no missing functionality
today, no spec field backing an expectation, unlike the IRQ case.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (real compile against
the real header; `gcb_proxy.py` checked by grep before concluding it had
no equivalent gap).

**Commits:** `gcb-host@171f16e` (pushed, verified);
`gcb-workspaces@6c4fb0c` (pushed, verified); this entry.

**Ticket status changes:** `GCB-040` stays `done | blue` - this closes
its own flagged follow-up within the same tick it was raised.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (GCB-041: a bigger finding from the same cross-check, correctly NOT implemented)

**Context:** extended `GCB-040`'s spec-signal-vs-RTL cross-check
systematically - every `signal:`-named field in `registers.yaml`
checked against the whole `gcb-rtl/rtl/*.sv` tree, not just the two
`IRQ_CTRL` bits already fixed. 25 signals came back "missing" on the
first pass.

**Investigated carefully before concluding anything, given the stakes.**
Most of those 25 (`r_dma_*`) turned out to be a false alarm: checked
`greencoyote_streaming_dma.sv` directly and found it implements its own
local register decoder under shorter local names (`r_en`, `r_ring_src`,
etc.) - a naming-convention difference, not a gap, confirmed by reading
the real write-decode block before concluding. The remaining cluster
(`r_ss_*`, `SS_CAL_IDX`/`SS_CAL_DATA`/`SS_RAMP_TIMING`) was real:
confirmed present in both `registers.yaml` and the generated package,
confirmed absent from `greencoyote_pilot_regs.sv` entirely, and -
deeper still - confirmed `greencoyote_ss_tdc.sv`/`greencoyote_ss_calib.sv`
are never instantiated anywhere in `gcb-rtl` at all, `top` included.

**Correctly stopped short of implementing anything.** Unlike `GCB-040`
(two bits, zero new clock domains, safe to wire and verify in one
pass), this touches the single-slope readout - the subsystem
`gcb-spec/ai-agents/README.md` itself names as the most rigorously
gated, `ADR-005 CONDITIONAL GO` part of the entire program. Checked
whether it's even a real defect first: `greencoyote_adc_if`/
`greencoyote_dac_if` (the currently-active Phase I bench path) genuinely
ARE integrated, while `ss_tdc`/`ss_calib` are documented (pre-existing
text) as the future "Phase II (silicon-target)" backend - not
necessarily an oversight. The one unambiguous error found -
`gcb-wiki/16` asserting as present fact that a coefficient BRAM exists
in `greencoyote_pilot_regs.sv` that does not exist anywhere - was
corrected directly. The substantive question (when/whether to integrate
a new clock domain into the gated subsystem) was filed as `GCB-041` for
the Architect, not decided or implemented.

**Epistemic status: PROVEN — DIRECT VERIFICATION** for every factual
claim (grep-confirmed absence across the whole RTL tree, not one file);
**explicitly no claim and no action** on the integration-timing
question itself.

**Commits:** `gcb-wiki@7555a92` (pushed, verified);
`gcb-workspaces@67a3c92` (pushed, verified); this entry.

**Ticket status changes:** `GCB-041` created, `open | pending` -
correctly left open, not forced to a resolution it doesn't belong to.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Open-ended continuation — 2026-09-13 (exhaustive register check: GCB-041 was an underestimate by 2 registers)

**Context:** the user asked to continue iterating; ran the exhaustive
register-vs-RTL check `GCB-041`'s own text had only informally gestured
at - all 49 non-stub `registers.yaml` registers (the 8 `THERMAL_*`
registers marked `implemented: false` in the spec itself excluded as a
correct, deliberate negative control, not a gap) cross-checked against
every `ADDR_*` reference in `gcb-rtl/rtl/*.sv`.

**What was found:** `SS_TDC_CTRL` (0xB0) and `SS_TDC_STATUS` (0xC0) are
equally unimplemented, alongside the three already named
(`SS_CAL_IDX`/`SS_CAL_DATA`/`SS_RAMP_TIMING`) - the full `SS_READOUT`
block, 5 registers not 3. `SS_TDC_STATUS` didn't surface in the original
`signal:`-field grep because it's read-only (`source:` fields, not
`signal:`) - a blind spot in the narrower check, caught by switching to
address-based verification instead. Also confirmed, exhaustively: this
is the *only* gap of its kind anywhere in the register map - real,
useful confidence that `GCB-041`'s finding is complete, not an
underestimate in the other direction either.

**What was done:** updated `GCB-041`, and its README row, to the full,
now-exhaustively-confirmed 5-register scope. No RTL or architectural
decision touched - same disposition as before, just accurately scoped.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (every one of the 49
registers checked against real RTL files, not sampled).

**Commits:** `gcb-workspaces@c1891db`, `@4374ff2` (both pushed,
verified); this entry.

**Ticket status changes:** `GCB-041` stays `open | pending` - scope
corrected, disposition unchanged.

**Next candidate:** continuing open-ended per the Architect's own
directive, staying mindful of the host's memory ceiling before any more
large EDA runs.

## Direct Architect request, 2026-09-13 - a stakeholder narrative portal (gcb-wiki/sagas/ + viewer/) and versioned image prompts

**Not a loop tick - a direct, explicit request**, interrupting the
open-ended sweep: build an 8-persona narrative portal explaining the
whole program, a browser-hostable TypeScript viewer for it (SOLID
design, GitHub Pages-deployable), and a versioned image-prompt folder
for future concept renders.

**What was built, all committed and pushed, verified `HEAD==origin/main`
throughout:**
- `gcb-wiki/sagas/` - 8 persona documents (neighbor, math/photonics
  professors, electrical/mechanical engineers, investor, corporate
  contacts, students), every technical claim re-verified against real
  files/tool output before being written (not transcribed from the
  Architect's own draft and trusted) - `gcb-wiki@c58240d`.
- `gcb-wiki/viewer/` - a static TS/HTML app, one class per interface
  in `src/types.ts` (Dependency Inversion), `marked`+`mermaid`+`KaTeX`
  via CDN, no bundler, `build.mjs` assembling a self-contained `dist/`.
  **Verified by actually building it**, not assumed: `npm run build`
  caught and fixed one real `noUncheckedIndexedAccess` compile error;
  every asset + all 8 sagas confirmed reachable over HTTP from a real
  local server afterward - `gcb-wiki@e033b60`.
- `.github/workflows/deploy-pages.yml` - builds+deploys on push (one
  manual step remains: enabling Pages -> Actions in GitHub's own repo
  settings, documented, not something a commit can do).
- `gcb-spec/concepts/images/` versioned: existing 7 renders moved to
  `v1_legacy/` (`git mv`, history preserved), new `v2_personas/` with
  a `manifest.json` + one `prompt.txt` per persona, grounded in the
  same re-verified facts - `gcb-spec@e4fd170`.

**Two real things caught before they became real problems:**
1. The Architect's own draft asserted "Apache 2.0 open-source foundry"
   licensing. Checked directly - the only `LICENSE` file anywhere in
   the program (`gcb-grants/LICENSE.md`) says "All rights reserved";
   no core repo has a license file at all. Not carried into
   `saga-06-investor.md` as fact - stated as an open, undetermined
   question instead, flagged explicitly so it's never repeated to an
   investor as if settled.
2. Every saga used relative links across repo boundaries
   (`../../gcb-spec/...`) - works in this local multi-repo checkout,
   **breaks on GitHub and in the deployed viewer** (separate repos).
   Caught by checking `gcb-wiki`'s own existing convention (plain
   backticks, no cross-repo links) before shipping more of the same
   mistake - converted every one to a real `https://github.com/...`
   URL instead, fixed in `gcb-wiki@2288750`.

Also caught mid-verification: a local test server left running after
an unsuccessful `pkill` attempt (it returned HTTP 200 when it should
have been dead) - found via a real `curl`, not assumed stopped, and
properly killed by PID via `netstat`/`taskkill`.

**Epistemic status: PROVEN — DIRECT VERIFICATION** for every technical
claim in every saga (re-checked against real files this session, not
copied from the request); **PROVEN — DIRECT EXECUTION** for the viewer
(real `npm run build`, real HTTP fetch checks). No browser extension
was available in this environment for a live visual render check -
flagged to the Architect as still worth doing once deployed.

**Commits:** `gcb-spec@e4fd170`, `gcb-wiki@c58240d`, `@e033b60`,
`@2288750` (all pushed, verified); this entry.

**Ticket status changes:** none - this work is not tracked against a
`GCB-###`/`TKT-###` ticket; it's a direct deliverable, not a backlog
item.

**Next candidate:** continuing the open-ended loop per the Architect's
standing directive.

## Direct Architect follow-up, 2026-09-13 - consolidate 8 sagas into 4 lenses, add 5 manufacturing/test personas, real 3-tier depth

**Not a loop tick - a direct follow-up request**: consolidate the 8
personas into 4 "lenses," absorb 5 newly-requested manufacturing/test
personas (chip/tapeout, PCB, board assembly, silicon test, board/
system test), keep SOLID, give expert pushback where warranted.

**The one real problem handled, not smoothed over**: the 5 new
personas describe work this program has not done at all. Checked
directly - zero "Tiny Tapeout" reference anywhere; `ASAP7` is a
predictive academic PDK no real foundry accepts; no package, PCB,
board, or silicon-test artifact exists anywhere in this program's real
evidence base. Rather than invent plausible-sounding tapeout/PCB
content to fill out the absorbed personas, built a dedicated
`gcb-wiki/appendices/manufacturing-pdk.md` stating this as a checked
gap list (Part 2) right next to the real physical-design evidence that
does exist (Part 1) - both lenses that absorb these personas link to
it instead of fabricating.

**What was built, committed, pushed, verified `HEAD==origin/main`:**
`gcb-wiki/lenses/` (4 consolidated documents, kept the Architect's own
grouping), `gcb-wiki/appendices/manufacturing-pdk.md`, one unified
`portal-manifest.json` replacing the old per-directory manifest, a
real 3-level depth system (Executive/System/Foundry, cumulative) via
`<!-- depth:LEVEL -->` HTML-comment tagging that `marked` passes
through as real DOM nodes - verified empirically against actual
`marked.js` output in Node (not assumed from the CommonMark spec)
before trusting the filter's core assumption. The original 8 sagas
were left completely unchanged (the Architect's own earlier "do not
destroy" instruction) and are still the full-depth link-out target
from each lens - `gcb-wiki@d22b690`.

**Verified by actually building, not assumed**: `npm run build`
compiled clean on the first try after the refactor; every asset
(including the new `lenses/`, `appendices/`, and
`portal-manifest.json`) confirmed reachable over HTTP from a real
local server; depth-tag comment balance checked across all 4 lenses
before committing.

**A process note, logged honestly**: the local test server used for
this verification was left running after an unsuccessful `pkill`
attempt during the *previous* follow-up - caught this time by actually
checking with `curl` before trusting `pkill`'s exit, found via
`netstat` + killed by PID via `taskkill`, confirmed dead by `curl`
again afterward. Applied the same discipline on this tick's own
temporary server from the start.

**Epistemic status: PROVEN — DIRECT EXECUTION** (real build, real HTTP
checks, real `marked.js` parse test). No browser extension was
available in this environment for a live visual render check of the
depth toggle - still flagged to the Architect as worth doing once
deployed.

**Commits:** `gcb-wiki@d22b690` (pushed, verified); this entry.

**Ticket status changes:** none - direct deliverable, not a backlog
item.

**Next candidate:** continuing the open-ended loop per the Architect's
standing directive.

## Open-ended continuation — 2026-09-13 (broad due-diligence sweep, clean)

**Context:** resumed the standing backlog loop after the lens-portal
work. Re-checked Docker availability (still unavailable, `TKT-020` R3's
DB-side gap stays blocked) then ran a broader sweep than usual before
picking a next item: `TODO`/`FIXME`/`XXX`/`HACK` across every
non-vendored Python source directory (`gcb-python-orchestrator`'s
`compiler/`/`scheduler.py`/`deploy/`, `gcb-analog-rx`, `gcb-pic-core`,
`gcb-host`'s `proxy/`/`tools/`) - the RTL side was already fully swept
in an earlier tick (`GCB-040`/`GCB-041`); self-consistency of the new
`gcb-wiki/appendices/manufacturing-pdk.md` against the pre-existing
`gcb-wiki/16` (it already independently states "No commercial PDK, no
tapeout" and "never touched a commercial PDK or a physical wafer" -
the new appendix agrees, not a coincidence worth treating as a
separate finding, just confirming no drift); the real ADR directory
against `gcb-spec`'s own "002-004 reserved, never filed" claim;
`gcb-host`'s `src/`/`tests/` state against `TKT-032`'s prior finding;
and a branch-divergence check (`git branch -a`) across all 12 repos.

**Result: clean across the board, nothing found.** Recorded as such,
not stretched into a manufactured finding - a thorough negative result
is itself worth logging, same as the register-map consistency check
earlier this session.

**Epistemic status: PROVEN — DIRECT VERIFICATION** (every check run
directly against real files/git state, not inferred).

**Commits:** none this tick - nothing needed changing.

**Ticket status changes:** none.

**Next candidate:** continuing the open-ended loop per the Architect's
standing directive, staying mindful of the host's memory ceiling
before any more large EDA runs.

## Direct Architect request, 2026-09-13 - add and test the IIS deploy script, real deployment bug found and fixed

**Not a loop tick - a direct request**: add
`Deploy-CoyoteWiki.ps1` to the project and verify it actually deploys,
against a real, already-running local IIS instance with a pre-created
target folder.

**Checked before running, not assumed**: `appcmd list vdir` revealed
the real IIS config - `Default Web Site/Coyote` maps to
`C:\inetpub\wwwroot\GreenCoyoteBay`. The script's own IIS
auto-detection can't find this (`WebAdministration` module not
installed on this machine) and silently falls back to a *different*
path (`C:\inetpub\wwwroot\coyote`) - deployed with `-CustomTargetDir`
pointing at the real vdir's physical path instead of trusting the
default.

**A real deployment bug found by testing, not assumed**: after the
first deploy, every `lenses/`/`sagas/`/`appendices/` `.md` file 404'd
over HTTP despite being physically present (confirmed via
`Test-Path`) - IIS has no built-in MIME type mapping for `.md` at all
(`appcmd list config -section:staticContent` showed only `.mdb`/`.mdp`,
not `.md`). Fixed with `viewer/public/web.config`, wired into
`build.mjs` so every future build ships it automatically - not a
one-off fix to this one IIS instance.

**Verified by redeploying and re-checking over real HTTP, not assumed
fixed**: all 13 deployed markdown files now 200; one file's deployed
content confirmed byte-for-byte identical to its source via direct
`Get-Content`/`Invoke-WebRequest` comparison; the manifest fetched over
HTTP parses with all 12 documents. (`web.config` itself correctly
404s when requested directly over HTTP - IIS hides that file from the
URL namespace by design, confirmed as expected behavior, not
misdiagnosed as a bug.) Site live at `http://localhost/Coyote/`.

**Epistemic status: PROVEN — DIRECT EXECUTION** (real IIS deployment,
real HTTP verification, real content-diff, not inferred from the
script's own success message).

**Commits:** `gcb-wiki@1040fc1`, `@8d30842` (both pushed, verified);
this entry.

**Ticket status changes:** none - direct deliverable, not a backlog
item.

**Next candidate:** continuing the open-ended loop per the Architect's
standing directive.

## Direct Architect report, 2026-09-13 - a real bug my own verification missed, found by an actual browser

**Self-critical record, stated plainly.** The Architect loaded the
deployed viewer in a real browser and hit: "Error: marked.js was not
found on window." This is precisely the gap this session's own
records had flagged as unverified ("no browser extension was
available... still worth doing once deployed") - and the gap turned
out to be real, not hypothetical.

**Root cause:** `index.html` referenced
`.../marked/12.0.2/marked.umd.min.js` - a URL that does not exist on
`cdnjs.cloudflare.com`. Confirmed by direct `curl` (404) and the cdnjs
API. I had verified `marked.parse()` works via an `npm install`ed copy
of the library (a real check, genuinely run) - but never once
`curl`-checked the actual CDN delivery URL hardcoded into `index.html`
before shipping it. KaTeX's and mermaid's URLs happened to be correct;
marked's wasn't, and nothing in my own build/HTTP-asset checks could
have caught it, because those checks only covered files `build.mjs`
deploys, never the three external CDN URLs the page also depends on.

**Fixed and verified far more rigorously than the first pass:**
corrected to `marked.min.js` (confirmed via the cdnjs API + direct
`curl` against both viable candidates, checked which one sets
`window.marked` via its UMD tail before picking). Then, rather than
repeat the same class of mistake, **simulated the actual browser load
end to end**: downloaded the real CDN-delivered file, executed it in a
Node `vm` with `window`/`self`/`globalThis` aliased to the sandbox
(matching a `<script>` tag's real global-object semantics), and
confirmed `window.marked.parse()` produces the exact HTML structure
(`<pre><code class="language-mermaid">` included) the rest of the
render chain depends on. Also re-verified, by direct `curl` and
content inspection this time, every other CDN URL in `index.html`
(KaTeX CSS/JS/auto-render, mermaid) and the actual global names each
one exposes (`renderMathInElement`, `window.mermaid`) - none of that
had actually been checked before either, it had just happened to be
right.

**Epistemic status: PROVEN — DIRECT EXECUTION**, now including the one
class of check (external CDN delivery, simulated real browser
load) that was missing from every prior verification pass on this
viewer.

**Commits:** `gcb-wiki@74fd1b7` (pushed, verified); this entry.

**Ticket status changes:** none - direct deliverable, not a backlog
item.

**Next candidate:** continuing the open-ended loop per the Architect's
standing directive.
