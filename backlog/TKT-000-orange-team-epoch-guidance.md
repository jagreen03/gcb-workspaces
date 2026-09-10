---
id: TKT-000
title: "Orange Team epoch guidance — Physical Reality First, and the RTL/P&R toolchain split"
date_created: 2026-09-10
status: done
telemetry_color: orange
tags:
  - backlog
  - doctrine
  - strategy
  - orange-team
  - physical-design
  - epoch
  - toolchain
---

# Objective

Capture the Orange Team's external advisory as project doctrine and give it a
`TKT-` number so the Cyclopter knowledge graph carries it. Two load-bearing
outputs:

1. **The epoch mandate — "Physical Reality First".** TKT-001…017 proved the
   compute path *functionally*: bit-exact INT4 math, 0 SRAM read stalls, the
   4096 MAC/cycle theoretical peak (TKT-017 / TKT-025). None of that is evidence
   the RTL *closes timing*, *fits an area budget*, or *routes without
   congestion* at 5nm-class density — those are falsifiable only by pushing real
   gates through place & route. **TKT-018 is re-cast as a Measurement Epoch** to
   extract that silicon feedback *before* TKT-019's optical-transport scale-up
   commits to wavelength count, serialization width and PHY area.
2. **The toolchain split.** Formally isolate the RTL-verification toolchain from
   the P&R toolchain so a P&R environment build can never again silently move
   the RTL baseline (as TKT-021 did — Yosys 0.52→0.68, Python 3.12→3.14,
   `/tmp/cocotb19` destroyed; caught only by the TKT-022 Yellow-Team check).

This ticket is a **doctrine deliverable**, not graded execution. It changes no
RTL and no code; its artifact is this document and the README index entry.

## The Orange Team advisory — core philosophy (verbatim)

> **Measure first. Then interpret. Then change the architecture. The first
> physical pass should be deliberately ugly.**

Read into practice:

* **Measure first.** Run one verified block through a *default* P&R flow with no
  tuning. The value of the pass is the **report** (area, `WNS`/`TNS`,
  congestion, power, DRC classes), not the quality of the GDSII.
* **Then interpret.** A negative slack, a congested route, a large macro — these
  are **successful measurements**, not failures. They are the silicon feedback
  the architecture has never had.
* **Then change the architecture.** Architectural change (pipeline depth,
  operand width, block partitioning, optical serialization) is made *from the
  numbers*, in follow-on tickets — not pre-emptively, and not inside the
  measurement pass.
* **Deliberately ugly.** No floorplan hand-optimization, no timing-driven synth
  sweeps, no congestion ECOs, no PDK cherry-picking, no clock-relaxation to
  fake `WNS ≥ 0`. Default ORFS recipe, ASAP7, one block, once.

## Epoch: Physical Reality First

| epoch | tickets | proves | toolchain |
|---|---|---|---|
| **RTL / functional** (complete) | TKT-001 … TKT-017 | the math is correct, the dataflow does not stall | RTL Baseline (below) |
| **Measurement** (this mandate) | **TKT-018**, rescoped | what silicon actually costs: area, timing, congestion, power, DRC on a real verified block | P&R Environment (below) |
| **Architecture-from-measurement** | new tickets, spawned by the TKT-018 report | the design changed *because the numbers said so* | both, at the file boundary |
| **Optical transport** | TKT-019 | — | **blocked** until the Measurement report exists and is interpreted |

## Toolchain isolation — the split

The two chains **share no installable component** and meet only at a file
boundary (an elaborated Verilog netlist in, reports out).

### RTL Baseline — LOCKED

Authoritative pin: `gcb-wdm-transceiver/sim/toolchain_manifest.json`.

| tool | version | role |
|---|---|---|
| Yosys | **0.68** | `sv2v` → Yosys SV-2017 elaboration + latch-free check (golden: `sim/yosys068_bless/`) |
| Verilator | **5.032** | `sim/lint.sh` gate + cocotb `SIM` backend |
| `sv2v` | **0.0.12** | SystemVerilog → Verilog-2005 front end |
| Cocotb | **1.9.2** | functional TBs |
| Python | **3.12.14** | cocotb interpreter (uv-managed CPython) |
| numpy | **2.5.3** | golden-model reference |
| venv | `~/.venvs/cocotb19` | persistent (survives `wsl --shutdown`); rebuild recipe in the manifest |

This set is **frozen**. Any change is a deliberate, reviewed re-pin with a full
baseline regression + a re-bless of `sim/yosys068_bless/` (the TKT-022 remediation
procedure).

### P&R Environment — ISOLATED

| tool | notes |
|---|---|
| OpenROAD | built from source (TKT-021), `build_openroad.sh --local` |
| OpenROAD-flow-scripts (ORFS) | pinned checkout, container-free |
| KLayout | **0.30.12** (upstream `.deb`) — DEF/GDS view, DRC deck runner |
| ASAP7 | the open 5nm-class PDK stand-in; PDK-parameterised so a real node drops in later |

Lives in its **own environment** — a dedicated WSL distro / container / user /
directory tree that shares nothing installable with the RTL Baseline. Its
`apt` / `pip` / `uv` / build activity must have **no path** to move Yosys,
Python, `sv2v`, Verilator or the `~/.venvs/cocotb19` venv.

### Isolation invariants

1. The P&R environment never runs a package manager against the RTL Baseline
   guest or its venv.
