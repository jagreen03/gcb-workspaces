---
id: TKT-033
title: "Channel-spacing cross-document conflict (Architect disposition needed) + FDTD/EME tooling survey - first real mode-solve obtained"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - silicon
  - photonics
  - architecture-conflict
  - toolchain
---

# Objective

Directed follow-on to `TKT-030` (now closed - the K=16 tile's
*layout-feasibility* question): formalize real channel-spacing values and
extract real insertion-loss/phase-noise figures to feed back into
`optical_mesh_dpi.cpp`'s `snr_db`/`phase_deg` parameters, per the
Architect's own framing - "bridges the gap between structural layout
geometry and validated physical simulation data."

**This ticket does NOT close that gap** - it surfaces a real,
previously-undetected cross-document conflict that blocks doing so
responsibly, and separately confirms what FDTD/EME tooling actually
exists in this environment (unconfirmed before now), with one real,
independently-reproduced FEM result obtained as a first concrete step.

## Part A - Channel-spacing conflict: ARCHITECT DISPOSITION NEEDED, not resolved here

**Do not pick a channel-spacing number for `gcb-pic-core`'s K=16 tile
without reading this section - doing so would silently choose among (at
least) three inconsistent, un-reconciled physical claims already on file
in this program's own docs.**

Checked `gcb-wiki`, `gcb-spec`, and `gcb-pic-core`'s own history for every
existing channel-spacing/wavelength claim. Found **three separate,
structurally different physical subsystems**, each with its own (or no)
spacing concept, and **no document anywhere states which of them
`gcb-pic-core`'s K=16 tile is actually supposed to be**:

1. **`gcb-wiki/16_hardware_parts_systems_specification.md` Part 9**
   ("DWDM laser/modulator bank... into an 8x8 unitary mesh," "Phase II
   integrated cell"): explicitly lists channel spacing, wavelength count,
   laser type, and modulator bandwidth as **Missing** (line 477), with
   its own doctrine note: *"recorded as a genuine gap, not filled in with
   an estimate, per this program's own discipline against fabricating
   figures that were never derived."* An 8x8 mesh is **64** elements -
   not 16.
2. **`gcb-wiki/15_hardware_inventory_and_testability.md`** (the
   `gcb_wavelength_router`/DWDM digital-transport RTL, inter-chip/board
   optical link): DOES carry an existing figure - **"Channel spacing: 50
   GHz grid (`ASSUMPTION`)"** (line 65), for a **60lambda** link-budget
   estimate vs. a **64-lane** RTL test ceiling (also deliberately kept
   distinct from each other, per that document's own `14`-doctrine
   cross-reference). This is a genuinely wavelength-multiplexed (DWDM)
   link - but it is the **digital transport** layer, not necessarily the
   same physical channel grid as an on-die optical MAC tile.
3. **`gcb-spec/bench_emulation_parameters.md`** (Task 3, Phase I bench
   emulation - the doc `gcb-wiki/16` itself names as Part 9's nominal
   parameter owner): describes something **structurally different from
   WDM entirely**. A **single** O-band wavelength (~1310 nm, one laser
   type spec, not N distinct wavelengths), with N=4-8 channels combined
   via a **COTS fused-fiber intensity/power coupler tree** (coherent or
   incoherent power summation, not frequency-domain multiplexing at
   all). Its own most-decision-relevant unmeasured number is the
   **coherent-vs-incoherent insertion-loss regime** (~0.2 dB vs. ~9 dB,
   `stage_il_db`) - not a channel spacing, because this bench path does
   not appear to use wavelength-division multiplexing in the first
   place.

**`gcb-pic-core`'s own K=16 tile (`TKT-030`, `wdm_combiner_tree.py` /
`k16_tile.py`) assumes a fourth configuration** - 16 (not 60, 64, or
4-8) wavelength-multiplexed channels, combined via a binary tree of
MZI-lattice filters (true frequency-domain WDM, like #2, but with a
different channel count than either #1 or #2, and a different combining
mechanism than #3's fused-fiber power-tree). **No document checked this
session establishes that this is the same physical subsystem as any of
#1-#3, a fourth intentionally-distinct one, or simply an
under-specified placeholder count.**

**Why this is not mine to resolve**: picking any single channel-spacing
value (the 50 GHz grid, an ITU-standard 100 GHz grid, or anything else)
to feed into `wdm_combiner_tree.py`'s `delta_lengths` would silently
assert which of these four subsystems `gcb-pic-core` actually is -
exactly the kind of architecture decision `TKT-031`'s own precedent
establishes belongs to the Architect, not an autonomous loop. Flagged
here, held for disposition, consistent with this program's standing
discipline.

**Candidate framings, for the Architect to choose among (not a
recommendation ranked here):**
- (a) `gcb-pic-core`'s K=16 tile IS (or tiles into) `gcb-wiki/16` Part 9's
  "Phase II integrated cell," in which case 4 of them would need to
  combine to reach the 8x8=64 mesh count, and real channel-spacing values
  are **genuinely not yet derived anywhere** - any figure used remains an
  `ESTIMATE-ASSUMPTION` by this program's own doctrine until real
  laser/modulator parts are chosen.
- (b) `gcb-pic-core`'s K=16 tile shares the 60lambda/50GHz-grid digital
  link's physical channel plan (reusing `gcb-wiki/15`'s existing
  `ASSUMPTION` figure, subsetted to 16 of the 60-64 channels) - plausible
  but unconfirmed; no document states the on-die tile and the inter-chip
  link share a wavelength plan.
