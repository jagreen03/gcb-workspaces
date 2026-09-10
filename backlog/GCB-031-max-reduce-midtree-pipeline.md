---
id: GCB-031
title: "Architecture-from-measurement (GCB-030 loop) — mid-tree pipelined gcb_max_reduce so REG_STAGES>0 closes timing without register replication"
date_created: 2026-09-10
status: open
telemetry_color: pending
tags:
  - backlog
  - rtl
  - compute
  - physical-design
  - pipeline
  - measurement-epoch
  - epic-tkt-017
---

# Objective

Act on the [[GCB-030-FINDINGS]] preferred hypothesis. The measurement chain
established:

* [[GCB-027]] — `gcb_max_reduce` is a **~1.67 ns combinational cone**
  (`WNS = −665 ps` @ 1 ns), timing-bound.
* [[GCB-028]] — instantiating it with `REG_STAGES = 2` (an **output** pipeline,
  TKT-016) in the requantize path; functionally +latency-only, stall-free
  end-to-end.
* [[GCB-029]] — `REG_STAGES = 2` alone still misses 1 ns (`WNS = −442 ps`)
  because the registers sit *after* the whole tree and default ORFS synth runs
  no retiming.
* [[GCB-030]] — enabling retiming **does** close 1 ns (`WNS = 0`), but by
  **replicating 46 flops → 818** across the 64-wide tree fan-out
  (`+63 %` cell area, `30 %` sequential-area fraction, `57` new max-slew DRVs).

**This ticket changes `gcb_max_reduce.sv` so `REG_STAGES > 0` places its
pipeline registers *between tournament-tree levels* by design** — cutting the
`⌈log2 N⌉`-deep fold into `REG_STAGES + 1` roughly-equal logic-depth segments —
so timing closes with **no retiming** and a flop count on the order of
`Σ (partial-winner width at each cut) · (WIDTH + IDX_W)`, i.e. tens of flops,
not hundreds.

**Non-negotiable:** `REG_STAGES = 0` stays **bit- and cycle-identical** to
today, and for `REG_STAGES > 0` the module keeps its current **latency
contract** (`out_valid` / `max_val` / `max_idx` emerge exactly `REG_STAGES`
cycles after `in_valid`, equal to the combinational reference) — so **no
consumer changes**, and in particular `gcb_tile_requantize.sv`'s GCB-028
`MAXRED_REG_STAGES` operand-alignment (which depends only on that latency)
needs **zero edits**.

## Context & Constraints

* **Current RTL (`rtl/gcb_max_reduce.sv`, TKT-016):** one `always_comb` builds
  the balanced tournament fold over `N_ELEMENTS` leaves, `LEVELS = ⌈log2 N⌉`
  deep, odd elements carried up; then a `g_comb_out` / `g_reg_out` branch
  optionally registers the *final* `{max_val, max_idx, out_valid}` by
  `REG_STAGES`. It is a **3-site shared primitive** — QAM hard-decision slice
  (`REG_STAGES=0`), softmax `x − max(x)` pre-pass (`REG_STAGES=0`), and the
  requantize block-float scale (`gcb_tile_requantize`, GCB-028, driven at
  `REG_STAGES=2` via `MAXRED_REG_STAGES`).
* **Interface is frozen for consumers:** no change to the port list, no change
  to `WIDTH` / `N_ELEMENTS` / `MODE` / `OUTPUT` / `SIGNED_CMP` / `TIE_LOW` /
  `REG_STAGES` names or meanings that a consumer relies on. `REG_STAGES`
  still means "`REG_STAGES` cycles of pipeline latency"; only *where* the
  registers live changes.
* **`gcb_tile_requantize.sv` must not need any edit.** Its GCB-028 alignment
  delay is `MAXRED_REG_STAGES` cycles of `pe_mag` / `pe_sgn` / `in_valid` hold —
  it assumes exactly that many cycles from the reduce input to `ch_max`. This
  ticket preserves that.
* **Toolchain:** pure SV-2017; Verilator-5 `sim/lint.sh`-clean; Cocotb ≥ 1.9 on
  the pinned venv (`~/.venvs/cocotb19`); `sv2v` → Yosys **0.68** elaboration
  clean and **latch-free** at a `chparam` bring-up geometry (re-bless
  `sim/yosys068_bless/{max_reduce,tile_requantize}.stat`). Re-run the manifest
  diff first; a delta re-triggers the TKT-022 Yellow-Team regression as a gate.
* **PBG / Cyclopter prompt-layer protocol stays out of the RTL repo**
  (`gcb-wiki/04`).

## AI Orchestration Priorities (PBG Evaluation)

**The target for GCB-031 is Green, through Blue-grade engineering** — the
minimal RTL change that gives `REG_STAGES > 0` an internally-pipelined tree,
proven functionally identical and interface-transparent.

* **Green (target):** `gcb_max_reduce.sv` with mid-tree register cuts for
  `REG_STAGES > 0` (auto-distributed across `LEVELS`; an optional explicit
  `PIPE_CUT_SPEC`-style param is Blue, not required); `REG_STAGES = 0`
  bit/cycle-identical to today; the module still emits the correct
  max/argmax `REG_STAGES` cycles after `in_valid` for every
  `{signed,unsigned} × {MAX,MIN} × {VALUE,INDEX,BOTH}` config and `N` not a
  power of two; `test_max_reduce.py` extended to prove `REG_STAGES ∈ {0,1,2,3}`
  equivalence + latency, existing 5 tests unchanged-green; **`test_tile_requantize.py`
  and `test_compute_e2e.py` pass with NO edit** (40/40 bit-exact,
  `stall_count == 0`); `sim/lint.sh` exit 0; `sv2v` → Yosys 0.68 elaboration
  clean + latch-free (re-blessed).
