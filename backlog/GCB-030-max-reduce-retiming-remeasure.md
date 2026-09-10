---
id: GCB-030
title: "Story 3 of the Measurement Epic (TKT-018) — enable synthesis register retiming and re-measure gcb_max_reduce (REG_STAGES=2)"
date_created: 2026-09-10
status: done
telemetry_color: orange
telemetry:
  pbg_o: orange
  disposition: physical-falsifiability
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

### 2026-09-10 (session 01Rpa9VJGe7xypzp5FkukSco) — Physical Design Engineer + Orange Team Auditor

Full detail + machine delta table: **[[GCB-030-FINDINGS]]**,
`gcb-workspaces/eda/GCB-030/report.json`. Layout / clock-tree PNGs + curated
reports: `gcb-workspaces/eda/GCB-030/`.

* **Assessment — the retiming hook.** ORFS `flow/scripts/synth.tcl` gates
  register retiming on the env var **`SYNTH_RETIME_MODULES`** being set: it runs
  `select <modules>; opt -fast -full; memory_map; opt -full; techmap;
  abc -dff -script scripts/abc_retime.script`, where `abc_retime.script` is
  `st; retime -v -o; retime -M 5 -v -o` (×3); `map`. Least-invasive hook — one
  config line, no script edit. Set `export SYNTH_RETIME_MODULES = gcb_max_reduce`.
* **Setup.** Same `sv2v` netlist as GCB-029 (`gcb_max_reduce.sv` frozen), same
  `constraint.sdc` (1000 ps), same `VERILOG_TOP_PARAMS = REG_STAGES 2`, same
  floorplan / place / route knobs, default recipe. **Only config diff:** the
  `SYNTH_RETIME_MODULES` line. `make synth` serial then `make -j 2`;
  `kepler-formal` `LD_LIBRARY_PATH` shim re-used.
* **Flow completed** synth → floorplan → place → CTS → route → fillcell →
  **finish**. `6_final.gds` produced.

* **Transfer function — GCB-029 (`REG_STAGES=2`, no retiming) → GCB-030 (retiming ON):**

  | metric | GCB-029 | GCB-030 | Δ |
  |---|---:|---:|---:|
  | **WNS @ 1 ns** | −442.09 ps | **0.00 ps** | **+442 ps → CLOSED** |
  | **TNS** | −9 570.50 ps | **0.00 ps** | closed |
  | setup-violating paths | 22 | **0** | −22 |
  | **max-slew DRVs** | 0 | **57** | **+57 (new)** |
  | **flop count** (`DFFASRHQN`) | 46 | **818** | **× 17.8** |
  | synth cell area | 621.41 µm² | **1 012.83 µm²** | **+63.0 %** |
  | sequential-area fraction | 2.81 % | **30.62 %** | +27.8 pts |
  | total cells | 6 230 | 8 208 | +1 978 |
  | `HAxp5` | 1 008 | 827 | −181 |
  | post-route area | 884 µm² @ 57 % | 1 137 µm² @ 45 % | +253 µm² |
  | **total power** | 17.8 mW | **12.2 mW** | **−31.5 %** |
  | wirelength | 24 927 µm | 29 069 µm | +16.6 % |
  | DRC / antennas | 0 / 0 | **0 / 0** | unchanged |
  | CTS | 46 sinks, minimal | **818 sinks, depth-2 tree** | real clock tree |

* **Analysis.**
  * **The cone IS broken.** Worst path is now **reg → reg through a tree
    *segment*** (`_09012_ → out_valid$_DFF_PN0_`, +31.24 ps slack), not
    `input → max_val` combinational. ABC's `retime` pushed the two output pipe
    stages up into the tournament levels — exactly what the TKT-016 comment
    promised, just not on by default (which is what [[GCB-029]] falsified).
    **With retiming on, `REG_STAGES=2` is sufficient to close 1 ns.**
  * **Async-reset flops were NOT a barrier** — ABC retimed straight through the
    `DFFASRHQN` async set/reset flops; all 818 result flops are `DFFASRHQN`.
  * **Flop count exploded 46 → 818** — retiming *replicates* a register pushed
    backward through a fan-out node; the output pipe regs sit downstream of the
    entire 64-wide tree, so pushing them up duplicates them across the tree
    width. This is the **cost** of closing timing by synthesis instead of by
    RTL: +63 % area, 30 % sequential fraction, +17 % wirelength, a full 818-sink
    clock tree.
  * **57 new max-slew DRVs** — the 818-flop fan-out on data/reset nets, not
    buffer-repaired by the default (no-last-gasp) recipe. DRC still 0.
  * **Power dropped 31 %** — shorter combinational segments glitch far less
    (comb power 17.4 → 8.6 mW), outweighing the 818-flop tree cost.