- (c) `gcb-pic-core`'s K=16 tile is an independent Phase-I-adjacent
  construction unrelated to either Part 9 or the DWDM link, closer in
  spirit to the bench-emulation path's single-wavelength/power-combining
  approach (#3) - in which case "channel spacing" may not even be the
  right concept for it, and `wdm_combiner_tree.py`'s WDM framing itself
  would need revisiting.

## Part B - FDTD/EME tooling survey + first real mode-solve

**Checked what this environment can actually run, rather than assume -
consistent with `TKT-030`'s own "no such tool has been confirmed
available... confirming that is itself future work" note.**

1. **`meep` (PyPI) is a name collision, NOT the FDTD simulator - caught
   by unzipping the wheel, not by the package name alone.** `pip index
   versions meep` resolves, and a 4.3 KB wheel downloads cleanly - but
   its own `METADATA` reads *"Summary: Very light-weight task runner...
   Keywords: ci cd automation operations... Prototype of very light task
   runner, meant to be used for CI/CD tasks triggered by VCS hooks."* The
   real MIT FDTD simulator (`pymeep`) is distributed only via
   conda-forge under this name, not pip - this environment does not have
   it, and installing the PyPI `meep` package would have been a false
   positive exactly like the AWG's "builds without raising an exception"
   trap, caught the same way: read the actual content, not just the
   absence of an error.
2. **`tidy3d` is real, cloud-hosted FDTD** - but requires creating an
   external account and API key. **Not initiated** - an external-service
   signup is exactly the kind of outward-facing, hard-to-reverse action
   that needs the Architect's authorization first, not an autonomous
   loop's assumption that it's wanted.
3. **`femwell` (pure-Python FEM mode solver/EME, open-source, no
   license) IS real and installs cleanly** - `~/.venvs/femwell` (kept
   SEPARATE from `~/.venvs/gdsfactory`; femwell's own dependency tree -
   VTK, `cadquery-ocp`, `gmsh`, `scikit-fem` - is heavy and partially
   overlapping, isolated rather than risking the already-verified
   gdsfactory venv), ~90s install, zero native build failures.
4. **First real result obtained**: `gcb-pic-core/mode_solve_strip.py`
   computes the fundamental-mode effective index of a 500x220nm silicon
   strip waveguide at 1.31 um (O-band - the one concrete wavelength this
   program's own docs commit to anywhere, per
   `gcb-spec/bench_emulation_parameters.md`): **n_eff = 2.684623** (real
   part), a textbook-consistent value for these dimensions, reproduced
   **byte-identically across two independent fresh process invocations**
   before being committed (`gcb-pic-core@23ec5dd`, pushed,
   `HEAD == origin/main` verified). 220 nm SOI thickness and the
   Si/SiO2 textbook indices used are explicitly flagged as NOT sourced
   from this repo's own docs (no layer stack is recorded anywhere) -
   this is a toolchain-capability demonstration and a single-waveguide
   baseline, not a repo-derived physical spec.
5. **Explicitly NOT attempted this session**: the MZI-lattice combiner's
   own real insertion loss or crosstalk (a materially bigger 3D/coupled-
   mode problem - modeling the actual directional coupler/lattice-filter
   geometry, not just a bare straight waveguide), and any real material-
   loss (complex refractive index) figure (none exists in this program's
   docs to feed in - the near-zero imaginary part of `n_eff` computed
   here is a numerical artifact of an all-real-index input, correctly
   labeled as such, not a loss measurement).

## Required work (next iteration, not this one)

1. **Architect disposition on Part A** - which of the four framings (or
   a fifth not listed) `gcb-pic-core`'s K=16 tile actually represents.
   Nothing in Part B depends on this being resolved first, but no real
   `delta_lengths`/channel-spacing value should be committed to
   `wdm_combiner_tree.py` until it is.
2. Once Part A is resolved: derive or source a real channel-spacing
   value (an ITU-T grid figure, a literature MZI-lattice FSR target, or
   a genuinely-measured bench figure) and propagate it into
   `wdm_combiner_tree.py`'s `delta_lengths` and `optical_mesh_dpi.cpp`'s
   relevant parameters - currently both out of reach without Part A.
3. Extend `mode_solve_strip.py`'s FEM approach (or build a new script) to
   model the actual MZI-lattice coupler geometry (not just a bare
   waveguide) and extract a real coupling-length/insertion-loss figure -
   materially bigger work, deferred per this ticket's own Part B finding
   #5.
4. If/when real insertion-loss or phase-noise figures are obtained: feed
   them back into `optical_mesh_dpi.cpp`'s `snr_db`/`phase_deg`
   parameters, per the Architect's own framing of this ticket's purpose -
   not attempted this session (blocked on items 1-3 above).

## Out of scope

- Creating a `tidy3d` account or any other external-service signup,
  without explicit Architect authorization.
- Picking a channel-spacing number on this ticket's own authority - see
  Part A.
- `TKT-019.19` and anything in that neighborhood - unrelated.

## Telemetry & Evaluation

**No PBG grade is assigned** - this ticket's central question (Part A,
which of at least four inconsistent physical framings `gcb-pic-core`'s
K=16 tile represents) is an architecture conflict held for the
Architect's disposition, not a completed or rejected piece of work;
matching this program's own doctrine that architecture-only/
measurement-only tickets get no grade, and `TKT-031`'s own precedent
(ungraded while open, graded only after the Architect's disposition
closed it). Part B's toolchain result (the FEM mode-solve) is real and
independently reproduced, but is a sub-component of this ticket, not a
standalone deliverable warranting its own grade split from Part A.

**Final State:** `open | pending` - Part A is an architecture conflict
flagged and held for the Architect's disposition (see `TKT-031`'s own
precedent for the expected shape of that resolution). Part B's toolchain
result stands independently of Part A's resolution and is already
committed and verified (`gcb-pic-core@23ec5dd`, `HEAD == origin/main`).