* **Blue:** an explicit cut-placement parameter for later tuning; a directed
  Cocotb latency-equivalence check (drive one vector, sample `REG_STAGES`
  cycles later, compare to the comb reference) across `REG_STAGES` and `N`; a
  one-line note in `docs/PPA_burndown.md` + `[[GCB-030-FINDINGS]]` that the RTL
  variant is in place, pending the GCB-032 physical re-measure.
* **Yellow (reject):** cut levels hard-coded for `N_ELEMENTS = 64` only, with
  no `N`-general placement; a variant where `REG_STAGES = 0` is no longer a
  pure pass-through; "proving" equivalence only for `MODE=MAX / OUTPUT=BOTH`.
* **Red (reject):** any change to the port list or to a consumer-visible
  parameter's meaning; a rewrite that changes the max/argmax result or the
  tie-break; forcing `gcb_tile_requantize.sv` (or any other consumer) to change;
  editing `gcb_max_reduce.sv` in a way that breaks `REG_STAGES` as a
  latency count.
* **Purple / Light-gray:** a full parameterised reduction-tree library with
  runtime dataflow switching is Purple / a later Epic; shipping the
  retiming-replication result from GCB-030 (Light-gray) carries the
  818-flop / +63 %-area cost into every future instantiation.

## The "Green" Target

1. `gcb-wdm-transceiver/rtl/gcb_max_reduce.sv`:
   * `REG_STAGES = 0` → **unchanged** (pure combinational fold, no registers,
     `out_valid = in_valid`) — bit/cycle-identical, verified by a directed
     `REG_STAGES=0` regression against the pre-GCB-031 file.
   * `REG_STAGES = K > 0` → the `LEVELS`-deep fold is split by `K` register
     banks at levels `≈ round(LEVELS · (k+1)/(K+1))` for `k ∈ [0,K)`; each bank
     registers the current partial-winner `{value[], index[]}` set (width
     `⌈N / 2^level⌉`) plus a `valid` bit. Total latency `in_valid → out_valid`
     is exactly `K` cycles — the current contract.
   * Optional `PIPE_CUT_SPEC` (or similar) parameter for explicit cut levels;
     default is the auto-distribution above. No new *required* parameter.
2. `sim/cocotb/test_max_reduce.py`:
   * the existing 5 tests stay green;
   * a new equivalence + latency test: for `REG_STAGES ∈ {0,1,2,3}`,
     `N ∈ {7,16,64}`, `{signed,unsigned} × {MAX,MIN} × {VALUE,INDEX,BOTH}`,
     drive random vectors and assert the output `REG_STAGES` cycles later is
     bit-identical to the combinational (`REG_STAGES=0`) reference, and that
     `out_valid` tracks `in_valid` delayed by exactly `REG_STAGES`.
3. `sim/cocotb/test_tile_requantize.py` + `test_compute_e2e.py` run **with no
   source edit** and stay green — `test_compute_e2e.py`:
   `MATCH | 40/40 tiles bit-exact | stall_count == 0`. (The GCB-028
   `MAXRED_REG_STAGES=2` alignment depends only on the preserved latency.)
4. `bash sim/lint.sh` exit 0; every Cocotb suite `FAIL = 0` on the pinned venv;
   `sim/run_tb.sh` stanzas unchanged.
5. `sv2v` → Yosys 0.68 elaboration of `gcb_max_reduce` (and, via the submodule,
   `gcb_tile_requantize`) clean + **latch-free** at a `chparam` bring-up
   geometry; refresh `sim/yosys068_bless/{max_reduce,tile_requantize}.stat` +
   `SUMMARY.md`.
6. `docs/PPA_burndown.md` + `[[GCB-030-FINDINGS]]` get a one-line "mid-tree
   pipelined variant landed (GCB-031); physical re-measure is GCB-032" note.
   Diff confined to `gcb_max_reduce.sv` + `test_max_reduce.py` + the bless stats
   + the two doc lines. Nothing else.

### Follow-on (not this ticket)

* **GCB-032** — re-run the [[GCB-029]] / [[GCB-030]] ORFS / ASAP7 flow on
  `gcb_max_reduce` at `REG_STAGES = 2`, **without** `SYNTH_RETIME_MODULES`, and
  confirm `WNS ≥ 0` at a flop count far below GCB-030's 818 (target: tens).
  Its own Measurement-Epoch story, in the isolated P&R env.
* `OUTPUT = "VALUE"` (drop the ~827-`HAxp5` index cone) where consumers don't
  need the argmax — orthogonal trade, own ticket.

### Toolchain

Pinned RTL Baseline (`gcb-wdm-transceiver/sim/toolchain_manifest.json`)
unchanged. Re-run the manifest diff before execution.

---
## Execution Log
*(To be populated during execution.)*

---
## Telemetry & Evaluation
*(To be populated post-execution.)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