2. **Drift tripwire (standing gate).** After any P&R environment change, re-run
   the RTL Baseline: `bash sim/lint.sh` (exit 0) + the `sim/run_tb.sh` cocotb
   stanzas + the toolchain-manifest diff. A non-empty manifest diff or a
   `FAIL ≠ 0` **halts the Measurement Epoch** until re-pinned. (This is the
   TKT-022 Yellow-Team check, promoted to a permanent gate.)
3. The chains meet only at a **file boundary**: the RTL Baseline emits the
   `sv2v` → Yosys-elaborated netlist (`sim/yosys068_bless/` is its golden
   reference); the P&R environment consumes that and emits `report.json` /
   `floorplan.png` / DRC logs. No shared tool binary, no shared `PATH` entry.
4. ASAP7 and any PDK material stay in the P&R environment — **never** in
   `gcb-wdm-transceiver` / `gcb-rtl` / `gcb-host` (`gcb-wiki/04` boundary +
   `gcb-wiki/10` EDA doctrine).

## The Orange vector (PBG-O)

The PBG telemetry vector (`gcb-wiki/09`) grades an outcome on three orthogonal
axes — **X** Specification (Green↔Red), **Y** Quality (Blue↔Yellow), **Z**
Emergence (Purple↔Light-gray): *how well does the artifact meet its spec, how
sustainably is it built, does it create reusable capability.*

**Orange is a fourth disposition, orthogonal to all three: has the artifact been
confronted with physical reality, and can it be falsified by it?**

* A ticket is **`orange`** when its deliverable's primary worth is a
  **measurement that can contradict an architectural assumption** — cell area,
  timing slack, routing congestion, power, DRC.
* An Orange outcome **deliberately does not optimize X / Y / Z.** A "bad" number
  — negative `WNS`, high congestion, an oversized macro — is a **positive**
  Orange result: it is the physical falsification the design has never had.
* Orange is **not** a colour on the R³ vector and does not change `gcb-wiki/09`'s
  maths. It is a working-doctrine flag introduced here; promoting it to a named
  spoke in `gcb-wiki/09` is a follow-on *iff* the Measurement Epoch proves the
  concept.
* `telemetry_color: orange` is a valid grade for a ticket whose job is to buy a
  measurement. The derived-label rule in `gcb-wiki/09` §5 is unaffected for
  every other ticket.

## Mandate for TKT-018 (Measurement Epoch)

TKT-018's Objective is rescoped (see that ticket): **not** a manufacturable,
timing-closed 5nm-class GDSII, but a single unoptimized pass of the smallest
fully-verified macro — **`gcb_max_reduce`** (TKT-016) — through the default
ORFS / ASAP7 flow, to extract:

* cell area + instance count,
* `WNS` / `TNS` at a stated clock,
* estimated power,
* routing congestion / utilization,
* DRC violation classes,

and produce `report.json` + `floorplan.png` + **a written interpretation** that
feeds TKT-019 and any architecture-from-measurement tickets. A timing-closed,
DRC-clean result is explicitly **not required** for this epoch.

## What this does NOT authorize

1. **No RTL change to close timing.** An un-closeable block is a *finding*,
   filed back as its own ticket — not patched in the netlist or the RTL to make
   the measurement look better.
2. **No merging P&R tooling into the RTL Baseline**, and no RTL Baseline tool
   upgrade "while we're in there".
3. **No TKT-019 execution** until the TKT-018 measurement report exists and has
   been interpreted.
4. **No PDK / foundry NDA material** in any repository.
5. This is doctrine, not a licence to skip the per-block verification gates —
   every block entering P&R is still `sim/lint.sh` / cocotb / elaboration green
   first.

---
## Execution Log

* **Agent ID:** Lead Architect / Project Manager (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`.
* **Source:** Orange Team external advisory relayed by the Architect,
  2026-09-10.
* **Actions:**
  * Authored this doctrine document.
  * Rescoped `TKT-018-epic-openroad-physical-layout.md` Objective to a
    **Measurement Epoch** on `gcb_max_reduce` (see that ticket's diff).
  * Inserted TKT-000 at the head of the `gcb-workspaces/README.md` index and
    layout tree as a foundational strategic document (`done | orange`).
* **Not changed:** any RTL, any code, `gcb-wiki/09` (the PBG maths); the RTL
  Baseline toolchain pin (`sim/toolchain_manifest.json`) — this ticket
  *references* it as the locked side of the split, it does not alter it.

---
## Telemetry & Evaluation

**Final State:** `orange`

**Vector Summary:** `PBG-O = orange` (Physical Falsifiability). Not graded on the
R³ PBG axes — this ticket optimizes none of X / Y / Z; its worth is that it
commits the project to physical falsification of the RTL epoch's assumptions
before optical scale-up, and formally isolates the toolchains so that
falsification pass cannot corrupt the verified baseline.

* **Why Orange, not Green.** A Green grade would claim the doctrine is
  *in-spec and done right*. That is not the point: the doctrine's value is only
  realised when TKT-018 returns numbers that may *contradict* current
  architectural assumptions. TKT-000 is the instrument; the measurement is
  TKT-018.
* **Falsification hook.** If the TKT-018 pass shows `gcb_max_reduce` closes
  timing comfortably with low congestion and small area, the "deliberately
  ugly first pass" mandate is vindicated cheaply. If it shows the opposite,
  TKT-000 has done its job: the optical-transport epoch is held until the
  architecture is re-planned from real silicon feedback.

Cyclopter scavenger (TKT-013) ingests this as the first `orange`-graded node —
the epoch marker the P&R-era tickets cluster against.