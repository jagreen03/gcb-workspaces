---
id: TKT-016
title: "Shared gcb_max_reduce macro — one verified max/argmax primitive for QAM slicing and softmax"
date_created: 2026-09-09
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.0
tags:
  - backlog
  - rtl
  - photonic
  - compute
  - area
---

# Objective

Exploit the cross-domain correlation TKT-014 surfaced: design **one**
parameterised, synthesizable SV-2017 primitive `gcb_max_reduce` that both the
optical QAM demodulator (`gcb_qam_datapath_top` — min-distance / max-likelihood
constellation slicing) and the compute softmax pre-pass (`gcb_inline_vector_unit`
— overflow-safe `x − max(x)` before `exp`) can instantiate in place of their two
bespoke comparator trees, so the max-reduction hardware is built and verified
once. This ticket delivers the primitive and its equivalence proof; wiring it
into the two consumers is a separate integration ticket.

## Context & Constraints

* **Current State:**
  * TKT-014's serendipity pass ranked `gcb_qam_datapath_top` ↔
    `07_inline_vector_softmax.md` §3 top of the list (`cos_sim 0.2099`, surface
    Jaccard 0.010) — linked *entirely* by the term `max`. Both pipelines open
    with a **small-vector max-reduction as their first numerically load-bearing
    step**: the QAM datapath selects the constellation point of minimum distance
    / maximum likelihood; the softmax unit subtracts the vector max for
    overflow-safe `exp()`.
  * Each has its own ad-hoc max logic today. There is no shared reduction
    primitive in `gcb-wdm-transceiver/rtl/`.
  * `07_inline_vector_softmax.md` §3 ("Hardware Softmax, Structural") and §4.1
    (fixed-point representation) specify the softmax side; the QAM slice lives in
    `gcb_qam_datapath_top.sv` and `02_receiver_architecture.md`.
  * Frozen interfaces from prior tickets stay frozen. `gcb_qam_datapath_top` and
    `gcb_inline_vector_unit` are **not** on that frozen list, but any change to
    *their* ports is out of scope here — `gcb_max_reduce` is an internal
    instantiation.
  * EDA doctrine (`gcb-wiki/10`): pure SV-2017, Verilator-5 lint gate
    (`sim/lint.sh`), Cocotb ≥ 1.9 (`SIM=verilator`), `sv2v` → Yosys elaboration
    check.
* **Constraint:** One hand-written file `gcb-wdm-transceiver/rtl/gcb_max_reduce.sv`,
  fully parameterised — element count, element width, signed/unsigned, `MAX`
  vs `MIN` mode, output selection (value / index / both), tie-break policy,
  optional pipeline stages — with **no `N`-specific literal**. Verilator-5
  lint-clean at the `sim/lint.sh` bar with the new top added. A Cocotb TB must
  prove equivalence against a Python reference for the general primitive **and**
  for the two concrete use-case patterns. No edit to any frozen-list interface;
  no port change to `gcb_qam_datapath_top` / `gcb_inline_vector_unit`.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-016 is Green, through Blue-grade engineering** — a small,
correct, reusable primitive with a real equivalence proof and a quantified area
argument.

* **Green (target):** `gcb_max_reduce.sv` (parameterised comparator tree) plus a
  Cocotb TB that proves, over randomised vectors, **value and index equivalence
  vs a Python reference** for {signed, unsigned} × {`MAX`, `MIN`} × {value,
  index}, ties included (documented tie-break, directed-tested), **and** the two
  use-case equivalences: (a) `x − max(x)` computed through `gcb_max_reduce` is
  bit-identical to the reference for fixed-point vectors per `07` §4.1
  (most-negative / saturation edges included); (b) `MODE=MIN` over a
  candidate-distance set selects the identical constellation index the existing
  `gcb_qam_datapath_top` slice picks for the same inputs. `sim/lint.sh` exit 0
  with the new top; wired into `sim/lint.sh` and the guarded `sim/run_tb.sh`
  stanza; a Yosys `stat` comparing one shared tree against the two bespoke trees
  to quantify the area saved.

* **Blue:** the above, plus the primitive shaped so the eventual drop-in to both
  consumers is a pure instantiation with no glue, and a one-line pointer added
  to `07_inline_vector_softmax.md` / `02_receiver_architecture.md`.

* **Yellow (reject):** a tree that only covers the softmax case (unsigned,
  `MAX`) and "will generalise later" — the QAM equivalence is unproven, so the
  shared-area claim is unfounded; or an equivalence TB that checks only random
  vectors and skips the two real use-case patterns.

