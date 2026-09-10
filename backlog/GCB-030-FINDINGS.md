# GCB-030 — FINDINGS: does synthesis retiming break the `gcb_max_reduce` cone?

**EPIC TKT-018 (Measurement Epoch) · Story 3 · per [[TKT-000]]**
Physical Design Engineer + Orange Team Auditor · 2026-09-10 ·
session `01Rpa9VJGe7xypzp5FkukSco`

**Yes — retiming closes 1 ns. But it does it by replicating the 46 pipeline
flops 17.8× to 818, at +63 % cell area and 57 new max-slew DRVs.**

`gcb_max_reduce` with `REG_STAGES = 2` through the **exact same** ORFS / ASAP7
flow as [[GCB-029]] — same `sv2v` netlist, same 1 ns SDC, same floorplan /
place / route recipe — with **one config line added**:

```
export SYNTH_RETIME_MODULES = gcb_max_reduce
```

which makes ORFS `synth.tcl` run
`select gcb_max_reduce; opt -fast -full; memory_map; opt -full; techmap;
abc -dff -script scripts/abc_retime.script` — i.e. ABC min-delay `retime -M 5`
(four passes) then map. `gcb_max_reduce.sv` frozen. Structured delta table:
`gcb-workspaces/eda/GCB-030/report.json`.

## The transfer function — GCB-029 (`REG_STAGES=2`, no retiming) → GCB-030 (retiming ON)

| metric | GCB-029 | GCB-030 | Δ |
|---|---:|---:|---:|
| **WNS @ 1 ns** | **−442.09 ps** | **0.00 ps** | **+442 ps → CLOSED** |
| **TNS** | −9 570.50 ps | **0.00 ps** | closed |
| setup-violating paths | 22 | **0** | −22 |
| worst-path slack | −442 ps | **+31.24 ps** (reg→reg tree segment) | MET |
| **max-slew DRVs** | 0 | **57** | **+57 (new)** |
| max-fanout / max-cap / hold | 0 / 0 / 0 | 0 / 0 / 0 | — |
| **Flop count** (`DFFASRHQNx1`) | 46 | **818** | **× 17.8** |
| Synth cell area | 621.41 µm² | **1 012.83 µm²** | **+391 µm² (+63.0 %)** |
| — sequential fraction | 17.44 µm² (2.81 %) | **310.09 µm² (30.62 %)** | +292 µm² |
| Total cell count | 6 230 | 8 208 | +1 978 |
| `HAxp5` half-adders | 1 008 | 827 | −181 |
| Post-route area | 884 µm² @ 57 % | 1 137 µm² @ 45 % | +253 µm² |
| **Total power** | 17.8 mW | **12.2 mW** | **−5.6 mW (−31.5 %)** |
| Routed wirelength | 24 927 µm | 29 069 µm | +16.6 % |
| Vias | 83 025 | 84 232 | +1 207 |
| **DRC** (detailed route) | 0 | **0** | 0 |
| Antenna net / pin | 0 / 0 | 0 / 0 | 0 |
| Clock tree (CTS) | 46 sinks, minimal | **818 sinks, depth 2, 41 clusters** | a real clock tree now |

## Analysis

### Did retiming break the ~1.44 ns combinational cone? — **Yes.**

* **WNS 0.00 ps, TNS 0.00 ps, 0 setup-violating paths.** The worst path is no
  longer `input → max_val` combinational — it is now **register → register
  through a *segment* of the tournament tree** (`_09012_ → out_valid$_DFF_PN0_`,
  +31.24 ps slack). ABC's `retime` pushed the two output pipeline stages
  **up into the tree levels**, splitting the ~1.67 ns cone into ≤ 1 ns pieces.
