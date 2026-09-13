---
id: TKT-035
title: "System-wide hardware inventory reconstruction (Orange-Team evidence discipline) - Pass 1 delivered"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - architecture-conflict
  - system-inventory
---

# Objective

The Architect supplied a standing prompt
(`C:\Users\jagre\Downloads\GCB System Hardware Inventory — Gemini +
Orange-Team Prompt.md`) for a full system-level hardware-inventory
reconstruction of GreenCoyote-Bay/ODIN_Bridge, with strict evidence-
category discipline (EXPLICITLY IDENTIFIED / ARCHITECTURALLY REQUIRED /
IMPLEMENTED / TESTED / PHYSICALLY VALIDATED / INFERRED / UNKNOWN - never
collapsed) and an explicit instruction to never silently reconcile
contradictory documentation.

Checked against `TKT-034` first, per the Architect's instruction: **not
close.** `TKT-034` is a narrow single-component grounding check (is
`gcb-pic-core`'s multiply operation `gcb-spec`-grounded). This prompt is
a full, 11-section, program-wide reconstruction across every repo. Opened
as this new ticket instead.

**Treated the source prompt itself per this program's own standing
doctrine**: its title ("Gemini + Orange-Team Prompt") and its own "may be
passed to another LLM" framing mark it as AI-facing, not as evidence in
its own right. `gcb-wiki/15_hardware_inventory_and_testability.md` and
`/16_hardware_parts_systems_specification.md` appear to already be
output from a prior run of this same (or a closely related) prompt -
and this session already found real, ungrounded content in both
(`TKT-033`). This reconstruction was therefore done as a genuinely fresh
pass from repo/`gcb-spec` evidence directly, not as a touch-up of the
existing docs, and not trusting their prior content as a starting
baseline.

## Pass 1 scope and honesty note

**This is a first pass, not an exhaustive final deliverable** - flagged
explicitly per this program's own "don't overclaim completeness"
discipline. Depth varies by repo:

- **Deep** (direct evidence gathered/re-verified this session or this
  pass): `gcb-rtl`, `gcb-wdm-transceiver`, `gcb-host`, `gcb-analog-rx`,
  `gcb-pic-core`, `gcb-spec`, `gcb-photonic-qam-v2` (RTL-level).
- **Shallow** (top-level README/structure only, not read in depth this
  pass): `gcb-python-orchestrator`, `gcb-dashboard`, `vortex` (the
  vendored RISC-V GPGPU - likely required external compute
  infrastructure per the prompt's own System Boundary Check, not a
  GCB-authored part; not yet confirmed).

See `gcb-workspaces/reports/system_hardware_inventory_pass1.md` for the
full deliverable (master inventory, status matrix, contradiction
register, system boundary, functional-completeness gaps, dependency map).

## Key findings (headline, full detail in the report)

1. **Real, hard evidence upgrade found**: `gcb-rtl`'s `greencoyote_top`
   has an actual Vivado 2024.2 post-route checkpoint (`post_route.dcp`)
   targeting a real FPGA part (`xcu55c-fsvh2892-2L-e`, Alveo U55C, OOC
   mode) - all timing constraints met (WNS +0.261 ns), real utilization
   (602 LUT / 0.05%, 8 DSP48E2) and a vectorless power estimate (flagged
   "confidence Medium" in its own source, not overclaimed). This is a
   materially higher evidence tier than "RTL IMPLEMENTED/DIGITALLY
   SIMULATED" for this specific top - genuinely SYNTHESIZED + PLACED
   AND ROUTED for a named FPGA part, confirmed by `gcb-host`'s own driver
   opening an XRT IP of the identical name.
2. **Confirmed `gcb_wavelength_router.sv` has diverged** between
   `gcb-wdm-transceiver` (124 lines, `N_LAMBDA` parameterized toward a
   ~60lambda Mode B count) and `gcb-photonic-qam-v2` (99 lines, the
   original fixed-2-color version) - a real fork-divergence, exactly the
   "repository names that refer to different architectural generations"
   contradiction class the source prompt names.
3. **This divergence likely resolves part of `TKT-033`'s earlier
   puzzle**: `gcb-wiki/15`'s ~60lambda/50GHz-grid DWDM figures most
   plausibly describe `gcb-wdm-transceiver`'s own real, RTL-implemented,
   regression-tested wavelength router - NOT `gcb-pic-core`'s homodyne
   tile (which `TKT-033` already correctly found has zero WDM grounding
   in `gcb-spec`). Two genuinely separate, both-real optical subsystems,
   previously conflated by `gcb-wiki`'s own cross-references.

## Required work (next iteration, not this one)

1. Deepen the shallow-pass repos (`gcb-python-orchestrator`,
   `gcb-dashboard`, `vortex`'s actual GCB integration surface).
2. Complete the remaining prompt sections not fully built in Pass 1
   (Required Equipment Matrix, full DFT/test-structure matrix) - Pass 1
   covers these at the depth `gcb-wiki/15` already established, re-
   verified rather than redone from scratch line-by-line.
3. Confirm the Finding #3 hypothesis above (`gcb-wiki/15`'s 60lambda
   figures describing `gcb-wdm-transceiver`, not `gcb-pic-core`) directly
   with the Architect or by re-reading `gcb-wiki/15`'s own citations in
   full.

## Out of scope

- Redesigning anything - this is reconstruction/inventory only, per the
  source prompt's own explicit framing.
- `TKT-019.19` and anything in that neighborhood - unrelated.

---
## Resolution, simplified (2026-09-12, same day, directed follow-on:
"simplify this, /loop till you find the best solution... don't throw
the baby out with the bathwater")

**The simple answer**: Track A (`gcb-spec`'s 5 repos) is **Phase I** -
the real, already-synthesized, current system. The "Track B" repos are
mostly **Phase II** - the same program's forward roadmap, not a
competing architecture. Nothing gets deleted; the confusion was a
citation gap, not a real conflict.

**Implemented and verified, not just decided in prose**: `gcb-pic-core`
is CONFIRMED to fold into Track A - `gcb-spec/docs/optical_geometry_spec.md`
(LOCKED v1.0.0) sizes a Phase-II integrated array at exactly `L=16`
contraction lanes/channel/fire, single wavelength. That's the real
number behind `gcb-pic-core`'s "K=16" - the WDM label was wrong, the
number wasn't. `mmi_power_tree.py` now builds+verifies both the real
Phase-I (N=8) and Phase-II (N=16) targets, reproduced twice, committed
(`gcb-pic-core@79e9c58`, `87de269`, pushed). See `TKT-030`'s own
refinement note.

**Checked, not yet confirmed, for the other four "Track B" repos**:
- `gcb-python-orchestrator` - plausibly ALSO belongs to Track A (its own
  README describes a compiler for "the Photonic + Vortex hybrid fabric,"
  which is exactly Track A's real data path - Vortex TCU feeding an
  optical cascade). Likely just an uncited repo, not a separate track -
  not yet confirmed by reading its internals in depth.
- `gcb-analog-rx` - **CHECKED against `ADR-005` directly.** NOT the
  retired ΔΣ branch (no feedback-nulling loop, no decimated bitstream -
  clearly different). NOT the winning Single-Slope CIS either, exactly:
  shares the same passive-integration-onto-`C_int` front end, but uses a
  flash/comparator-bank ADC back-end instead of Single-Slope's ramp +
  shared Gray-counter TDC, and its modeled window (200 ps) doesn't match
  `ADR-005`'s locked window (256 ns) by over 1000x - built independently
  of `ADR-005`'s real numbers. A genuinely **third** Rx variant for the
  same role, not yet reconciled with the already-locked decision -
  flagged on `TKT-031` (the ticket that made the original Phase-I
  disposition without checking `ADR-005`), not silently resolved.
- `gcb-wdm-transceiver` - real, substantial, regression-tested DWDM
  RTL, but Track A is explicitly single-wavelength ("no channel mux").
  Most likely a genuinely separate subsystem (inter-chip/board optical
  TRANSPORT, a different layer than Track A's on-die compute cascade),
  not forced into Track A - this is the one repo where "separate but
  real" is the most likely honest answer, not a citation gap.
- `gcb-photonic-qam-v2` - complex-valued QAM optical compute; no Track A
  counterpart found. Most likely a separate, longer-horizon vision, same
  status as `gcb-wdm-transceiver`.

**Net result (SUPERSEDED below - this paragraph's `gcb-pic-core`
conclusion was a hasty overreach, corrected the same day, see
`TKT-030`'s own correction-of-correction and `TKT-034`'s resolution).**

---
## Correction: "Track A/Track B" was itself too vague - there are TWO
NAMED, coherent programs, not one canonical track plus a scatter of
loose repos

**Continuing the directed open-ended work (confirm `gcb-python-
orchestrator`, then deepen) surfaced the real, simple structure.** Both
`gcb-pic-core` and `gcb-analog-rx` self-describe, in their own README
headers, as **"the GCB Photonic QAM Accelerator"** - a real, named
second program, not an amorphous "Track B." Its components, now
confirmed by direct, specific evidence (not naming/guesswork):

- `gcb-wdm-transceiver` - the V1.0 DWDM transport + reduction RTL.
  `rtl/gcb_dwdm_pkg.sv`'s own comment: `K_MAX = 16` is *"a HARD
  cross-architecture invariant."*
- `gcb-photonic-qam-v2` - the V2.0 complex-QAM extension (its own
  README's own file-fork admission explains the `gcb_wavelength_router.sv`
  divergence found earlier - normal version drift within ONE lineage,
  not two separate forks). `intent.md`'s "Software Tiling Constraint"
  derives the SAME `K <= 16` from a balanced-homodyne SNR budget, for the
  SAME A+B/A-B multiply mechanism `gcb-pic-core` implements - confirmed
  word-for-word, not by coincidence of a shared digit.
- `gcb-pic-core` - the PIC layout for that same multiply cell.
- `gcb-analog-rx` - a candidate Rx front-end **for this program**, not a
  rival implementation of `gcb-spec`'s `ADR-005` decision (which belongs
  to the OTHER program, "GCB/ODIN_Bridge"). **This simplifies the
  `TKT-031` flag below**: there was never a reconciliation needed - each
  named program has always had its own separate Rx question, the earlier
  flag just hadn't identified that `gcb-analog-rx` belongs to the QAM
  Accelerator program specifically.
- `gcb-python-orchestrator` - **CONFIRMED this pass** (the one item left
  open): `compiler/packer.py`'s own comment copies its bit convention
  from `gcb_dwdm_pkg::pack_int4` "not reinvented" - the SAME RTL package
  as `gcb-wdm-transceiver`, K_MAX=16 included. This is the QAM
  Accelerator's own compiler, not "GCB/ODIN_Bridge"'s (my own earlier
  guess, based only on the word "Photonic" in its README, was wrong -
  corrected here rather than left standing).

**The two real, named programs, simplified:**

| | GCB/ODIN_Bridge | GCB Photonic QAM Accelerator |
|---|---|---|
| Repos | `gcb-spec`, `gcb-rtl`, `gcb-host`, `gcb-dashboard`, `gcb-papers` | `gcb-wdm-transceiver`, `gcb-photonic-qam-v2`, `gcb-pic-core`, `gcb-analog-rx`, `gcb-python-orchestrator` |
| Optical mechanism | Single wavelength, power-summing (plain addition) | 2 colors/operand (QPSK I/Q), balanced-homodyne multiply (A+B/A-B) |
| Spec authority | `gcb-spec` (direct, explicit) | `gcb-photonic-qam-v2/intent.md` + shared RTL (`gcb_dwdm_pkg.sv`) - real, just no single unified repo like `gcb-spec` |
| Physical evidence | Real Vivado P&R (`greencoyote_top`, Alveo U55C) | Real cocotb/Icarus RTL regression (`gcb-wdm-transceiver`), real DPI-C co-simulation (`model/RESULTS.md`), `gdsfactory` layout feasibility (`gcb-pic-core`) - no FPGA/ASIC evidence |

**All five "Track B" repos are now accounted for** - none discarded, all
real, all belonging together as one coherent second program. This closes
Contradiction Register entry #1 (the original TKT-035 report) to the
extent evidence allows: the two "tracks" are not competing visions of
the same thing, they are two separate, real, differently-evidenced
programs sharing an umbrella name.

## Telemetry & Evaluation

Spec 0.9 - resolved the original ambiguity with a simple, two-program
structure, backed by each repo's own self-description and matching
RTL/doc evidence, not guesswork; not 1.0 because the physical-maturity
gap between the two programs (one has real FPGA evidence, the other
doesn't) remains a real, unaddressed fact, and the equipment/DFT
deliverable sections from the original prompt are still deferred.
Quality 0.9 - every claim in the corrected table is backed by a direct
read (README self-descriptions, RTL comments, intent.md text), including
catching and correcting this same ticket's own earlier overreach rather
than leaving it standing. Emergence 0.85 - the "two named programs"
framing is simpler and more actionable than the original "Track A/
Track B" ambiguity, and directly enabled `TKT-034`'s resolution and
`TKT-030`'s correction - a structural finding with real leverage on
multiple other tickets, not an isolated result.

**Final State:** `open | pending` - Contradiction Register entry #1 (the
ticket's central ambiguity) is now resolved with the two-program
structure, confirmed and simple. This does NOT close the ticket - the
original Pass-1 deliverable sections not revisited here (equipment/DFT
matrices, per the source prompt's own 11-section scope) remain genuinely
open follow-on work.

---
## Deepened the two remaining shallow-pass repos (2026-09-12, same day,
continuing open-ended)

**`gcb-dashboard` - confirmed cross-program, and confirmed genuinely
functional (not just described).** Its own `Makefile` comment states the
design explicitly: *"RTL source set for the staleness check: the dirs
`build_visuals.py` really reads (`gcb-rtl` + `gcb-photonic-qam-v2`)...
`gcb-wdm-transceiver`/rtl is deliberately NOT in the default set - the
dashboard never renders those tops."* This repo serves BOTH named
programs by explicit design, not accident - it is cross-cutting
infrastructure, not evidence for either program over the other.

**Ran `make doctor` for real** (not assumed): **passes cleanly** - the
full render toolchain (`sv2v v0.0.12`, `Yosys 0.68`, `node v22.22.1`,
`yosys2digitaljs`, `elkjs`) is genuinely installed and functional,
`outputs/` already holds 17 rendered SVGs, fresh (not stale) against
every RTL source. This is real IMPLEMENTED + TESTED status for Role 2
(the visualization backend), not merely described.

**Role 1 (the React monitoring dashboard) is a different story, found by
checking rather than assuming**: `src/GreenCoyoteDashboard.jsx` is real,
substantial code (514 lines, genuine React hooks + a real default
export) - but `package.json` declares NO `react`/`react-dom` dependency
and NO build/dev/start script for it anywhere. **IMPLEMENTED, but this
repo currently has no way to actually build or run it** - a real,
previously-unrecorded gap, not a rejection of the component's substance.

**Fixed and verified, 2026-09-13** (`gcb-dashboard@3689d74`, pushed):
added `react`/`react-dom` + `vite`/`@vitejs/plugin-react`, a minimal
`vite.config.js`, `index.html`, and `src/main.jsx` mounting the existing
component - the missing tooling, not a rewrite. Verified by actually
running it: `npm install` (64 packages) and `npm run build` both
succeed, a real production build (30 modules, a real `dist/` bundle,
728ms). One real, known `esbuild` vulnerability found and reported, not
silently patched (dev-server-only, fixing it needs a breaking `vite@8`
upgrade, not applied without a deliberate decision). **Separately
found, then fixed 2026-09-13** (`gcb-dashboard@805c39f`, pushed): the
README expansion ("expanded 2026-09-11, GCB-039") was real, dated
content already on disk but never committed - deliberately excluded
from the build-tooling fix above to keep that commit scoped, then
committed on its own once verified (`make doctor` genuinely passes;
role 2 is real, per the confirmation directly above this section).

Same pattern, same day, two more repos: `gcb-photonic-qam-v2/README.md`
and `gcb-python-orchestrator/README.md` were found completely
untracked (`??`, zero `git log` history) via a routine `git status`
sweep done deliberately low-risk right after the B-operand OOM event -
distinct from `gcb-dashboard`'s case (an older version *was* already
committed, just stale): these two had never been `git add`ed at all.
Both read in full before touching git, confirmed to match content
already relied on earlier this session, committed as-is, one commit
per repo: `gcb-photonic-qam-v2@8168b50`, `gcb-python-orchestrator@d7d2975`
(both pushed, verified). A full `gcb-*` sweep afterward found no further
cases - the only remaining stray state anywhere is `gcb-wdm-transceiver`'s
own pre-existing, explicitly protected, unrelated stray state.

**`vortex` - System Boundary question CONCLUSIVELY confirmed, not just
inferred from file absence.** `git remote -v` shows the real upstream
origin (`https://github.com/vortexgpgpu/vortex.git`, not a GCB fork);
`git log` shows genuinely unrelated upstream commits (PR merges, a
`tinygpu` synthesis config, NaN-boxing test fixes); an exhaustive grep
for "greencoyote"/"GreenCoyote"/"ODIN_Bridge" across the entire tree
(`.sv`/`.md`/`.py`) returns **zero matches**. `vortex` is genuinely
**required external infrastructure**, per the source prompt's own
System Boundary Check category - not a GCB-authored component, with
every piece of GCB's own integration work confirmed to live entirely in
`gcb-rtl/integration/*.sv` and `gcb-spec/vortex_integration_notes.md`,
never inside the `vortex` tree itself.

**Epistemic status: PROVEN — DIRECT EVIDENCE** for all of the above
(a real command run with real output for `make doctor`; `git remote`/
`git log`/exhaustive grep for `vortex`'s boundary; direct file reads for
the React gap) - none of this is inferred from naming or absence alone.

This closes both remaining shallow-pass items from the original Pass 1.

---
## Capstone finding (2026-09-12, same day, continuing open-ended): why
"16" and "channel spacing" both appear repeatedly, never the same thing,
and never a coincidence - `gcb-papers`

`gcb-papers` (the fifth Track-A-canonical repo, never actually inspected
until now despite all the reconciliation work above) holds a real,
substantial three-paper research arc that directly explains the whole
pattern this session kept re-discovering in pieces:

- **Paper 1** (`p1-cascaded-reduction`): cascaded optical carry-save
  reduction - matches Track A's real `gcb-rtl/sim/mmi_tree_model.py`
  mechanism exactly (power-summing, cascade ADC reset, INT8-equivalent
  precision via digital reset between 6-bit analog stages).
- **Paper 2** (`p2-rfi-interconnect`): the **Reduction Fabric Interface**
  - explicitly an INTERCONNECT standard ("what PCIe is to general
  computing"), using **coherent optical QAM** over TFLN modulators, WDM
  ("one wavelength per compute unit, all wavelengths on one fiber"), with
  its own stated channel plan: **8-channel WDM, 200 GHz spacing in the
  C-band**. This is a real, independently-derived channel-spacing figure
  - for the TRANSPORT/interconnect layer specifically, not the on-die
  compute layer.
- **Paper 3** (`p3-unified-matmul`): extends the optical domain backward
  into the multiply stage itself (TFLN MZM modulator arrays), unifying
  multiply + reduce "through photonic waveguide physics" with the same
  cascade-ADC mechanism as Paper 1 - explicitly citing Paper 2's QAM
  interconnect as the thing that moves partial results between compute
  units, not the thing that does the multiply or the reduce.

**This is the clean, final resolution of the whole "why does 16 keep
appearing, and why does channel spacing keep appearing, and are they
ever the same thing" question this session chased across `TKT-030`,
`TKT-033`, and `TKT-034`:** they are two genuinely different parameters
for two genuinely different LAYERS of one overall vision, not one
overloaded number and not a coincidence:

| Layer | Parameter | Real values found this session | Where |
|---|---|---|---|
| On-die compute (multiply + reduce) | reduction depth / contraction width | `L_CONTRACT=16` (`gcb-spec`, Track A); `K<=16`/`K_MAX=16` (the QAM Accelerator, `intent.md` + `gcb_dwdm_pkg.sv`) | Two separate programs, coincidentally-or-historically the same number, NEVER a wavelength count in either |
| Inter-unit/appliance transport | WDM channel count / spacing | `~60lambda`/`50 GHz` (`gcb-wiki/15`, most plausibly `gcb-wdm-transceiver`'s real router); **8 channels/`200 GHz`** (`gcb-papers` Paper 2's RFI, a real designed channel plan) | Genuinely the transport concern - channel spacing belongs HERE, never at the compute layer |

**Revises, not reverses, `TKT-033`'s original finding**: `gcb-pic-core`'s
K=16 STILL has no WDM/channel-spacing requirement of its OWN (confirmed
independently twice now, by two different routes - `gcb-spec`'s
power-summing model and the QAM Accelerator's own SNR-budget derivation).
What's new here is WHY the broader program keeps producing real channel-
spacing numbers anyway: a genuinely separate transport layer
(`gcb-wdm-transceiver` / Paper 2's RFI) needs one, and always did - this
session's own earlier investigations were repeatedly finding REAL
numbers for a REAL but DIFFERENT layer than the one being asked about,
not fabricated figures.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (all three papers read
directly for their own stated architecture; Paper 2's channel plan is a
design specification within the paper, not claimed here as built/
measured hardware - these are draft arXiv papers, not verified silicon,
and are cited as evidence of INTENT/architecture, not of physical
results).

---
## Checked, could not verify (2026-09-12, same day): the Cyclopter/
pgvector deployment's actual execution status

`gcb-python-orchestrator/deploy/cyclopter/` (the `pbg_telemetry`
PostgreSQL+pgvector persistence layer cited repeatedly this session, and
the subject of `GCB-039`'s own Objective B) is real, well-documented
configuration - `docker-compose.yml`, an idempotent migration, a
one-click `db_up.sh` bring-up script with a thoughtful detail (binds
host port 5433 specifically "avoids the Windows PG17 on 5432," strongly
suggesting it was run at least once on a real machine with a real local
conflict). **Could not verify whether it is currently running, or has
ever actually been run, in THIS session's environment**: `docker` is not
installed in either the WSL environment or on the Windows host checked
this pass, and no exported data, logs, or artifacts from a past run
exist anywhere in the repo (git-tracked state only shows configuration,
never output). Did not install Docker to force a check - an environment
change that large is outward-facing enough to ask first, not assume.

**This matches a pattern recurring across this entire program, found
independently at several other points this session** (the React
dashboard with no build script; `gcb-host`'s empty `src`/`tests`): real,
well-designed configuration/code that has rarely been actually EXECUTED
and verified end-to-end in a way that leaves evidence. Recorded as
CONFIG EXISTS / EXECUTION STATUS UNKNOWN, not overclaimed either way.

---
## Correction (2026-09-12, later the same session): the OpenROAD
"toolchain unavailable" finding above was WRONG - my own check was
incomplete, not the program's record

**The Architect asked directly: if OpenROAD was never available, how
did `GCB-027`/`029`/`030`/`032` produce real physical-layout findings?**
Good question - checking properly (not re-asserting the earlier
conclusion) found the earlier check in this report was simply
incomplete: `which openroad` against default `PATH` found nothing, but
`TKT-021` (read in full only now, having been missed earlier) documents
a `--local` ORFS build at `~/eda/OpenROAD-flow-scripts`, built deliberately
**without** touching system `PATH` - it requires `source env.sh` from
inside that tree first, exactly as `TKT-021`'s own Execution Log states.

**Verified directly, not re-asserted:**
- `~/.wslconfig` on the Windows host genuinely has `memory=8GB`,
  `processors=4`, `swap=8GB`, `autoMemoryReclaim=Disabled` - an exact
  match to `TKT-021`'s documented changes.
- `source ~/eda/OpenROAD-flow-scripts/env.sh && openroad -version` →
  a real version string, `26Q3-1953-gc6c0900a16`.
- `flow/results/asap7/gcb_max_reduce/base/` holds a complete, genuine
  ORFS output set: real `.odb` database files at every stage, `6_final.gds`,
  `6_final.def`, `6_final.spef` (parasitics), a final netlist, rendered
  layout images - not something an LLM could fabricate.
- `flow/reports/asap7/gcb_max_reduce/base/6_finish.rpt` reads
  **`wns max 0.00`** - an exact match to `GCB-032`'s claimed "WNS = 0.00 ps."

**Corrects this report's own earlier "OpenROAD... is not installed"
line and `spike_loop_summary.md`'s matching entry.** OpenROAD is real,
working, and was genuinely used for `gcb_max_reduce`'s ASAP7 physical
validation - it was simply never on default `PATH` in a fresh shell, a
fact this report's own check did not account for before concluding
unavailability. The ASIC physical-design findings in `GCB-027`/`029`/
`030`/`032` are confirmed genuine, not fabricated.

**Epistemic status: PROVEN — DIRECT EVIDENCE** (the binary run directly,
real output files inspected, a real reported number cross-checked
against a real claim). The earlier "unavailable" claim in this same
report is the thing that was wrong, corrected here rather than left
standing.
