# GCB-032 — FINDINGS: does the GCB-031 mid-tree RTL pipeline close 1 ns without synthesis retiming?

**EPIC TKT-018 (Measurement Epoch) · Story 4 · per [[TKT-000]]**
Physical Design Engineer + Orange Team Auditor · 2026-09-10 ·
session `01Rpa9VJGe7xypzp5FkukSco`

**Yes. WNS = 0.00 ps, 0 setup violations, fmax 1.519 GHz — and at roughly HALF
the cost of GCB-030's synthesis retiming: 372 flops (vs 818), −29 % synth area,
−23 % power, −20 % wirelength, index cone left intact. 38 max-slew DRVs remain
(vs retiming's 57), the one axis where the prediction of "0" was falsified.**

The [[GCB-031]] mid-tree `gcb_max_reduce` (`REG_STAGES = 2` → two register banks
*between* tournament levels 2 and 4) through the **exact [[GCB-029]] flow** —
same 1 ns SDC, same floorplan / place / route recipe, `REG_STAGES=2` via
`VERILOG_TOP_PARAMS`, **`SYNTH_RETIME_MODULES` unset** — netlist = `sv2v` of the
GCB-031 `rtl/gcb_max_reduce.sv` (`gcb-wdm-transceiver` `642251c`). Structured
data: `gcb-workspaces/eda/GCB-032/report.json`.

## The transfer function — GCB-029 → GCB-030 → GCB-032

| metric | GCB-029 (output pipe, no RT) | GCB-030 (synthesis retiming) | **GCB-032 (GCB-031 mid-tree RTL)** | GCB-032 vs GCB-030 |
|---|---:|---:|---:|---:|
| **WNS @ 1 ns** | **−442.09 ps** | **0.00 ps** | **0.00 ps** | **MET** |
| **TNS** | −9 570.50 ps | 0.00 ps | **0.00 ps** | met |
| setup-violating paths | 22 | 0 | **0** | 0 |
| worst setup slack | −442.09 ps | +31.24 ps | **+90.27 ps** | +59 ps |
| reg→reg core_clock worst slack | — | — | **+341.47 ps** | — |
| **fmax** | — | — | **1.519 GHz** (~658 ps) | — |
| **Flop count** (`DFFASRHQNx1`) | 46 | **818** | **372** | **−446 (−54.5 %)** |
| Synth cell area | 621.41 µm² | 1 012.83 µm² | **714.78 µm²** | **−298 µm² (−29.4 %)** |
| — sequential fraction | 2.81 % | 30.62 % | **19.73 %** | −10.9 pts |
| Synth cell count | 6 230 | 8 208 | **6 313** | −1 895 |
| `HAxp5` (argmax cone) | 1 008 | 827 | **1 008** | +181 — **cone intact** |
| Post-route stdcell area | 884 µm² @ 57 % | 1 137 µm² @ 45 % | **810 µm² @ 45.9 %** | **−327 µm² (−28.7 %)** |
| **max-slew DRVs** | 0 | **57** | **38** | **−19 (−33 %)** |
| max-fanout / max-cap / hold DRVs | 0 / 0 / 0 | 0 / 0 / 0 | **0 / 0 / 0** | — |
| **Total power** | 17.8 mW | 12.2 mW | **9.37 mW** | **−2.83 mW (−23.2 %)** |
| — comb / seq / clock | — | — | 7.59 / 1.35 / 0.43 mW | — |
| Routed wirelength | 24 927 µm | 29 069 µm | **23 208 µm** | **−20.2 %** |
| Vias | 83 025 | 84 232 | **63 916** | −24 % |
| **Detailed-route DRC** | 0 | 0 | **0** | 0 |
| Antenna (net / pin) | 0 / 0 | 0 / 0 | **0 / 0** | 0 |
| CTS | 46 sinks | 818 sinks, depth 2 | **372 sinks**, 27 clk-buf + 13 clk-inv, skew 6.73 ps | −446 |

## Does the WNS meet the 1.0 ns target? — **YES, explicitly.**

`report_wns` = **0.00 ps**, `report_tns` = **0.00 ps**, `setup_violation_count`
= **0**, `hold_violation_count` = **0**, `fmax` = **1.519 GHz**. Every setup path
is MET.

## Analysis

### Is the ~1.67 ns combinational cone broken? — **Yes, by the RTL, not by ABC.**

The three tightest paths after route are all **segments**, none the
`input → max_val` cone GCB-027 (−665 ps) / GCB-029 (−442 ps) measured:

* `g_reg_out.bnk_val[bank2][*] → max_val[1]` output — **+90.27 ps** (last
  segment, tree levels 4-5, through the I/O output delay). The tightest path.
* `vec_flat[54] → g_reg_out.bnk_val[bank0][*]` — **+262.15 ps** (segment 0,
  tree levels 0-1, through the I/O input delay).
* reg→reg through a mid-segment — **+341.47 ps**.

`mr_cut_lvl` floor-distributes the two cuts over `LEVELS = 6` (`nseg = 3`) →
banks after levels 2 and 4, so the cone is three ~2-level segments. Each closes
1 ns with margin; the binding constraint is the **I/O boundary** segment
(+90 ps), not any internal segment (+341 ps) — expected, since `clk_io_pct =
0.20` charges 200 ps at each port.

### GCB-030 (retiming) vs GCB-032 (RTL) — the mid-tree pipeline wins on every PPA axis

* **Flops: 372 vs 818 (−54.5 %).** Retiming *replicates* a register once per
  fan-out branch when it pushes the output pipe back through the 64-wide tree
  (46 → 818). The RTL banks are placed once, at the narrow points: bank 1 after
  level 2 latches 16 partial winners, bank 2 after level 4 latches 4. The
  [[GCB-031]] Yosys 0.68 bless predicted ~440 flop *bits* / 42 `$adff`; ABC on
  the ASAP7 path maps that to **372** physical `DFFASRHQN`. No replication.
* **Synth area 715 vs 1 013 µm² (−29 %)**, sequential fraction **19.7 % vs
  30.6 %**, post-route **810 vs 1 137 µm² (−29 %)**.
* **Power 9.37 vs 12.2 mW (−23 %)**, and −47 % vs GCB-029's 17.8 mW — shorter
  combinational segments glitch far less (comb power 7.6 mW) and there is no
  818-sink clock tree to drive (clock power 0.43 mW vs GCB-030's ~1.1 mW).
* **Wirelength −20 %, vias −24 %.**
* **The argmax cone is untouched:** `HAxp5` = **1 008**, *identical* to
  GCB-029. Retiming re-optimised it to 827 — i.e. retiming reshaped the
  datapath; the mid-tree cut only inserts registers between existing levels.
* **Combinational cell count 6 313 ≈ GCB-029's 6 230** (vs retiming's 8 208):
  same tournament, sliced.

### Where the GCB-031 prediction is FALSIFIED — max-slew DRVs

GCB-031's Orange Target predicted **0 max-slew DRVs**. **38 remain** (GCB-030
had 57; GCB-027/029 had 0). They are the **bank-1 fan-out**: the level-2 fold
feeds 16 partial-winner registers × (16 value + 6 index) ≈ **352 data nets**,
and those high-fanout nets exceed what the **default (`SKIP_LAST_GASP = 1`,
no-last-gasp) recipe** buffer-repairs. This is a *structural* trait of any
register bank sitting on a wide partial-winner set — not replication (there is
none), and fewer than retiming's 57 (no duplicated async-reset fan-out). It is
**not** a routing or DRC problem: detailed-route DRC converged 1199 → 124 → 86 →
**0**, antenna 0 / 0. It is a signoff item the "deliberately ugly" recipe leaves
on the table — a `SKIP_LAST_GASP = 0` slew-repair pass would clear it.

