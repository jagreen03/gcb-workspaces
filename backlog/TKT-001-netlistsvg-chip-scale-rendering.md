---
id: TKT-001
title: "Migrate RTL schematic rendering off netlistsvg to a headless chip-scale layout engine"
date_created: 2026-09-08
status: open
telemetry_color: pending
tags:
  - backlog
  - tooling
  - visualization
---

# Objective

Close the visualization-layer capability gap: `gcb-dashboard/build_visuals.py`
(`DigitalRtlBuilder`) cannot produce a schematic for any RTL module whose
flattened netlist contains a wide register array or a deep address-decode mux
tree. `netlistsvg` — the current `yosys JSON -> SVG` renderer — aborts on these
with a V8 stack overflow, so the DMA engine, the AXI read master, the SS/TDC, and
the MMIO register file (the modules a reviewer most wants to see) never render.
The pipeline must be able to turn every `greencoyote_*` / `gcb_*` top into a
diagram, headlessly, in CI, with no per-module manual fallback.

**Scope:** a single-path replacement of the render backend inside
`gcb-dashboard/build_visuals.py` — Option B below (headless DigitalJS via
`yosys2digitaljs` + `elkjs`), grading Green only once `netlistsvg` (and the
Graphviz bridge, if used) are out of `DigitalRtlBuilder` entirely. The
visualization pipeline lives in `gcb-dashboard/`, not `gcb-python-orchestrator/`.

## Context & Constraints

* **Current State:** `netlistsvg`'s `FlatModule.gather()` net walker
  (`built/FlatModule.js:102`, `indexOfContains` <- `gather` <- `gather`) recurses
  over net connectivity **per bit with no depth guard**. On the GCB RTL the
  flattened Verilog is dense with structures yosys lowers to register lists
  (`ring_mem`, `r_lc_init`, pipeline `acc_p*` / `lfsr_p*`, the 64-bank weight
  store, the pilot-register readback `case`). Walking a 32-bit x N-entry fan-out
  drives `gather` thousands of frames deep and throws
  `RangeError: Maximum call stack size exceeded`.
  * Confirmed on `greencoyote_streaming_dma`, `greencoyote_dma_axi_master`
    (~5120 cells), `greencoyote_ss_tdc` (~1373 cells), and
    `greencoyote_pilot_regs` (**only ~367 cells**). The 367-cell case is the
    tell: this is a **recursion-shape bug, not a raw scale limit**.
  * yosys is **not** implicated — `prep -top <each>` elaborates all 12 gcb-rtl
    tops cleanly ("Found and reported 0 problems", exit 0). The failure is
    entirely downstream in the renderer.
  * Mitigations already falsified: `node --stack-size=4000/8000` still overflows;
    `--stack-size=12000` makes node `SIGSEGV` (rc 139). A structural yosys pass
    (`hierarchy; proc; opt_clean`, no `flatten`/`techmap`) still overflows.
    `netlistsvg` has no upstream fix and is scoped to small structural datapaths.
