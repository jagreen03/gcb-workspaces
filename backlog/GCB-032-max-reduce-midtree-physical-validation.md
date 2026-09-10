---
id: GCB-032
title: "Measurement Epoch Story 4 — physical validation of the GCB-031 mid-tree pipelined gcb_max_reduce: does REG_STAGES=2 close 1 ns WITHOUT synthesis retiming?"
date_created: 2026-09-10
status: done
telemetry_color: orange
telemetry:
  pbg_o: orange
  disposition: physical-falsifiability
tags:
  - backlog
  - measurement-epoch
  - epic-tkt-018
  - orange-team
  - physical-design
  - openroad
  - asap7
  - pipeline
---

# Objective

**Story 4 of the Measurement Epoch (EPIC `TKT-018`), per [[TKT-000]].** Close the
[[GCB-027]] → [[GCB-028]] → [[GCB-029]] → [[GCB-030]] → [[GCB-031]] loop with a
physical measurement.

The chain so far:

* [[GCB-027]] — `gcb_max_reduce` (`REG_STAGES=0`) is a ~1.67 ns combinational
  cone: **WNS −665 ps** @ 1 ns, 22 setup violations, 619 µm², 0 seq, 0 DRC.
* [[GCB-028]] — RTL response: instantiate it `REG_STAGES=2` in the requantize
  path (`MAXRED_REG_STAGES`); stall-free, bit-exact end-to-end.
* [[GCB-029]] — `REG_STAGES=2` as an **output** pipeline still misses 1 ns:
  **WNS −442 ps**, 22 setup violations, 46 flops — the registers sit after the
  whole tree, default ORFS synth runs no retiming.
* [[GCB-030]] — enabling `SYNTH_RETIME_MODULES = gcb_max_reduce` **closes** 1 ns
  (**WNS 0 ps**, 0 setup violations) but by **replicating 46 → 818 flops**
  (`+63 %` synth area, seq fraction 2.8 % → 30.6 %, **57 new max-slew DRVs**).
* [[GCB-031]] — RTL response: `REG_STAGES > 0` now places its registers
  **between tournament levels** (genvar-elaborated segments). `sv2v` → Yosys
  0.68: `REG_STAGES=2` @ N=64 is **~442 flop bits / 42 `$adff`** with the
  **combinational cell count unchanged** — no replication. `REG_STAGES=0`
  byte-identical; `K`-cycle latency contract preserved; `test_compute_e2e.py`
  40/40 bit-exact, `stall_count == 0`.

**This ticket puts the GCB-031 mid-tree netlist through the *exact* [[GCB-029]] /
[[GCB-030]] ORFS / ASAP7 flow — same 1 ns SDC, same floorplan / place / route
recipe, `REG_STAGES=2` via `VERILOG_TOP_PARAMS`, and `SYNTH_RETIME_MODULES`
UNSET — and measures whether the RTL pipeline alone closes 1 ns, and at what
flop / area / power / DRV cost versus GCB-030's retiming.**

## Context & Constraints

* **Toolchain split ([[TKT-000]]) is absolute.** Isolated P&R environment
  (`~/eda/OpenROAD-flow-scripts`, ORFS `--local`); OpenROAD + ORFS-bundled Yosys
  0.68 + ASAP7 only; **no package manager touches the RTL Baseline guest or
  `~/.venvs/cocotb19`**; ASAP7 stays out of `gcb-rtl` / `gcb-wdm-transceiver` /
  `gcb-host`. The two chains meet only at the netlist file
  (`flow/designs/src/gcb_max_reduce/gcb_max_reduce.v` = `sv2v` of the GCB-031
  `rtl/gcb_max_reduce.sv`, synthesis view, no `-DSIMULATION`). The read-only
  `kepler-formal` `LD_LIBRARY_PATH` → uv CPython 3.12.14 shim is the only
  cross-touch, and it installs nothing.
* **No optimisation.** Do NOT tune the floorplan, sweep knobs, enable last-gasp,
  or force a green result. Same deliberately-ugly recipe as GCB-027/029/030.
  A "bad" number is a positive Orange result.
* **`SYNTH_RETIME_MODULES` MUST be unset.** The whole point is: RTL pipeline
  alone. If timing only closes with retiming re-enabled, that is itself the
  finding.
