# GCB-029 — FINDINGS: physical validation of the GCB-028 pipeline response

**EPIC TKT-018 (Measurement Epoch) · Story 2 · per [[TKT-000]]**
Physical Design Engineer + Orange Team Auditor · 2026-09-10 ·
session `01Rpa9VJGe7xypzp5FkukSco`

`gcb_max_reduce` with **`REG_STAGES = 2`** (the [[GCB-028]] response) through the
**exact same** ORFS / ASAP7 flow as [[GCB-027]] — same `sv2v` netlist, same
`constraint.sdc` (1000 ps target, virtual-clock I/O), same floorplan knobs,
same default recipe, **zero tuning**. The only config diff:
`VERILOG_TOP_PARAMS = REG_STAGES 2` (ORFS `chparam -set REG_STAGES 2` before
synth). Structured data + a GCB-027-vs-GCB-029 machine table:
`gcb-workspaces/eda/GCB-029/report.json`. Full P&R outputs
(`6_final.{gds,def,v,spef}`, 11 MB GDS) left in the isolated P&R env.

## The transfer function — GCB-027 (`REG_STAGES=0`) → GCB-029 (`REG_STAGES=2`)

| metric | GCB-027 (combinational) | GCB-029 (`REG_STAGES=2`) | Δ |
|---|---:|---:|---:|
| **WNS @ 1 ns** | **−665.45 ps** | **−442.09 ps** | **+223.36 ps (+33.6 %)** |
| **TNS** | **−14 420.39 ps** | **−9 570.50 ps** | **+4 849.89 ps (+33.6 %)** |
| setup-violating paths | 22 | 22 | 0 |
| hold violations | 0 | 0 | 0 |
| Synth cell area | 618.75 µm² | 621.41 µm² | **+2.66 µm² (+0.43 %)** |
| Synth cell count | 6 240 | 6 230 | −10 |
| Sequential elements | 0.00 µm² (0 %) | **17.44 µm² (2.81 %)** — 46 × `DFFASRHQNx1` | +46 flops |
| Post-route design area | 901 µm² @ 59 % | 884 µm² @ 57 % | −17 µm² |
| **Total power** | 22.0 mW | **17.8 mW** | **−4.2 mW (−19.1 %)** |
| — sequential / clock | 0 / 0 | 0.331 mW / 0.053 mW | new (FF + CTS) |
| — combinational | 22.0 mW | 17.4 mW | −4.6 mW |
| Routed wirelength | 24 841 µm | 24 927 µm | +86 µm |
| Vias | 84 742 | 83 025 | −1 717 |
| **DRC violations** (detailed route) | **0** | **0** | 0 |
| Antenna net / pin violations | 0 / 0 | 0 / 0 | 0 |
| Routing layers | M2–M7 | M2–M7 | same |
| Congestion | converged, no overflow | converged, no overflow | same |

**Summary of the measured consequence of the architectural pipeline injection:**
`+2 output pipeline stages` → **−34 % WNS, −34 % TNS, −19 % power** for
**+0.43 % area / +46 flops**, with routing, DRC and congestion **unchanged**.

## Critical-path analysis

### Did the pipeline break the ~1.67 ns combinational cone?

**No — it moved the cone's endpoint from a port to a flop, and shaved ~223 ps
off it, but it is still a single combinational segment.**

* The **worst path is still `data input → max_val[*]`, combinational**, still
  **22** violating paths — same shape and count as GCB-027. `WNS = −442 ps`
  means the input-side segment (inputs → `val_pipe[0]`, the *first* pipeline
  register) is now ~1.44 ns.
* Where the +223 ps came from: with the cone now terminating at a **register**
  instead of a top-level output port, the resizer had shorter, better-loaded
  end nets to work with, and the last few levels sized up more effectively. It
  is a *resizing* gain, not a *logic-depth* gain.

### New timing paths introduced by the registers

Yes — and **none of them violate**:

| new path | type | slack |
|---|---|---|
| `g_reg_out.val_pipe[0][b] → val_pipe[1][b]` | stage 0 → stage 1, **pure flop-to-flop, no logic between** | **MET +29.98 ps** |
| `g_reg_out.vld_pipe[1] → out_valid` | reg → output port (`vclk`) | MET |
| `rst_n → g_reg_out.vld_pipe[1]` | async-reset removal check | MET +178.64 ps |