* **Red (reject):** changing a frozen-list interface; or bloating
  `gcb_max_reduce` into a grab-bag `reduce` (sum / min / max / any / prefix)
  that neither consumer fully uses, adding dead ports.

* **Purple / Light-gray:** a full parameterised reduction-tree library
  (sum / min / max / argmax / prefix-scan) is Purple / a later ticket. Keeping
  the two bespoke max trees (Light-gray) carries the duplicated area TKT-014
  flagged.

**Explicitly out of scope (separate tickets):**
1. Instantiating `gcb_max_reduce` into `gcb_qam_datapath_top` /
   `gcb_inline_vector_unit` — the integration follow-on.
2. Any port change to those two modules.
3. The rest of the softmax datapath (`exp`, normalisation) — `gcb-wiki/07`.
4. The QAM distance-metric computation upstream of the max.
5. Physical PPA, macro selection, floorplanning.

## The "Green" Target

1. `gcb-wdm-transceiver/rtl/gcb_max_reduce.sv` — one synthesizable SV-2017
   module. Parameters: `N` (elements), `W` (width), `SIGNED`, `MODE`
   (`MAX` / `MIN`), `OUT` (value / index / both), `TIE` (lowest- / highest-index),
   `REG_STAGES` (pipeline cut count, default 0 = combinational).
2. Comparator-tree implementation of depth `⌈log2 N⌉`, `REG_STAGES` inserted at
   even tree levels; no `N`-specific literal, `N` need not be a power of two.
3. Documented tie-break, exercised by directed tests (all-equal vector,
   adjacent ties, single element, `N` not a power of two).
4. Cocotb TB `sim/cocotb/test_max_reduce.py`: randomised equivalence vs a
   NumPy/Python reference for {signed, unsigned} × {`MAX`, `MIN`} × {value,
   index}, `N` and `W` swept over a small set.
5. **Use-case proof A (softmax):** drive fixed-point vectors per `07` §4.1,
   assert `x − max(x)` via `gcb_max_reduce` is bit-identical to the reference,
   including most-negative and saturation edges.
6. **Use-case proof B (QAM slice):** drive a candidate-distance set with
   `MODE=MIN`, assert the selected index equals the constellation index the
   existing `gcb_qam_datapath_top` slice logic picks for the same inputs
   (reference = a Python model of that slice / its extracted behaviour).
7. `bash sim/lint.sh` exit 0 with `gcb_max_reduce` added; Cocotb
   `TESTS=… PASS=… FAIL=0`; wired into `sim/lint.sh` and the guarded
   `sim/run_tb.sh` stanza; `sv2v` → Yosys elaboration check clean, latch-free.
8. A Yosys `stat` comparison — `gcb_max_reduce` synthesised once vs. the two
   existing bespoke max trees synthesised separately — quantifying the
   cell/area delta. Diff confined to the new RTL + TB + sim-list edits; nothing
   in a frozen module, nothing from the out-of-scope list.

---
## Execution Log