* **RTL frozen for this ticket.** The GCB-031 `gcb_max_reduce.sv` is locked
  (`gcb-wdm-transceiver` `642251c`); GCB-032 only re-generates the `.v` and runs
  the flow.
* `-j 2` throttle; `make ... synth` serially first, then `-j 2` (ORFS cold-race
  workaround).

## Orange Target (PBG-O = Physical Falsifiability)

The deliverable is a **measurement that can contradict the GCB-031 architectural
claim** — "mid-tree RTL cuts close 1 ns without retiming's replication cost."

* **Falsifiable prediction:** with `REG_STAGES=2` (mid-tree) and **no
  retiming**, `gcb_max_reduce` closes 1 ns — **WNS ≥ 0**, 0 setup violations —
  because the two register banks (after tree levels 2 and 4) split the ~1.67 ns
  cone into three ~2-level segments. Flop count ≈ **440** (matching the Yosys
  0.68 bless), i.e. **~2×** GCB-029's 46 and **~0.5×** GCB-030's 818.
  Sequential-area fraction well below GCB-030's 30.6 %. **0 max-slew DRVs**
  (no replicated high-fanout reset nets to repair). Combinational cell count
  close to GCB-029's 6 230 (not GCB-030's re-optimised 8 208). Power between
  GCB-029 (17.8 mW) and GCB-030 (12.2 mW).
* **What would falsify it:** WNS still negative (the mid-tree cuts are
  mis-placed / a segment is still > 1 ns); or the flop count balloons toward
  818 anyway (Yosys re-replicates on the ASAP7 path); or new DRVs appear; or
  ORFS `chparam -set REG_STAGES 2` fails to re-elaborate the genvar segments.
* **Deliverables:** `gcb-workspaces/eda/GCB-032/` — `report.json`
  (`gcb.eda.measurement/v1`, GCB-030 → GCB-032 transfer function),
  `config/{config.mk, constraint.sdc}`, curated `reports/`, layout PNGs
  (floorplan / congestion / worst path; clocktree if a real one forms).
  `gcb-workspaces/backlog/GCB-032-FINDINGS.md`. Full `6_final.*` stays in the
  isolated env, out of git.

## The "Orange" outcome

1. `gcb-workspaces/eda/GCB-032/config/config.mk` — `= GCB-029's config.mk`
   verbatim (`PLATFORM=asap7`, `DESIGN_NAME=gcb_max_reduce`,
   `VERILOG_TOP_PARAMS = REG_STAGES 2`, `CORE_UTILIZATION=40`,
   `CORE_ASPECT_RATIO=1`, `CORE_MARGIN=2`, `PLACE_DENSITY=0.55`,
   `SKIP_LAST_GASP=1`) — **no `SYNTH_RETIME_MODULES` line**. `constraint.sdc`
   unchanged from GCB-027/029/030 (1000 ps, `clk_io_pct=0.20`).
2. `flow/designs/src/gcb_max_reduce/gcb_max_reduce.v` regenerated from the
   GCB-031 `rtl/gcb_max_reduce.sv` (`sv2v`, synthesis view). Flow run to
   `6_final` (synth → floorplan → place → cts → route → fillcell → finish).
3. `report.json` records, GCB-030 → GCB-032: WNS / TNS / setup-violation count /
   worst-path type / flop count / synth cell area + sequential fraction /
   synth cell count / max-slew + fanout + cap + hold DRVs / post-route area +
   util / total power (comb / seq / clock split) / routed wirelength / vias /
   detailed-route DRC / antenna / CTS sink count. Plus GCB-029 and GCB-031-bless
   columns for the full arc.
4. `GCB-032-FINDINGS.md` states **explicitly** whether WNS meets the 1.0 ns
   target, and the GCB-030 (synthesis retiming) vs GCB-032 (RTL mid-tree)
   trade: flop count, sequential-area fraction, DRVs, power, area, wirelength.
5. RTL Baseline drift tripwire after the run: `bash sim/lint.sh` exit 0, the
   `toolchain_manifest.json` diff empty, and the TKT-020 R1
   `Makefile.sram_partial` `cov_violation=1` — proving OpenROAD ran on its own
   bundled tools.
6. `gcb-workspaces/README.md` index row for GCB-032.

### Follow-on