Because `gcb_max_reduce`'s `REG_STAGES` is an **output** pipeline
(`val_pipe[s] <= val_pipe[s-1]`, `idx_pipe`, `vld_pipe` — TKT-016), the two new
register→register segments carry **zero combinational logic** and meet 1 ns
trivially. The registers sit *after* the tournament tree, not *inside* it.

### Why timing did not close

The TKT-016 comment promised "synthesis retiming distributes the registers into
the tree." **The default ORFS synth recipe does not run register retiming**
(`abc` retiming / `-dff`). So all 46 flops stayed where the RTL puts them —
downstream of the whole reduce cone — and the cone's logic depth is unchanged.
`REG_STAGES=2` at the output is a **latency + power + net-load** win, not a
logic-depth win.

## Orange Team verdict

* **This is a clean, quantified transfer function** — exactly what the Measurement
  Epoch is for. `+2 output stages` buys −34 % WNS/TNS and −19 % power for
  essentially free area. It does **not** close 1 ns because it does not shorten
  the combinational cone.
* **It falsifies the working assumption** (carried from GCB-027's hypothesis 1
  and the TKT-016 comment) that `REG_STAGES=2` alone would close timing via
  retiming. Retiming is not on by default; output-only pipelining is not
  enough.
* **Architecture-from-measurement hypotheses to file as `GCB-###`:**
  1. **Enable register retiming** in a P&R-side synth sweep (still Measurement
     Epoch — a knob on the *flow*, not the RTL) and re-measure. If retiming
     alone closes 1 ns, GCB-028's `REG_STAGES=2` is already sufficient and only
     the flow config needs a line.
  2. If retiming is not enough: a **mid-tree pipeline** `gcb_max_reduce` variant
     (registers between tournament levels, `REG_STAGES` interpreted as *tree
     cut* count) — an RTL change, its own ticket, then re-measure.
  3. **`OUTPUT="VALUE"`** (drop the 1 008-`HAxp5` index datapath) where
     consumers don't need the argmax — measure the WNS delta from removing half
     the cone.
  4. **`REG_STAGES=3/4` sweep** as a cheap datapoint before the RTL change.
* The functional side is unaffected: GCB-028 already proved the compute
  dataflow is stall-free and bit-exact at *any* `MAXRED_REG_STAGES`; this ticket
  only measures what the physical timing actually is.

## Task 4 — RTL Baseline drift tripwire (post-P&R)

**PASS. GCB-029's P&R run did not corrupt the RTL Baseline.**

| check | result |
|---|---|
| toolchain manifest diff | **EMPTY** (Verilator 5.032 / sv2v 0.0.12 / Yosys 0.68 / node v22.22.1 / venv Python 3.12.14 / cocotb 1.9.2 / numpy 2.5.3) |
| `bash sim/lint.sh` | **exit 0**, 34 tops |
| cocotb smoke — TKT-020 R1 `Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0`, **`cov_violation=1`** |

Same isolation as GCB-027: ORFS on its own bundled Yosys/OpenROAD, no package
manager; only cross-touch the read-only `kepler-formal` `LD_LIBRARY_PATH` shim
(uv CPython 3.12.14 runtime lib). The [[TKT-000]] toolchain split held.

## Reproduce

```
# gcb_max_reduce.sv is UNCHANGED by GCB-028 - the sv2v netlist is the same as GCB-027.
# config: gcb-workspaces/eda/GCB-029/config/config.mk  (= GCB-027's + one line:
#   export VERILOG_TOP_PARAMS = REG_STAGES 2)
cd ~/eda/OpenROAD-flow-scripts/flow && source ../env.sh
export LD_LIBRARY_PATH=~/.local/share/uv/python/cpython-3.12.14-linux-x86_64-gnu/lib:$LD_LIBRARY_PATH
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk synth      # serial first
make DESIGN_CONFIG=designs/asap7/gcb_max_reduce/config.mk -j 2       # to finish
```