* **Constraint:** No athletic execution and no brittle patches. The fix must be
  (a) **headless** (runs in the VS Code task and in CI with no GUI),
  (b) **scalable** (bounded memory / non-recursive layout that survives
  thousand-cell netlists), (c) **single-path** (no "renderer A for small, renderer
  B for big" split to maintain long-term), and (d) free of forked third-party
  source. A time-boxed bridge is permitted only if it is explicitly labelled as
  temporary and tracked to removal in this ticket.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid,
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation (no real capability delivered).

* **Option A — Graphviz (`yosys show -format svg`) fallback tier:** **Yellow.**
  Athletic workaround. It unblocks "produce *an* artifact for every module"
  within ~20 min, but it does **not** close the stated gap: Graphviz `dot`
  output is orthogonal-routed spaghetti, not a bus-aware schematic, so the
  chip-scale datapaths remain effectively unreadable. It also violates two
  constraints — it introduces a second renderer path plus a `graphviz` system
  dependency (`apt install graphviz`, needs sudo), and it keeps `netlistsvg` in
  the critical path. Defensible **only** as a clearly-marked temporary bridge
  while Option B lands; not an acceptable end state.

* **Option B — Headless DigitalJS (`yosys2digitaljs` + `elkjs` layout):**
  **Green target, Blue execution.** This fundamentally closes the capability
  gap. `elkjs` is a non-recursive, bounded layout engine that natively handles
  large netlists; it is the *same* engine as the `DigitalJS-VSC` extension the
  codebase already names as the interactive fallback, so the batch output and
  the human's interactive view converge. It is headless, scriptable from a small
  Node wrapper that `build_visuals.py` shells out to, and it lets us **delete
  the `netlistsvg` dependency entirely** — collapsing back to a single render
  path. Cost ~0.5 day. This is the outcome the ticket should be graded against.

* **Option C — Patch / vendor `netlistsvg`'s `FlatModule.gather()`:** **Red.**
  Brittle technical debt. It means forking third-party npm source and
  maintaining a recursion-to-iteration rewrite of code we do not own; every
  `npm i -g netlistsvg` or lockfile bump re-opens the wound, and the patch has
  to be re-validated against each GCB RTL revision. Option B makes the entire
  effort moot. Do not pursue.

* **Do-nothing (retain the current graceful-skip):** **Light-gray.** The interim
  `build_visuals.py` already degrades safely — yosys-fails are hard errors,
  `netlistsvg` stack overflows are logged skips pointing at DigitalJS-VSC, and
  the orchestrator exits 0 with 12/17 SVGs. Zero capability delivered for the
  remaining 5 modules; a permanent manual step. Acceptable holding pattern, not
  a resolution.

**Recommended vector:** ship Option A as an explicitly temporary bridge **iff**
the 5 missing diagrams are needed before B can land; otherwise skip straight to
Option B. Grade this ticket Green only when B is merged and `netlistsvg` +
Graphviz are both out of the pipeline.

## The "Green" Target

A "Green" outcome is a **clean, single-path migration to a headless layout
engine** (DigitalJS / `elkjs`, driven via `yosys2digitaljs`) such that:

1. Every RTL top in `GCB_RTL_TOPS`, `QAM_RTL_TOPS` (and any future set) renders
   to one SVG — including `greencoyote_streaming_dma`,
   `greencoyote_dma_axi_master`, `greencoyote_ss_tdc`, `greencoyote_pilot_regs`
   — with **no capacity skip and no `RangeError`**.
2. The render is **headless and deterministic**: it runs unattended in the
   `VIS: Build Hardware Visualizations` task and in CI, no browser, no GUI, no
   sudo-installed native package beyond the Node toolchain.
3. Layout is **non-recursive / bounded** — a thousand-cell netlist lays out in
   bounded stack and predictable memory; large modules produce a legible
   hierarchical schematic, not a crash and not `dot` spaghetti.
4. `netlistsvg` is **removed** from `DigitalRtlBuilder` (dependency, code path,
   and `is_available()` probe). The Graphviz bridge, if it was introduced, is
   also removed. The builder is back to one rendering path.
5. Batch output visually matches the interactive `DigitalJS-VSC` fallback, so a
   reviewer sees the same diagram in CI artifacts and in the editor.
6. `build_visuals.py` still exits non-zero only on a genuine elaboration failure;
   a successful full run reports `N built, 0 skipped, 0 failed`.

---
## Execution Log
*(To be populated during execution)*
* **Agent ID:**
* **Commands Run:**
* **Artifacts Touched:**

### Pre-ticket diagnostic (session 01Rpa9VJGe7xypzp5FkukSco, 2026-09-08)
Not the ticket execution — root-cause and interim hardening only.
* **Commands Run:**
  * `sv2v rtl/generated/*.sv rtl/*.sv > flat.v` then
    `yosys -q -p 'read_verilog -sv flat.v; prep -top <top>; write_json ...'`
    for all 12 gcb-rtl tops -> all elaborate, exit 0.
  * `netlistsvg <top>.json -o <top>.svg` per top -> 8 pass, 4 crash with
    `RangeError: Maximum call stack size exceeded` in `FlatModule.js` `gather`.
  * `node --stack-size={4000,8000,12000} $(realpath $(which netlistsvg)) ...`
    -> 4000/8000 overflow, 12000 SIGSEGV (rc 139).
  * `yosys -q -p '... hierarchy -top <top>; proc; opt_clean; write_json ...'`
    (structural, no flatten) -> netlistsvg still overflows.
  * `yosys -q -p '... prep -top <top>; show -format svg ...'` -> works but
    `sh: 1: dot: not found` (graphviz absent; `sudo apt install graphviz` times
    out under a non-interactive shell).
* **Artifacts Touched:** `gcb-dashboard/build_visuals.py` (uncommitted interim):
  typed `YosysError` / `NetlistSvgError(capacity=)`, per-stage stderr capture,
  `read_verilog -sv` (unblocks all 5 `qam-v2` tops), `node --stack-size` wrapper,
  capacity-skip instead of hard-fail. Post-change full run:
  `rtl:gcb-rtl` 8 SVG + 4 skip, `rtl:qam-v2` 4 SVG + 1 skip, orchestrator exit 0.
  This is the Light-gray holding pattern, to be superseded by Option B.

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
