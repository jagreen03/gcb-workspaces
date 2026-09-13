---
id: TKT-032
title: "gcb-host intake: C++ pilot driver / FastAPI MMIO proxy has never been surveyed or ticketed"
date_created: 2026-09-12
status: open
telemetry_color: pending
tags:
  - backlog
  - intake
  - hardware-connectivity
---

# Objective

`gcb-host` ("C++ pilot driver, FastAPI MMIO proxy, model manifest
tooling... part of the GreenCoyote-Bay photonic inference fabric") has
**never been surveyed or ticketed** in this backlog - discovered only in
the same repo sweep that found `gcb-pic-core` (`TKT-030`) and
`gcb-analog-rx` (`TKT-031`). Unlike those two, this ticket is
**intentionally a lightweight intake placeholder, not a completed
survey** - a real C++ pilot driver + MMIO proxy is "hardware
connectivity" tier (this program's own stated priority: Silicon > RTL >
hardware connectivity > software/tooling) and deserves the same
actually-run-it-and-verify treatment `TKT-030`/`TKT-031` got, but doing
that properly (build the C++ driver, exercise the FastAPI proxy, check
for an existing test suite and whether it passes) is its own bounded
task, not a five-minute add-on to an already-long session.

## What is known so far (from the README only - not yet verified)

- C++ pilot driver (`src`/`include`) - presumably the host-side code that
  actually talks to the real hardware's MMIO registers.
- A FastAPI MMIO proxy (`proxy`) - a software shim, likely for
  development/testing without real hardware attached, or for a
  higher-level orchestrator to reach the driver over HTTP.
- Model manifest tooling.
- A `tests/` directory exists - unknown whether it currently passes,
  what it covers, or what toolchain it needs.
- `GCB_STATE_COMPRESSION.txt` at the repo root - purpose not yet
  determined.

## Required work (next iteration, not this one)

1. Read `gcb-host`'s own docs/code in full (not just the README) to
   understand what the pilot driver and MMIO proxy actually claim to do,
   and how they relate to this program's existing RTL/digital components
   (the AXI4-Lite CSR interface already built into
   `gcb_dwdm_ctrl_axi.sv`/`gcb_dwdm_dualmode_top.sv` is the most likely
   real connection point - confirm or refute this, don't assume it).
2. Attempt to build/run the existing `tests/` suite and report real
   pass/fail results, matching this program's own "verify before
   claiming" standard - not a code-review-only assessment.
3. Determine whether this repo's own test/build toolchain is already
   available in this dev environment or needs its own setup (the
   `~/.venvs/gdsfactory` and `~/.venvs/cocotb19` precedents are the
   pattern to follow if a new venv/toolchain is needed).
4. Only after (1)-(3): decide what, if anything, is actionable RTL/
   hardware-connectivity work here, and scope it into its own ticket(s) -
   this ticket's job is the survey, not the fix.

## Out of scope

- Any RTL change - this ticket is intake/survey only.
- `TKT-019.19` and anything in that neighborhood - unrelated.

---
## Roadmap (established 2026-09-12) - work in order; a blocked step is a
logged finding that advances to the next step, not a reason to stop

- [ ] **Step 1 - read the actual source.** `include`/`src`/`proxy`/
  `tools`/`tests` directories and `GCB_STATE_COMPRESSION.txt` - understand
  what the pilot driver and MMIO proxy actually claim to do, from the code
  itself, not the one-paragraph README.
- [ ] **Step 2 - attempt the C++ build.** Identify the build system
  (CMake/Makefile/other - confirm, don't assume) and attempt it; report
  the real toolchain requirement (compiler version, libraries) and
  whether it's already available in this dev environment or needs setup
  (matching the `~/.venvs/gdsfactory`/`~/.venvs/cocotb19` precedent if a
  new environment is needed).
- [ ] **Step 3 - attempt the existing `tests/` suite.** Report real
  pass/fail, not a code-review guess.
- [ ] **Step 4 - attempt the FastAPI MMIO proxy smoke test.** Identify
  its own dependencies (likely a Python venv); start it and confirm it at
  least responds, even if a full hardware-attached test isn't possible in
  this environment.
- [ ] **Step 5 - relate to existing RTL.** Confirm or refute whether this
  driver/proxy's MMIO model actually corresponds to
  `gcb_dwdm_ctrl_axi.sv`'s real AXI4-Lite CSR map (register addresses,
  widths) - by reading both sides directly, not by assuming the obvious
  connection is the real one.

## Telemetry & Evaluation

No PBG grade - this is an unexecuted intake placeholder, not a completed
assessment (contrast `TKT-030`/`TKT-031`, which ARE completed surveys for
their own repos).

**Final State:** `open | pending` - survey not yet performed. Roadmap
above tracks the steps.