## Orange Team verdict

* **The GCB-031 architectural claim is physically validated.** Mid-tree RTL
  cuts close `gcb_max_reduce` at 1 GHz **without synthesis retiming** — WNS
  0.00 ps, 0 setup violations, cone broken into port / reg→reg segments.
* **And they are the cheap way to do it.** Half retiming's flops, −29 % area,
  −23 % power, −20 % wire, with the argmax cone left intact. GCB-030 proved
  retiming *can* close it; GCB-032 proves the RTL *should*.
* **One honest caveat:** 38 max-slew DRVs (predicted 0). A shared trait of a
  wide mid-tree bank, clearable with a slew-repair pass that this recipe skips.

### Architecture-from-measurement — next `GCB-###`

1. **Retire `SYNTH_RETIME_MODULES` for `gcb_max_reduce`.** Push `REG_STAGES = 2`
   + the mid-tree config into the shared ORFS flow config; update
   `gcb-wdm-transceiver/docs/PPA_burndown.md` and [[GCB-030-FINDINGS]] with the
   GCB-032 numbers.
2. **Measure a `SKIP_LAST_GASP = 0` slew-repair pass** on this exact design and
   confirm the 38 max-slew DRVs clear, at whatever small area / power cost the
   repair buffers add.
3. `OUTPUT = "VALUE"` where the argmax is unused — drop the 1 008-`HAxp5` index
   cone. Orthogonal; still its own ticket.

## Task 4 — RTL Baseline drift tripwire (post-P&R) — **PASS**

| check | result |
|---|---|
| `bash sim/lint.sh` | **exit 0**, 32 tops |
| `toolchain_manifest.json` diff | **empty** (at committed `642251c` state) |
| tool versions | Verilator 5.032 · sv2v 0.0.12 · Yosys 0.68 (38e001a6f) · node v22.22.1 · venv Python 3.12.14 · cocotb 1.9.2 · numpy 2.5.3 — all match manifest pins |
| cocotb — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0 SKIP=3`, **`cov_violation=1`** on `partial_load_read_unwritten_hardfails` |

Same isolation as GCB-027/029/030: ORFS `--local`, OpenROAD + bundled Yosys
0.68 + ASAP7 only; no package manager against the RTL Baseline guest or
`~/.venvs/cocotb19`; only the read-only `kepler-formal` `LD_LIBRARY_PATH` → uv
CPython 3.12.14 shim (installs nothing). The [[TKT-000]] toolchain split held.

## Reproduce

```
# gcb_max_reduce.sv = GCB-031 mid-tree (gcb-wdm-transceiver 642251c).
sv2v gcb-wdm-transceiver/rtl/gcb_max_reduce.sv > \
  $O/flow/designs/src/gcb_max_reduce/gcb_max_reduce.v
# config: gcb-workspaces/eda/GCB-032/config/config.mk  (= GCB-029's, i.e. NO
#   SYNTH_RETIME_MODULES line; REG_STAGES 2 via VERILOG_TOP_PARAMS)
cd ~/eda/OpenROAD-flow-scripts/flow && source ../env.sh
export LD_LIBRARY_PATH=~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib:$LD_LIBRARY_PATH
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk           # serial - the
#   -j 2 cold-race on 2_1_floorplan.sdc still bites; -j 1 respects the -j 2 ceiling
```
