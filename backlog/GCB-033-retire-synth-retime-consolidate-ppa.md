---
id: GCB-033
title: "Consolidation — retire SYNTH_RETIME_MODULES for gcb_max_reduce, promote the GCB-032 mid-tree config as the standing P&R config, and roll the physical arc into docs/PPA_burndown.md"
date_created: 2026-09-10
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 0.8
  emergence: 0.0
tags:
  - backlog
  - measurement-epoch
  - epic-tkt-017
  - epic-tkt-018
  - physical-design
  - documentation
  - consolidation
---

# Objective

Close out the `gcb_max_reduce` timing-closure investigation. The chain
established the answer:

* [[GCB-027]] — `gcb_max_reduce` @ defaults: **WNS −665 ps** @ 1 ns, a
  ~1.67 ns combinational cone (timing-bound, 619 µm², 0 DRC).
* [[GCB-028]] — RTL response: `REG_STAGES=2` in the requantize path
  (`MAXRED_REG_STAGES`); stall-free, bit-exact end-to-end.
* [[GCB-029]] — `REG_STAGES=2` as an *output* pipe still misses: **WNS −442 ps**,
  46 flops — registers after the whole tree, no retiming.
* [[GCB-030]] — `SYNTH_RETIME_MODULES = gcb_max_reduce` **closes** 1 ns
  (**WNS 0 ps**) but by **replicating 46 → 818 flops** (+63 % synth area,
  30.6 % sequential-area fraction, 57 max-slew DRVs).
* [[GCB-031]] — RTL response: `REG_STAGES > 0` now places its registers
  **between tournament levels** (genvar-elaborated segments). Yosys 0.68
  bless: ~442 flop bits, combinational cells unchanged, `REG_STAGES=0`
  byte-identical, `K`-cycle latency contract preserved — no consumer moved.
* [[GCB-032]] — physical validation: the mid-tree netlist through the exact
  GCB-029 ASAP7 flow, **`SYNTH_RETIME_MODULES` unset** → **WNS 0.00 ps @ 1 ns,
  0 setup violations, fmax 1.519 GHz**, at **372 flops** (−54.5 % vs GCB-030's
  818), synth area −29 %, power −23 %, wirelength −20 %, argmax cone intact,
  0 detailed-route DRC. 38 max-slew DRVs remain (own follow-on).

**Decision:** the mid-tree RTL pipeline is the physically-validated way to close
`gcb_max_reduce` at 1 GHz; synthesis retiming for this block is superseded.
This ticket makes that the *standing* state of the repo — it does **not** run a
new physical flow, change RTL, or touch the isolated P&R environment's tools.

## Context & Constraints

* **No new measurement.** All numbers are already in `eda/GCB-032/report.json`.
  GCB-033 is a documentation + config-record consolidation.
* **No RTL change.** `gcb_max_reduce.sv` is locked at GCB-031
  (`gcb-wdm-transceiver` `642251c`). `REG_STAGES = 0` stays the module default;
  the requantize consumer stays at `MAXRED_REG_STAGES = 2` ([[GCB-028]]).
* **`docs/PPA_burndown.md` is a measurement summary, not PDK material** — the
  [[TKT-000]] toolchain split forbids ASAP7 / PDK *files* in
  `gcb-wdm-transceiver`, not references to measured PPA. [[GCB-028]] already
  added a "Physical-measurement feedback" section there; GCB-033 extends it.
* **No git history rewrite** ([[GCB-026]]).
* The standing ORFS design config lives in the isolated P&R env
  (`~/eda/OpenROAD-flow-scripts/flow/designs/asap7/gcb_max_reduce/`), which is
  not in git; the git-visible canonical record is under `gcb-workspaces/eda/`.

## AI Orchestration Priorities (PBG Evaluation)

**Target: Green through Blue** — the minimal set of edits that make "retiming is
retired, mid-tree is the config" the unambiguous repo state, with the physical
arc legible from one place.

