# `eda/gcb_max_reduce/` — standing ORFS / ASAP7 config

The canonical, measurement-ticket-independent OpenROAD-flow-scripts design
config for the shared `gcb_max_reduce` primitive (`gcb-wiki` TKT-016). Promoted
by **GCB-033** from the [[GCB-032]] validating run.

| file | purpose |
|---|---|
| `config.mk` | ORFS `DESIGN_CONFIG` — `asap7`, 1000 ps target, `REG_STAGES 2` via `VERILOG_TOP_PARAMS`, **no `SYNTH_RETIME_MODULES`**, deliberately-ugly recipe (no knob tuning) |
| `constraint.sdc` | 1000 ps virtual-clock SDC, `clk_io_pct = 0.20` — unchanged across GCB-027 / GCB-029 / GCB-030 / GCB-032 |

## Closure path — RTL mid-tree pipeline, retiming retired

`gcb_max_reduce` at defaults (`REG_STAGES=0`) is a ~1.67 ns combinational
tournament cone — **timing-bound** at a 1 ns target ([[GCB-027]]: WNS −665 ps).
The investigation:

| step | result |
|---|---|
| [[GCB-029]] `REG_STAGES=2` as an *output* pipe, no retiming | WNS −442 ps — still open (registers after the whole tree) |
| [[GCB-030]] `SYNTH_RETIME_MODULES = gcb_max_reduce` | WNS 0 ps — **closes**, but replicates 46 → **818 flops** (+63 % area, 57 max-slew DRVs) |
| [[GCB-031]] RTL: `REG_STAGES>0` = register banks **between** tournament levels | Yosys 0.68: ~442 flop bits, combinational cells unchanged, `REG_STAGES=0` byte-identical, `K`-cycle latency preserved |
| **[[GCB-032]]** physical validation of GCB-031, `SYNTH_RETIME_MODULES` unset | **WNS 0.00 ps @ 1 ns, 0 setup violations, fmax 1.519 GHz, 0 DRC, 372 flops** — −54.5 % vs retiming, synth area −29 %, power −23 % |

**`SYNTH_RETIME_MODULES` for `gcb_max_reduce` is retired.** It closed timing but
by register replication; the RTL mid-tree pipeline closes it at roughly half the
flop count with the datapath and argmax cone left intact.

**Open item:** 38 max-slew DRVs remain (the wide mid-tree bank-1 fan-out —
16 partial winners × 22 b off the level-2 fold). Not a DRC/routing problem
(detailed-route DRC = 0); clearable with a `SKIP_LAST_GASP = 0` slew-repair
pass — a separate follow-on.

## Reproduce

```
# netlist: sv2v of the GCB-031 rtl/gcb_max_reduce.sv (gcb-wdm-transceiver 642251c)
sv2v gcb-wdm-transceiver/rtl/gcb_max_reduce.sv > \
  $O/flow/designs/src/gcb_max_reduce/gcb_max_reduce.v
cp eda/gcb_max_reduce/config.mk      $O/flow/designs/asap7/gcb_max_reduce/config.mk
cp eda/gcb_max_reduce/constraint.sdc $O/flow/designs/asap7/gcb_max_reduce/constraint.sdc
cd $O/flow && source ../env.sh
export LD_LIBRARY_PATH=~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib:$LD_LIBRARY_PATH
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk        # serial - the
#   -j 2 cold-race on 2_1_floorplan.sdc still bites; -j 1 respects the ceiling
```

Per-run curated artifacts (`report.json`, curated `reports/`, layout PNGs) live
under `eda/GCB-0NN/`; full `6_final.*` stays in the isolated P&R environment,
out of git, per [[TKT-000]].