* This is exactly the behaviour the TKT-016 comment promised ("synthesis
  retiming distributes the registers into the tree") — it just isn't on by
  default, which is what [[GCB-029]] measured and falsified. **With retiming on,
  `REG_STAGES = 2` is sufficient to close 1 ns.**

### Were the async-reset flops a barrier? — **No.**

All 818 result flops are `DFFASRHQNx1` (async set/reset). ABC `retime -dff`
moved right through them — the reset is consistent, so retiming replicates the
reset fan-out along with the register. Not a barrier; a **multiplier**.

### Did the flop count change? — **Massively: 46 → 818 (× 17.8).**

Register retiming, moving a flop **backward** through a fan-out node,
**replicates** it once per fan-out branch. The two output pipe registers sit
downstream of the *entire* 64-wide tournament tree, so pushing them up one level
duplicates them across the tree width; several levels in, 46 → 818. This is the
**cost** of getting timing closure from retiming instead of from the RTL:
`+391 µm²` cell area (**+63 %**), sequential area from **2.8 % → 30.6 %** of the
chip, `+17 %` wirelength, a full 818-sink clock tree where there was none.

### New DRVs

**57 max-slew (max-transition) violations** — zero in GCB-027/029. The 818-flop
explosion drives high-fanout data / reset nets that the **default (no
last-gasp) recipe** does not buffer-repair. Not a routing or DRC problem
(detailed route DRC still 0), but a signoff item the "deliberately ugly" recipe
leaves on the table.

### Power went *down*

**−31 % vs GCB-029, −45 % vs GCB-027.** Combinational power 17.4 → 8.6 mW:
shorter combinational segments between registers glitch far less. The 818 flops
+ their clock tree add 2.44 mW sequential + 1.12 mW clock, but the glitch saving
dominates.

## Orange Team verdict

* **Retiming works** — it re-validates the assumption [[GCB-029]] falsified:
  `REG_STAGES = 2` *does* close 1 ns for `gcb_max_reduce`, **once retiming is
  enabled**. The cone is broken; the RTL response ([[GCB-028]]) is physically
  sufficient.
* **But the cost is steep** for a shared 3-site primitive: 818 flops, +63 %
  area, 30 % sequential-area fraction, 57 slew DRVs. Retiming got the *result*
  by *replication*, which is a strong signal that **the pipeline should be
  expressed in the RTL** (registers placed *between* tournament levels by
  design → 2 stages ≈ 2 × WIDTH flops, timing closes with no replication), not
  synthesised.

### Architecture-from-measurement — next `GCB-###`

1. **Preferred: a mid-tree pipelined `gcb_max_reduce` RTL variant.**
   Re-interpret `REG_STAGES` as a *tree-cut* count: insert a register bank
   between tournament levels `⌊LEVELS·k/(REG_STAGES+1)⌋`. `REG_STAGES = 2`
   → ~2 × (WIDTH + IDX_W) flops (~44), not 818, and timing closes **without**
   retiming. RTL ticket; then re-run this exact flow (no `SYNTH_RETIME_MODULES`)
   and expect `WNS ≥ 0` at ~44 flops.
2. **Alternative: accept retiming + a slew-repair pass.** Set
   `SYNTH_RETIME_MODULES` in the *shared* ORFS flow config, enable the slew
   repair the default skips (`SKIP_LAST_GASP = 0`), and re-measure the DRV /
   area. Cheaper to ship, but leaves the 818-flop / +63 %-area cost per
   instantiation.
3. `OUTPUT = "VALUE"` where the argmax is unused (drop the ~827-`HAxp5` index
   cone) — orthogonal, still worth measuring.

The functional side is unaffected — [[GCB-028]] already proved the compute
dataflow is stall-free and bit-exact at any `MAXRED_REG_STAGES`; this ticket
only measures the physical cost of the two ways to make the timing close.

## Task 4 — RTL Baseline drift tripwire (post-P&R) — **PASS**

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** (Verilator 5.032 / sv2v 0.0.12 / Yosys 0.68 / node v22.22.1 / venv Python 3.12.14 / cocotb 1.9.2 / numpy 2.5.3) |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`** |

Same isolation as GCB-027/029; only cross-touch the read-only `kepler-formal`
`LD_LIBRARY_PATH` shim. The [[TKT-000]] toolchain split held.

## Reproduce

```
# gcb_max_reduce.sv frozen; same sv2v netlist as GCB-027/029.
# config: gcb-workspaces/eda/GCB-030/config/config.mk  (= GCB-029's + one line:
#   export SYNTH_RETIME_MODULES = gcb_max_reduce)
cd ~/eda/OpenROAD-flow-scripts/flow && source ../env.sh
export LD_LIBRARY_PATH=~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib:$LD_LIBRARY_PATH
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk synth      # serial first
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk -j 2       # to finish
```