* **Verdict.** Retiming re-validates the [[GCB-028]] response — `REG_STAGES=2`
  *does* close 1 ns with retiming enabled — **but at a register/area/DRV cost
  that says the pipeline should be in the RTL, not synthesised by replication.**

* **Next `GCB-###` (from [[GCB-030-FINDINGS]]):** (1) **preferred** — a mid-tree
  pipelined `gcb_max_reduce` RTL variant (`REG_STAGES` as tree-cut count →
  ~2·(WIDTH+IDX_W) ≈ 44 flops, closes without retiming); (2) alternative —
  set `SYNTH_RETIME_MODULES` in the shared flow config + a slew-repair pass
  (`SKIP_LAST_GASP=0`) and re-measure DRV/area; (3) `OUTPUT="VALUE"` where the
  argmax is unused.

### Task 4 — RTL Baseline drift tripwire (post-P&R) — **PASS**

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** (all 7 tools unchanged) |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`** |

ORFS on its own bundled Yosys/OpenROAD, no package manager; only cross-touch the
read-only `kepler-formal` `LD_LIBRARY_PATH` shim. The [[TKT-000]] split held.

### Artifacts touched

* `gcb-workspaces/eda/GCB-030/` (new) — `report.json`, `floorplan.png` +
  `congestion.png` + `worst_path.png` + `clocktree.png`,
  `config/{config.mk,constraint.sdc}`, `reports/`.
* `gcb-workspaces/backlog/GCB-030-FINDINGS.md` (new).
* **Nothing** in `gcb-rtl` / `gcb-wdm-transceiver`; `gcb_max_reduce.sv` frozen;
  no PDK material in any RTL repo. GCB-029's config preserved at
  `eda/GCB-029/config/`.

---
## Telemetry & Evaluation

**Final State:** `orange`

**Vector Summary:** `PBG-O = orange` (Physical Falsifiability) — **SATISFIED**.

* **The pass produced a clean before/after transfer function and answered the
  decisive question with a caveat.** Retiming **closes 1 ns** (`WNS −442 → 0`,
  22 → 0 setup violations, cone broken into reg→reg segments) — re-validating
  the [[GCB-028]] `REG_STAGES=2` response that [[GCB-029]] had falsified under
  the default recipe. **But** it does so by **replicating 46 flops → 818**
  (+63 % area, 30 % sequential fraction, 57 new slew DRVs). That measured cost
  is itself the finding: retiming is a valid path, and a mid-tree pipelined RTL
  variant is the cheaper one.
* R³ axes deliberately not optimized (timing closure was a *measurement
  outcome* here, not a pursued goal — one config line, everything else frozen).
  For the record: X ≈ 0, Y ≈ +0.5 (clean isolated measurement — one knob, same
  SDC/recipe, RTL frozen, tripwire green), Z = 0.
* **Valid Orange measurement:** config diff vs GCB-029 is a single line, the
  1 ns SDC was not relaxed, no floorplan/place/route knob moved, RTL frozen,
  tripwire clean.

Cyclopter scavenger (TKT-013) ingests this as the third `orange` child of
EPIC TKT-018. The primitive's loop is now:
`GCB-027 (baseline, −665 ps)` → `GCB-028 (RTL response, green)` →
`GCB-029 (validation: output-only pipe, still −442 ps)` →
`GCB-030 (retiming closes it, at 818 flops)` — measure → change → re-measure →
re-measure the fix.
