---
id: GCB-030
title: "Story 3 of the Measurement Epic (TKT-018) — enable synthesis register retiming and re-measure gcb_max_reduce (REG_STAGES=2)"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - eda
  - physical-design
  - measurement-epoch
  - openroad
  - asap7
  - synthesis
  - retiming
  - orange
---

# Objective

**Story 3 of EPIC `TKT-018` — the Measurement Epoch** (mandate: [[TKT-000]]).
[[GCB-029]] measured that `gcb_max_reduce` with `REG_STAGES = 2` still misses the
1 ns target (`WNS = −442 ps`) because those are **output** pipeline stages after
the tournament tree, and **the default ORFS synth recipe runs no register
retiming** — the 46 flops stay downstream of the whole ~1.44 ns combinational
cone.

GCB-029 hypothesis 1: **turn register retiming on and re-measure.** This is a
knob on the *flow*, not the RTL — `gcb_max_reduce.sv` and the GCB-028
`gcb_tile_requantize.sv` change stay frozen. The decisive question:

> **Does synthesis retiming move the existing `REG_STAGES=2` registers into the
> tournament-tree levels far enough to break the cone and (nearly) close 1 ns?**

* **If yes** — GCB-028's `REG_STAGES=2` was already sufficient; only the P&R
  flow config needs a retiming line, and the RTL response is validated.
* **If no / not enough** — hypothesis 2 (a mid-tree pipelined `gcb_max_reduce`
  RTL variant) becomes the next ticket, now with a measured baseline for what
  retiming alone can and cannot do.

**Not pursuing timing closure.** A partial improvement, a register-count
explosion, or retiming blocked by the async-reset flops are all *successful
measurements* — the raw physical truth of what retiming buys.

## Context & Constraints

* **Only difference from GCB-029:** synthesis register retiming enabled. Same
  `sv2v` netlist, same `VERILOG_TOP_PARAMS = REG_STAGES 2`, same
  `constraint.sdc` (1000 ps, virtual-clock I/O), same `CORE_UTILIZATION` /
  `PLACE_DENSITY`, same platform, same default place/route recipe. Apples-to-
  apples with GCB-029 by construction.
* **First execution step is an assessment:** identify the ORFS retiming hook.
  Candidates, in order of least-invasive: a `SYNTH_*` / `ABC_*` env var the
  design `config.mk` can set; an ORFS-supported custom ABC script
  (`dretime` / `abc -dff -g`); the Yosys `abc` `-dff` path in
  `flow/scripts/synth_syn.tcl`; or (last resort) a one-line prepend to the
  synth Tcl via `SYNTH_SCRIPT`. Use the least-invasive one that ORFS documents;
  record exactly what was set.
* **Isolation ([[TKT-000]] toolchain split):** entire flow in the isolated P&R
  environment; no package manager against the RTL Baseline guest or
  `~/.venvs/cocotb19`; re-use the read-only `kepler-formal` `LD_LIBRARY_PATH`
  shim; after the run, re-execute the RTL Baseline drift tripwire
  (`bash sim/lint.sh` + manifest diff) and record it clean.
* **Deliberately unoptimized ([[TKT-000]]):** retiming is the *only* knob
  moved. No floorplan opt, no other synth sweep, no ECOs, no clock relaxation.
  `gcb_max_reduce.sv` frozen.
* ASAP7 / PDK material stays in the P&R env; nothing in an RTL repo.

## AI Orchestration Priorities — the Orange Target (PBG-O, [[TKT-000]])

Graded **Orange** — the deliverable is a GCB-029 → GCB-030 transfer function and
a yes/no answer on retiming, not an in-spec artifact.

* **Orange (target):** one ORFS / ASAP7 pass of `gcb_max_reduce` at
  `REG_STAGES=2` **with retiming enabled**, and **`GCB-030-FINDINGS.md`** — a
  direct GCB-029-vs-GCB-030 table for **WNS @ 1 ns, TNS, setup-violating path
  count, critical-path structure (still `input→max_val`? now
  `reg→reg` through tree logic?), flop count, sequential area, total area,
  power, routing congestion / DRC** — plus the answer: did retiming break the
  ~1.44 ns cone, and if so by how much? were the async-reset (`DFFASRHQN`)
  flops a barrier? did the flop count change?
* **A partial or null result is a PASS.** "Retiming closed WNS to −80 ps" or
  "retiming did nothing because the async resets pinned the flops" are both the
  measured transfer function — recorded, interpreted, not forced further.
* **Reject (Red):** editing `gcb_max_reduce.sv` or `gcb_tile_requantize.sv`;
  relaxing the 1 ns SDC; moving any floorplan/place/route knob vs GCB-029;
  running P&R in the RTL Baseline env; committing PDK material to an RTL repo;
  stacking multiple synth changes so the retiming effect can't be isolated.
* **Not this story (later `GCB-###`):** a mid-tree pipelined `gcb_max_reduce`
  RTL variant; `REG_STAGES=3/4`; `OUTPUT="VALUE"` area trade; achieving
  `WNS ≥ 0`; the PPA regression; SDC from Cocotb.

## The "Orange" Target (acceptance)

1. ORFS run of `gcb_max_reduce`, `VERILOG_TOP_PARAMS = REG_STAGES 2`, retiming
   enabled via the identified ORFS hook — config diff vs GCB-029 = that one
   setting, recorded verbatim.
2. Flow completes (or fails at a named stage — recorded). `report.json` +
   `floorplan.png` into `gcb-workspaces/eda/GCB-030/`.
3. `GCB-030-FINDINGS.md` — the GCB-029 → GCB-030 transfer function table + the
   retiming yes/no analysis (cone broken? by how much? flop count Δ? async-reset
   barrier?).
4. RTL Baseline drift tripwire re-run clean and recorded.
5. Diff confined to `gcb-workspaces/eda/GCB-030/` + `GCB-030-FINDINGS.md`.
   Nothing in `gcb-rtl` / `gcb-wdm-transceiver`; no PDK material in any RTL
   repo. GCB-029's config preserved at `eda/GCB-029/config/`.

### Decision this ticket feeds

* Retiming **sufficient** → file a small `GCB-###` to set the retiming line in
  the shared ORFS flow config (or the per-block config), and mark GCB-028's
  `REG_STAGES=2` physically validated.
* Retiming **insufficient** → open the mid-tree pipelined `gcb_max_reduce` RTL
  variant ticket, referencing this ticket's measured ceiling.

### Toolchain

RTL Baseline pin unchanged; P&R environment per [[TKT-000]].

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution — expected grade: `orange`, per [[TKT-000]].)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
