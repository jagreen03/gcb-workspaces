---
id: TKT-030
title: "gcb-pic-core Component 4: verify + extend the balanced-homodyne layout toward a real K=16 tile"
date_created: 2026-09-12
status: open
telemetry_color: pending
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

## Telemetry & Evaluation

No PBG grade - this ticket documents a verified current state and a
scoped next step; it does not itself execute the K=16 layout.

**Final State:** `open | pending`
