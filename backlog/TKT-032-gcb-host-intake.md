---
id: TKT-032
title: "gcb-host intake: C++ pilot driver / MMIO proxy - survey complete, real connection to gcb-rtl confirmed"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.9
  quality: 0.9
  emergence: 0.4
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

- [x] **Step 1 - read the actual source. DONE.** `include/greencoyote_pilot.hpp`
  (~800 lines) is a real, substantial header-only C++ driver - NOT a stub -
  targeting an **Alveo U55C FPGA via Xilinx Runtime (XRT)**, with a
  `/dev/mem` bare-metal fallback. It opens an XRT IP named literally
  `"greencoyote_top"`. Register surface (from
  `include/generated/greencoyote_regmap.hpp`, `map_version: 0.6.0`):
  `PRECISION_MODE` (INT4/FP4/FP8/BF16), `GLOBAL_CAL`, `CH_GAIN_TRIM` (8
  channels), `REDUCTION_CTRL`, `IRQ_CTRL`, an 8-port **crossbar**
  (`XBAR_MODE_STATUS`/`XBAR_ROUTE_LO`/`HI`, with `XBAR_TENSOR`/`PIPELINE`/
  `MOE`/`CUSTOM` routing modes for multi-GPU tensor/pipeline/MoE
  parallelism), plus `TRAIN_CTRL`/`GRAD_UPDATE_STATUS`/`LORA_TILE_ADDR`/
  `GRAD_REDUCE_CTRL`, `EXEC_CTRL`/`BRAM_WR_*`, snapshot/rollback/fault-log,
  task-allocation/scheduling, and `SS_TDC_CTRL`/`SS_CAL_IDX`/`SS_CAL_DATA`
  (matching `gcb-rtl`'s single-slope TDC readout by name). `proxy/gcb_proxy.py`
  is a real, self-checking pure-Python MMIO simulator (NOT FastAPI - see
  Step 4). `tools/hf_manifest_gen.py` exists (not yet read in detail -
  out of scope for this pass).
- [x] **Step 2 - attempt the C++ build. NOTHING TO BUILD - reported
  honestly, not as a blocked attempt.** `src/` and `tests/` are BOTH
  **completely empty** (confirmed by direct listing). No `CMakeLists.txt`,
  `Makefile`, or any build file exists anywhere in this repo. The "C++
  pilot driver" is a header-only API declaration with a real, working
  implementation inside the header itself (not a stub), but there is no
  project-level build target, no compiled artifact, and nothing to
  "attempt to build" in the sense this step asked - there is no build
  system to run, not a build system that failed.
- [x] **Step 3 - attempt the existing `tests/` suite. REDIRECTED to the
  real test surface, then run - ALL PASS.** `gcb-host/tests/` is empty,
  but Step 5 (below) confirmed this driver's real register-level
  counterpart lives in `gcb-rtl`, which DOES have a real, runnable
  regression (`sim/run_pilot_tb.sh`, `run_dma_tb.sh`, `run_ss_tb.sh`, via
  Icarus Verilog - already available, confirmed `which iverilog vvp`).
  Ran all three fresh: `tb_cs_fifo_path` (the pilot/register-block
  testbench) **ALL CHECKS PASS**; `tb_dma_integration` **ALL CHECKS PASS**
  (`saw_armed=1 fire_seen=1018 opv_seen=1018 underrun=0 errors=0`);
  `tb_ss_calib` **10000/10000 PASS** + `tb_ss_tdc` **ALL CHECKS PASS**. The
  RTL side of this connection is genuinely healthy and regression-green;
  the gap is entirely host-side (Step 2's finding).
- [x] **Step 4 - attempt the proxy smoke test. RAN, PASSED - but the
  README's own description is wrong.** `gcb_proxy.py` contains **no
  FastAPI import, no `app =`, no `@app.` route, no `uvicorn` - anywhere in
  the file** (confirmed by direct grep, not assumption). It is a
  self-contained, self-checking pure-Python MMIO register simulator, not
  an HTTP proxy of any kind. Ran it directly: exercises a DMA descriptor
  push + doorbell + arm + a reduction trigger against the real v0.6.0
  register map, asserts `ARM`/`FIRE` w1p strobes self-clear and the
  unmapped-read sentinel reads back correctly - **exit 0, "OK - v0.6.0
  MMIO map exercised"**. `gcb-host`'s own top-level README ("FastAPI MMIO
  proxy") is stale/inaccurate for what this file actually is - flagged,
  not silently corrected on the Architect's behalf.
- [x] **Step 5 - relate to existing RTL. DONE - the original hypothesis
  in this ticket was WRONG, found by checking, not assumed.** This
  ticket's own roadmap guessed the connection point was
  `gcb_dwdm_ctrl_axi.sv` (`gcb-wdm-transceiver`) - **refuted**. The real
  connection is to `gcb-rtl/rtl/greencoyote_top.sv` +
  `greencoyote_pilot_regs.sv`, confirmed two ways: (1) the C++ driver
  literally opens an XRT IP named `"greencoyote_top"`; (2) the generated
  register packages on both sides are **genuinely synchronized**, not
  merely similarly-named - `map_version: 0.6.0` matches exactly, and
  every checked offset matches exactly between
  `gcb-host/include/generated/greencoyote_regmap.hpp` and
  `gcb-rtl/rtl/generated/greencoyote_regmap_pkg.sv` (`PRECISION_MODE=0x00`,
  `GLOBAL_CAL=0x04`, `CH_GAIN_TRIM_LO/HI=0x08/0x0C`, `REDUCTION_CTRL=0x10`,
  `SS_TDC_CTRL=0xB0`, ...). `gcb_dwdm_ctrl_axi.sv` (the `gcb_*`-namespace,
  post-`GCB-026`-migration WDM transceiver CSR interface) is an entirely
  **separate, unrelated** control surface - `gcb-host`'s driver targets
  the older `greencoyote_*`-namespace hardware design in `gcb-rtl`, not
  `gcb-wdm-transceiver` at all.

## Telemetry & Evaluation

Spec 0.9 - all five roadmap steps executed exactly as scoped, with two
steps (2, 3) honestly redirected rather than forced when the literal
instruction didn't match reality (no build system exists; the real test
surface is in `gcb-rtl`, not `gcb-host`). Quality 0.9 - every claim is
backed by a direct check (grep for FastAPI usage, diffing register
offsets between two repos, actually running three Icarus testbenches and
one Python script), and the survey's own starting hypothesis (Step 5,
`gcb_dwdm_ctrl_axi.sv`) was found wrong and corrected rather than
confirmed by assumption. Not 1.0: `tools/hf_manifest_gen.py` was not read
in detail (flagged, not silently skipped); no attempt was made to
actually build a minimal CMake/Makefile for the header-only driver (that
would be new work, not a survey). Emergence 0.4 - this survey surfaced a
real, previously-undocumented cross-repo link (`gcb-host` <->
`gcb-rtl`'s `greencoyote_top`, sharing a genuinely-synchronized generated
register map) that existed in neither repo's own README, plus a real
documentation inaccuracy (the "FastAPI" description) worth a human
maintainer's attention.

