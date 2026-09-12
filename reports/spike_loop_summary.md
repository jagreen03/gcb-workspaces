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