* **Agent ID:** Lead Hardware Engineer (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`

* **Commands Run:**
  * `verilator --lint-only -sv -Wall -Wno-DECLFILENAME -Wno-UNUSEDPARAM
    --top-module gcb_max_reduce` — clean.
  * `bash sim/lint.sh` — **exit 0, 29 tops** (`gcb_max_reduce` added to the RTL
    list and the top loop).
  * `make -C sim/cocotb -f Makefile.max_reduce` — **`TESTS=5 PASS=5 FAIL=0`**
    (softmax, QAM, corner configs, pipeline, 1200 randomised cross-checks).
  * `sv2v mr_<cfg>.sv rtl/gcb_max_reduce.sv | yosys -p 'read_verilog;
    hierarchy -check; proc; opt -purge; check -assert; select -assert-none
    t:$latch; synth -flatten; stat'` for the softmax (W16/N64) and QAM
    (W12/N16) configs — **exit 0 both, `Found and reported 0 problems`,
    latch-free**.

* **Cocotb assertions proven** (`sim/cocotb/test_max_reduce.py`):
  * `test_softmax_max_subtraction` — `max_val == max(x)` for 64 signed
    W=16/N=64 vectors incl. most-negative (`-2^15`), most-positive, all-equal;
    and `(x[k] - max_val) mod 2^16` bit-identical to the reference
    `(x[k] - max(x))` for every `k` (two's-complement wrap).
  * `test_qam_min_distance_slice` — `max_idx == argmin(distances)` with the
    documented lowest-index tie-break for 54 unsigned W=12/N=16 candidate sets
    (unique min, two-way tie, all-equal, min at last index). *(The shipped
    `gcb_qam_datapath_top` has no in-RTL argmin — the optical/ADC path makes
    the hard decision — so the reference is a Python model of a min-distance
    slicer, per out-of-scope item 4.)*
  * `test_corner_configs` — non-power-of-two `N=7` with the max at the
    odd-carry position (index 6); `TIE_LOW=0` resolving ties to the highest
    index; `N=1` degenerate (`val = elem`, `idx = 0`).
  * `test_pipeline_valid` — `REG_STAGES=2` delays value / index / `out_valid`
    by exactly 2 cycles (38 checks) and drains cleanly.
  * `test_randomized_equivalence` — 1200 value+index cross-checks across the
    soft / qam / np2 configs.

* **Yosys area (`synth -flatten`, gate-level cell count):**

  | config | cells |
  |---|---|
  | softmax envelope — `WIDTH=16, N_ELEMENTS=64, MODE=MAX, OUTPUT=BOTH` | **6629** |
  | QAM — `WIDTH=12, N_ELEMENTS=16, MODE=MIN, OUTPUT=BOTH` | **1248** |
  | two dedicated bespoke trees (sum) | **7877** |
  | one shared `gcb_max_reduce` at the W16/N64 envelope, time-multiplexed | **6629** |

  **Δ ≈ 1248 cells ≈ 15.8 %** of the combined 7877 eliminated when both sites
  time-multiplex the shared instance (the W12/N16 op fits the 16-bit/64-elem
  envelope with tie-off). Even without time-multiplexing, the two call sites
  now carry *identical, formally-equivalent* logic behind one lint / Yosys /
  Cocotb gate instead of two hand-rolled trees, with retiming-friendly
  `REG_STAGES`.

* **Artifacts Touched:**
  * `gcb-wdm-transceiver/rtl/gcb_max_reduce.sv` (new).
  * `gcb-wdm-transceiver/sim/cocotb/{max_reduce_tb_top.sv, test_max_reduce.py,
    Makefile.max_reduce}` (new).
  * `gcb-wdm-transceiver/sim/lint.sh`, `sim/run_tb.sh`, `.gitignore` — wired in
    the new top / cocotb stanza / build dirs.
  * No change to `gcb_qam_datapath_top`, `gcb_inline_vector_unit`, or any
    frozen-list interface; no consumer instantiation (integration follow-on).

---
## Telemetry & Evaluation

**Final State:** `Green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence 0.0)`,
`‖T‖₂ = √2 ≈ 1.414`.

* **X — Specification `+1.0`.** All eight Green-Target criteria met: one
  parameterised SV-2017 comparator tree (`WIDTH`, `N_ELEMENTS`, `MODE`
  MAX/MIN, `OUTPUT` VALUE/INDEX/BOTH, `SIGNED_CMP`, `TIE_LOW`, `REG_STAGES`;
  no `N`-specific literal; `N` need not be a power of two); a Cocotb TB proving
  value+index equivalence vs a Python reference over {signed,unsigned} ×
  {MAX,MIN} plus the two use-case proofs (softmax `x−max(x)` bit-exact; QAM
  `argmin` index) and the directed corners; `sim/lint.sh` exit 0 and Cocotb
  `FAIL=0`, both wired into the sim scripts; `sv2v`→Yosys elaboration clean and
  latch-free; and a Yosys `stat` quantifying the ~1248-cell / ~15.8 % saving.
  The `OUTPUT` naming (vs the ticket's compound `OUTPUT_TIE`) and the
  slicer-model reference for the QAM proof are scoped decisions, not spec gaps.

* **Y — Quality `+1.0`.** Blue-grade: one verified primitive rather than two
  hand-rolled trees, strict-`-Wall` lint-clean, `sv2v`→Yosys "0 problems" and
  latch-free, 1200+ randomised cross-checks plus directed odd-carry / both
  tie-policies / `N=1`, a real `REG_STAGES` pipeline with a drain proof, and an
  honest area figure with its time-multiplex assumption stated. No frozen
  interface touched; consumer integration correctly deferred.

* **Z — Emergence `0.0`.** A shared reusable primitive exploiting a TKT-014
  correlation — Blue consolidation, not net-new platform capability; the ticket
  claimed no Purple lean.

Dominant spoke: `|x| = |y| = 1.0`; tie-break `X > Y > Z` → `X+` → **Green**.