**Final State:** `done | blue` - full survey completed, all roadmap steps
closed. No RTL or code changed (this ticket is intake/survey only, per
its own stated scope) - findings recorded here for whoever picks up
follow-on work (a real `gcb-host` build system, or correcting the
README's "FastAPI" description).

---
## Follow-up (2026-09-12, same day) - directed "build-and-run verification
pass": re-confirmed this ticket's own closure still holds, then closed
its one flagged-but-unpursued gap

**The Architect's next-step framing ("open up TKT-032 for its build-and-
run verification pass") predated this ticket's own closure earlier the
same session. Re-verified rather than silently re-run**: `src/`/`tests/`
are still both empty except for what this follow-up itself adds (no
build system has appeared) - the earlier survey's findings stand.

1. Read `tools/hf_manifest_gen.py` in full (Step 1's own "not read in
   detail" flag) - a real, substantial (~725-line) HuggingFace config ->
   GreenCoyote hardware-requirement manifest generator + negotiation
   engine, not a stub.
2. **Ran it for real** against two synthetic HF-style configs
   (`--local`, no network dependency): a 70B-dense-model-shaped config
   correctly `REJECTED` (needs 384 tiles vs. the 16-tile prototype
   default); a small dense config correctly `DEGRADED`/accepted-with-
   warnings.
3. **Caught and corrected a false lead in my own verification, not in
   the tool**: checking the exit code via `$?` immediately inside the
   same `wsl bash -c '...'` invocation that ran the script reported `0`
   for the `REJECTED` case, which looked like a real bug (the script's
   own `exit_codes` mapping says `REJECTED -> 1`). Re-checked with a
   minimal `false; echo $?` control (no Python involved) and reproduced
   the same wrong `0` - proving this is a WSL-invocation quirk in how
   `$?` is read *inside* that exact invocation shape, unrelated to
   `hf_manifest_gen.py`. Re-checked the real exit code from OUTSIDE the
   `wsl` call instead: genuinely `1` for `REJECTED`, `0` for
   `DEGRADED`/`ACCEPTED` - the tool's own logic is correct; the earlier
   reading was a measurement artifact, caught before being reported as a
   bug.
4. Added `tests/test_hf_manifest_gen.py` - the first real test in this
   previously-empty directory: 3 scenarios (large dense -> `REJECTED`,
   small dense -> `DEGRADED`, a DeepSeek-V3-shaped MoE config -> expert-
   count/active-expert extraction), 13 self-checking assertions (no
   pytest dependency, matching `gcb_proxy.py`'s own self-checking
   convention per this ticket's Step 4 finding), driven by direct import
   rather than subprocess (sidesteps the exit-code quirk entirely).
   **All 13 checks pass**, reproduced across two independent runs.
   Committed `gcb-host@d4be571`, pushed, `HEAD == origin/main` verified.

**Epistemic status: PROVEN — DIGITAL SIMULATION (direct Python
execution), TESTED CONDITIONS** for the 3 scenarios' negotiation-logic
outcomes and real exit codes. No claim about the actual FPGA/XRT hardware
path - `HardwareManifest.from_fpga()` returns a hardcoded prototype
default here, not a live register read, unchanged and not exercised by
this pass.

**Final State (unchanged):** `done | blue`. This follow-up adds a real
test artifact and closes the one flagged gap from the original survey;
it does not reopen the ticket or change its disposition.