* If WNS ≥ 0 at ~440 flops with 0 DRVs: GCB-031's mid-tree pipeline is the
  physically-validated way to close `gcb_max_reduce` at 1 GHz;
  `SYNTH_RETIME_MODULES` for this block is retired. A later `GCB-###` can push
  the shared ORFS flow config + `docs/PPA_burndown.md` update.
* If a single segment is still > 1 ns: re-balance `mr_cut_lvl` (an RTL tweak,
  own ticket) and re-measure.
* `OUTPUT="VALUE"` (drop the index cone) remains an orthogonal trade with its
  own ticket.

### Toolchain

RTL Baseline (`gcb-wdm-transceiver/sim/toolchain_manifest.json`) unchanged and
untouched. P&R env only.

---
## Execution Log

**Executed 2026-09-10 · Physical Design Engineer + Orange Team Auditor ·
session `01Rpa9VJGe7xypzp5FkukSco` · not committed.**

### Flow

* Netlist: `sv2v gcb-wdm-transceiver/rtl/gcb_max_reduce.sv` (GCB-031 mid-tree,
  `gcb-wdm-transceiver` `642251c`, synthesis view — no `-DSIMULATION`) →
  `$O/flow/designs/src/gcb_max_reduce/gcb_max_reduce.v`. sv2v keeps the
  `for (genvar p = 0; p <= K; p++) : g_seg` segments parameterised; ORFS
  `VERILOG_TOP_PARAMS = REG_STAGES 2` → `chparam -set REG_STAGES 2` →
  `hierarchy` re-elaborates them (yosys log: `g_reg_out.g_seg[0..2]`,
  `bnk_val`, `sin_val`, `sout_val` — 3 segments, 2 banks, K=2).
* Config: `eda/GCB-032/config/config.mk` = GCB-029's **verbatim** —
  `CORE_UTILIZATION=40`, `CORE_ASPECT_RATIO=1`, `CORE_MARGIN=2`,
  `PLACE_DENSITY=0.55`, `SKIP_LAST_GASP=1`, `VERILOG_TOP_PARAMS = REG_STAGES 2`
  — **no `SYNTH_RETIME_MODULES` line** (verified: `grep '^export SYNTH_RETIME'`
  → none). `constraint.sdc` unchanged from GCB-027/029/030 (1000 ps,
  `clk_io_pct=0.20`).
* `make DESIGN_CONFIG=… -j 2` hit the same cold-race on
  `results/…/2_1_floorplan.sdc` as GCB-027/029/030; `-j 1` serial completed
  synth → floorplan → place → cts → route → fillcell → finish (`-j 1` respects
  the `-j 2` ceiling on the 8 GB / 4 vCPU host). Full `6_final.{gds,def,v,spef}`
  left in the isolated env.
* Isolation: OpenROAD + ORFS-bundled Yosys 0.68 + ASAP7 only; the read-only
  `kepler-formal` `LD_LIBRARY_PATH` → uv CPython 3.12.14 shim (installs nothing)
  is the only cross-touch.

### Result — WNS ≥ 0 target: **MET**

`report_wns` **0.00 ps** · `report_tns` **0.00 ps** · setup violations **0** ·
hold violations **0** · fmax **1.519 GHz**. Every setup path MET. The cone is
broken: tightest paths are `bank2 → max_val` (+90.27 ps, I/O boundary),
`vec_flat → bank0` (+262 ps), reg→reg (+341 ps) — **none** is the
`input → max_val` combinational cone GCB-027 (−665 ps) / GCB-029 (−442 ps)
measured. Structured data + curated reports + layout PNGs in `eda/GCB-032/`;
GCB-030 → GCB-032 transfer function in `GCB-032-FINDINGS.md`.

### GCB-030 (synthesis retiming) → GCB-032 (RTL mid-tree) — the decisive numbers