* **Green (target):**
  1. A stable, measurement-ticket-independent P&R config record for
     `gcb_max_reduce` at `gcb-workspaces/eda/gcb_max_reduce/`
     (`config.mk` + `constraint.sdc` = GCB-032's, i.e. **no
     `SYNTH_RETIME_MODULES`**, `REG_STAGES 2` via `VERILOG_TOP_PARAMS`) + a
     short `README.md` stating it is the standing config and GCB-032 is the run
     that validated it. Future measurement stories copy from here.
  2. `gcb-wdm-transceiver/docs/PPA_burndown.md`: the "Physical-measurement
     feedback" section extended to the full GCB-027 → GCB-032 arc — the
     transfer-function table (WNS / flops / area / power / DRV across GCB-029 /
     GCB-030 / GCB-032), the one-line verdict ("mid-tree RTL closes 1 ns
     without retiming, ~half retiming's flops"), the standing config, and the
     open 38-max-slew-DRV item pointing at its follow-on. The `gcb_max_reduce`
     row in the per-block gate table annotated with the `max_reduce_p2` bless
     (`REG_STAGES=2` mid-tree: 42 `$adff`, comb cells unchanged).
  3. `gcb-workspaces/backlog/GCB-030-FINDINGS.md`: a short **"Resolved"** note
     at the top — retiming closes it but at 818 flops; [[GCB-031]] +
     [[GCB-032]] supersede it; `SYNTH_RETIME_MODULES` for this block is
     retired.
  4. `gcb-workspaces/README.md` index row + layout tree.
  5. Isolated P&R env: the `flow/designs/asap7/gcb_max_reduce/config.mk`
     already on disk is the GCB-032 (no-retiming) config; GCB-033 records that
     as the standing state (a carried-over banner comment is fine, no tool or
     PDK change).
* **Blue:** a one-line pointer from `sim/yosys068_bless/SUMMARY.md`'s
  `max_reduce_p2` row to the GCB-032 physical result; a `docs/PPA_burndown.md`
  note that the 4096³ default geometry still bit-blasts (unchanged Y1 caveat)
  so the ASAP7 run stays at `WIDTH=16 N_ELEMENTS=64`.
* **Yellow (reject):** editing `docs/PPA_burndown.md` to *delete* the GCB-030
  retiming result — it is a real measurement and part of the record; it is
  *superseded*, not wrong. Copying ASAP7 `.lib` / `.lef` / tech files into
  `gcb-wdm-transceiver` to "make the config self-contained".
* **Red (reject):** any RTL edit; re-running the ASAP7 flow; changing
  `MAXRED_REG_STAGES`'s default or `REG_STAGES`'s module default; rewriting the
  GCB-030 commit or ticket.
* **Purple / Light-gray:** a general per-design ORFS config library with CI
  wiring is a later Epic (Purple); leaving `SYNTH_RETIME_MODULES` "available
  but unused" with no doc trail (Light-gray) is what this ticket exists to
  prevent.

## The "Green" Target

1. `gcb-workspaces/eda/gcb_max_reduce/{config.mk, constraint.sdc, README.md}` —
   the standing P&R config (= GCB-032's), no `SYNTH_RETIME_MODULES`, with the
   README naming GCB-032 as the validating run and pointing at
   `eda/GCB-032/report.json` for the numbers.
2. `gcb-wdm-transceiver/docs/PPA_burndown.md` — "Physical-measurement feedback"
   section carries the GCB-027 → GCB-032 arc, the transfer-function table, the
   verdict, the standing config, and the open DRV item. The `gcb_max_reduce`
   gate-table row notes the `max_reduce_p2` (`REG_STAGES=2` mid-tree) bless.
   Diff confined to that file.
3. `gcb-workspaces/backlog/GCB-030-FINDINGS.md` — "Resolved by GCB-031 /
   GCB-032" note; `SYNTH_RETIME_MODULES` retired for this block.
4. `gcb-workspaces/README.md` — GCB-033 index row + layout-tree entries.
5. **No** change to `gcb_max_reduce.sv`, the manifest tool pins, the bless
   `.stat` files, or the isolated P&R env's tools / PDK. `bash sim/lint.sh`
   still exit 0 (unchanged RTL); no cocotb re-run needed (no RTL/TB change).

### Explicitly out of scope (own follow-ons, per [[GCB-032]]-FINDINGS)

* **Slew-repair pass** — measure `SKIP_LAST_GASP = 0` on the GCB-032 design and
  confirm the 38 max-slew DRVs clear. A physical (Orange) story.
* **`OUTPUT = "VALUE"`** — drop the 1 008-`HAxp5` argmax cone where the index is
  unused. An RTL trade study.

### Toolchain

RTL Baseline (`gcb-wdm-transceiver/sim/toolchain_manifest.json`) unchanged and
untouched. P&R env unchanged (config already in place; no tool / PDK edit).

---
## Execution Log

**Executed 2026-09-10 · Release Engineer / Technical Program Manager ·
session `01Rpa9VJGe7xypzp5FkukSco` · not committed.**

No physical run, no RTL change, no P&R-env tool/PDK edit. Consolidation only.

### `gcb-workspaces`

* **`eda/gcb_max_reduce/{config.mk, constraint.sdc, README.md}`** (new) — the
  standing, measurement-ticket-independent ASAP7 config = [[GCB-032]]'s:
  `REG_STAGES 2` via `VERILOG_TOP_PARAMS`, **no `SYNTH_RETIME_MODULES`**,
  deliberately-ugly recipe (`CORE_UTILIZATION=40`, `PLACE_DENSITY=0.55`,
  `SKIP_LAST_GASP=1`). `config.mk` header rewritten from a GCB-032 snapshot
  into a standing banner (closure path, GCB-032 validation numbers, the open
  38-DRV item). `README.md` carries the GCB-027 → GCB-032 step table and the
  reproduce recipe. Future Measurement-Epoch stories copy from here.
* **`backlog/GCB-030-FINDINGS.md`** — a `> RESOLVED` block at the top: retiming
  closes 1 ns but by 46 → 818 replication; [[GCB-031]] + [[GCB-032]] supersede
  it; `SYNTH_RETIME_MODULES` retired; standing config pointer. The 46 → 818
  measurement body is kept verbatim as the record of *why* the RTL path was
  needed.
* **`README.md`** — GCB-033 index row `done | green`; layout tree gains the
  `GCB-033-*.md` ticket and the `eda/gcb_max_reduce/` standing-config dir.

### `gcb-wdm-transceiver` (docs only — no RTL, no `.stat`, no manifest)

* **`docs/PPA_burndown.md`** — the "Physical-measurement feedback" section
  retitled `(GCB-027 → GCB-032)` and extended: the GCB-029 / GCB-030 / GCB-031
  / GCB-032 step table, the **GCB-030 retiming → GCB-032 mid-tree**
  transfer-function table (WNS / flops −54.5 % / synth area −29 % / power
  −23 % / wirelength −20 % / `HAxp5` cone intact / max-slew DRVs 57 → 38 / DRC
  0), the verdict, the standing-config pointer, and the open 38-DRV +
  `OUTPUT="VALUE"` follow-ons. Per-block gate table gains a second
  `gcb_max_reduce` row for `max_reduce_p2` (`REG_STAGES=2` mid-tree: 987 cells,
  42 `$adff`, combinational cells unchanged). PDK-material-free — measurement
  summary only, per [[TKT-000]] (precedent: [[GCB-028]] added this section).
* **`sim/yosys068_bless/SUMMARY.md`** — one sentence on the `max_reduce_p2` row:
  GCB-032 physically validated it (WNS 0.00 ps, 372 `DFFASRHQN`, 0 DRC),
  `SYNTH_RETIME_MODULES` retired. `.stat` files unchanged.

### Isolated P&R environment

`~/eda/OpenROAD-flow-scripts/flow/designs/asap7/gcb_max_reduce/{config.mk,
constraint.sdc}` synced to the standing `eda/gcb_max_reduce/` copy
(`grep '^export SYNTH_RETIME'` → none). No ORFS / OpenROAD / Yosys / ASAP7
tool or PDK change.

### Verification

| gate | result |
|---|---|
| `bash sim/lint.sh` | **exit 0**, 32 tops (RTL untouched) |
| RTL repo diff | `docs/PPA_burndown.md` + `sim/yosys068_bless/SUMMARY.md` only — doc-only, no `.sv` / `.stat` / manifest |
| cocotb | not re-run — no RTL or TB change (per ticket) |
| `toolchain_manifest.json` | unchanged |

---
## Telemetry & Evaluation

**Final State:** `done | green`

**Vector Summary:** `T = (spec +1.0, quality +0.8, emergence 0.0)`,
`‖T‖₂ ≈ 1.28`. `telemetry_color: green` (argmax\|axis\| = spec, +X → Green).

* **Spec +1.0** — the Green target met in full: standing
  `eda/gcb_max_reduce/` config promoted (no `SYNTH_RETIME_MODULES`), the
  GCB-027 → GCB-032 physical arc + transfer function rolled into
  `docs/PPA_burndown.md`, `GCB-030-FINDINGS.md` marked resolved, the bless
  SUMMARY cross-linked, the P&R env config synced. Retiming for this block is
  now unambiguously retired across config, docs and findings.
* **Quality +0.8** — Blue-grade tidy: the GCB-030 retiming *measurement* is
  preserved verbatim (superseded, not deleted), every artifact cross-links, the
  standing config is reusable (future stories copy it), and the diff is
  doc-only with zero RTL / `.stat` / manifest churn. Not +1.0 only because the
  ORFS design config still physically lives in the un-versioned P&R env — the
  git record is a copy, not the source of truth.
* **Emergence 0.0** — pure consolidation; no new capability.

### Open follow-ons (own `GCB-###`, per [[GCB-032]]-FINDINGS)

1. `SKIP_LAST_GASP = 0` slew-repair re-measure — clear the 38 max-slew DRVs.
2. `OUTPUT = "VALUE"` — drop the 1 008-`HAxp5` argmax cone where unused.
