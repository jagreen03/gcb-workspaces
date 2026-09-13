---
id: TKT-033
title: "Channel-spacing question RESOLVED (no WDM in the spec-authoritative architecture) + FDTD/EME tooling survey - first real mode-solve obtained"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.95
  quality: 0.9
  emergence: 0.75
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

**Part A is now RESOLVED** (corrected from this ticket's original
"Architect disposition needed" framing - see the note below on why that
framing was itself a process error, not just an open question). Part B's
FDTD/EME toolchain result stands as originally obtained.

## Part A - Channel-spacing question: RESOLVED - no WDM in the spec-authoritative architecture

**Process correction, stated first because it matters beyond this one
ticket**: this section originally escalated a "four-way architecture
conflict" for Architect disposition, built by treating `gcb-wiki` as
evidence co-equal with `gcb-spec`. **That was a methodology error.**
`gcb-wiki` is the human-readable view *of* `gcb-spec`, not a parallel
source of truth - per the Architect's own correction. The real resolution
path was to check `gcb-spec` (and what it directly authors/models)
directly, which decisively answers the question without needing to
adjudicate between documents that were never co-equal in the first place.
Saved as a standing methodology note for future sessions
(`gcb-wiki-not-source-of-truth` memory) - this should not recur.

**Resolution, checked directly against `gcb-spec`, not inferred:**

1. **`gcb-spec` contains ZERO mentions of "Component 4," "balanced-
   homodyne," "multiplier tile," or "K=16" anywhere** (exhaustive grep,
   not a sampled read). The entire "K=16 WDM multiplier tile" framing
   that `TKT-030` built toward this session exists **only** in
   `gcb-wiki` - and `gcb-pic-core`'s own `README.md` ("Near-term goals")
   cites `../gcb-wiki` `goal.md` §2 as its source, **not `gcb-spec`**.
   That citation chain is the root cause of this whole question.
2. **`gcb-spec/task3_physical_bom.md`** (the actual authoritative Phase I
   physical BOM): specifies **a single** O-band (1310 nm) CW DFB laser
   source, isolated, driven through **one** linear VOA intensity
   modulator (`TKT-028`'s own executive decision) - not N wavelengths,
   not a WDM mux of any kind.
3. **`gcb-spec/bench_emulation_parameters.md`** (Task 3 bench, cross-
   checked in this ticket's first pass): N=4-8 channels combined via a
   **COTS fused-fiber intensity/power coupler tree** - power-summing, not
   frequency-domain multiplexing.
4. **`gcb-rtl/sim/mmi_tree_model.py`** (Task 1's own numerical model, the
   thing the Task 3 bench exists to validate against): explicitly states
   *"The MMI tree is a POWER-SUMMING combiner with excess loss only...
   Optimistic combiner model; a fully mutually-incoherent N:1 combiner
   would carry ~10*log10(N) dB more"* - single wavelength throughout, no
   wavelength-selectivity concept anywhere in the model. Its own `K` means
   a **cascade stage count** (`8^K` compute units reducing through `K`
   cascaded 8:1 power-summing stages), not a simultaneous wavelength-
   channel count - a second, independent point of terminology confusion
   this session's "K=16 = 16 wavelengths" assumption ran into.

**Decision**: `gcb-pic-core`'s K=16 tile has no spec-grounded requirement
for wavelength-division multiplexing, channel spacing, or any
frequency-domain combining at all. The program's actual, `gcb-spec`-
authoritative optical combining mechanism - at every tier checked (Task 1
model, Task 3 bench BOM) - is **single-wavelength, power-summing MMI
combining**. "Channel spacing" is not merely unresolved; it is **not the
right concept** for this component, full stop.

**Consequence for `TKT-030` (acknowledged here, corrected there)**:
`wdm_combiner_tree.py` and `k16_tile.py` (committed this session,
`gcb-pic-core@391d6bd`/`a3e1525`) implement a real, working WDM binary-
tree combiner - but target an architecture with no `gcb-spec` grounding.
This is a genuine correction to `TKT-030`'s own closure, not a footnote -
see `TKT-030`'s own follow-up Execution Log for the honest accounting and
the replacement, spec-grounded component.

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

1. **`gcb-pic-core` needs a spec-grounded replacement component** for
   `wdm_combiner_tree.py`/`k16_tile.py`: a single-wavelength, power-
   summing MMI combiner tree matching `gcb-rtl/sim/mmi_tree_model.py`'s
   actual Task 1 model (an 8:1 cell - two 4x1 MMIs into one 2x1 MMI - not
   a WDM/dispersive structure). See `TKT-030`'s own follow-up for the
   replacement built this session.
2. Extend `mode_solve_strip.py`'s FEM approach (or build a new script) to
   model the real MMI power-combiner geometry (not just a bare
   waveguide) and extract a real coupling/insertion-loss figure -
   materially bigger work, still deferred per this ticket's own Part B
   finding #5.
3. If/when real insertion-loss or phase-noise figures are obtained: feed
   them back into `optical_mesh_dpi.cpp`'s `snr_db`/`phase_deg`
   parameters, per the Architect's own framing of this ticket's purpose -
   not attempted this session (blocked on item 2 above).
4. A human maintainer should reconcile the two `gcb-wiki` passages
   flagged this session (`gcb-wiki@3f8a319`) - either ground the DWDM/
   8x8-mesh framing in a real `gcb-spec` citation if it's an intentional
   separate future-phase concept, or retire it.

## Out of scope

- Creating a `tidy3d` account or any other external-service signup,
  without explicit Architect authorization.
- `TKT-019.19` and anything in that neighborhood - unrelated.

## Telemetry & Evaluation

Spec 0.95 - both named halves of the Architect's own framing were
resolved: Part A with a decisive, `gcb-spec`-grounded answer (not an
escalation), Part B with a real, reproduced toolchain result. Quality 0.9
- the resolution is backed by an exhaustive grep across `gcb-spec` (not a
sampled read) plus direct reads of the three authoritative documents that
settle it; not 1.0 because the replacement MMI-combiner layout itself is
tracked under `TKT-030`'s follow-up, not built inside this ticket.
Emergence 0.75 - this ticket surfaced something bigger than its own
channel-spacing question: a real, previously-unnoticed methodology error
(treating `gcb-wiki` as co-equal evidence with `gcb-spec`) that the
Architect corrected and that is now saved as a standing discipline
(`gcb-wiki-not-source-of-truth` memory) - directly changes how future
architecture questions in this program should be resolved, not just this
one.

**Final State:** `done | blue` - Part A resolved decisively against
`gcb-spec` (no WDM grounding exists for `gcb-pic-core`'s tile); Part B's
toolchain result stands, already committed and verified
(`gcb-pic-core@23ec5dd`, `HEAD == origin/main`). The replacement,
spec-grounded combiner layout is tracked as `TKT-030`'s own follow-up,
not reopened here.