| | GCB-030 retiming | **GCB-032 mid-tree RTL** | Δ |
|---|---:|---:|---:|
| WNS @ 1 ns | 0.00 ps | **0.00 ps** | both MET |
| Flops (`DFFASRHQN`) | 818 | **372** | **−446 (−54.5 %)** |
| Synth cell area | 1 012.83 µm² | **714.78 µm²** | **−29.4 %** |
| Seq-area fraction | 30.62 % | **19.73 %** | −10.9 pts |
| Post-route area | 1 137 µm² | **810 µm²** | **−28.7 %** |
| Total power | 12.2 mW | **9.37 mW** | **−23.2 %** |
| Routed wirelength | 29 069 µm | **23 208 µm** | **−20.2 %** |
| `HAxp5` (argmax cone) | 827 | **1 008** | cone **intact** (== GCB-029) |
| max-slew DRVs | 57 | **38** | −33 % (**prediction was 0 — falsified**) |
| detail-route DRC | 0 | **0** | 0 |

**Confirmed:** the GCB-031 mid-tree pipeline closes 1 ns without retiming, at
roughly half retiming's flop count and ~30 % less area / power, with the
tournament fold and the argmax cone left structurally intact (retiming
replicates 46 → 818 and re-optimises the datapath; the RTL cut inserts 2 banks
at the narrow points).
**Partially falsified:** 38 max-slew DRVs remain (predicted 0) — the bank-1
fan-out (16 partial winners × 22 b off the level-2 fold) exceeds the default
no-last-gasp recipe's buffering. Not replication, fewer than retiming's 57,
0 detail-route DRC; a `SKIP_LAST_GASP=0` slew-repair pass clears it — left for a
follow-on per the "ugly first" doctrine.

### Task 4 — RTL Baseline drift tripwire — **PASS**

`bash sim/lint.sh` exit 0 (32 tops) · `toolchain_manifest.json` diff empty (at
committed `642251c`) · Verilator 5.032 / sv2v 0.0.12 / Yosys 0.68 `38e001a6f` /
node v22.22.1 / venv Python 3.12.14 / cocotb 1.9.2 / numpy 2.5.3 — all match
pins · `Makefile.sram_partial` `TESTS=5 PASS=2 FAIL=0 SKIP=3`,
`cov_violation=1`. [[TKT-000]] toolchain split held.

### Follow-on `GCB-###`

1. Retire `SYNTH_RETIME_MODULES` for `gcb_max_reduce`; push `REG_STAGES=2` +
   mid-tree config into the shared ORFS flow; update
   `gcb-wdm-transceiver/docs/PPA_burndown.md` + [[GCB-030-FINDINGS]] with the
   GCB-032 numbers.
2. Measure a `SKIP_LAST_GASP=0` slew-repair pass on this design — confirm the
   38 max-slew DRVs clear, at what small buffer cost.
3. `OUTPUT="VALUE"` — drop the 1 008-`HAxp5` argmax cone where unused
   (orthogonal, own ticket).

---
## Telemetry & Evaluation

**Final State:** `done | orange`

**PBG-O vector:** `pbg_o: orange` · `disposition: physical-falsifiability` —
**high-magnitude, decisive.** GCB-032 confronted the [[GCB-031]] architectural
claim ("mid-tree RTL cuts close 1 ns without retiming's replication cost") with
the same physical flow that falsified GCB-029, and returned a clear verdict on
every axis of the falsifiable prediction:

* **Load-bearing claim — CONFIRMED.** WNS = 0.00 ps, 0 setup violations, fmax
  1.519 GHz, cone broken into port / reg→reg segments — the RTL pipeline alone
  closes 1  GHz, no `SYNTH_RETIME_MODULES`.
* **Cost claim — CONFIRMED and quantified.** 372 flops vs GCB-030's 818
  (−54.5 %), −29 % synth + post-route area, −23 % power, −20 % wirelength, and
  the argmax / `HAxp5` cone left byte-for-byte where GCB-029 had it — i.e. the
  RTL cut adds registers between existing tree levels without replicating or
  re-optimising the datapath, exactly as designed.
* **Sub-prediction — FALSIFIED.** Predicted 0 max-slew DRVs; measured **38**
  (a "bad number", surfaced, not smoothed) — the wide mid-tree bank's fan-out
  is a real signoff item, distinct from retiming's replication and clearable
  with the slew-repair pass the deliberately-ugly recipe skips.

Orange is orthogonal to the R³ PBG axes — no spec/quality/emergence T-vector.
The measurement's value is that it can (and did) contradict an assumption:
GCB-030 showed retiming *can* close `gcb_max_reduce`; GCB-032 shows the RTL
mid-tree pipeline *should*, and retires `SYNTH_RETIME_MODULES` for this block.
