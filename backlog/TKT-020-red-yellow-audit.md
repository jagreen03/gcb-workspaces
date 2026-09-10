---
id: TKT-020
title: "Red/Yellow foundation audit — adversarial + tech-debt review of the locked baseline before the Epics"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - audit
  - red-team
  - yellow-team
  - risk
---

# Objective

Before TKT-017 / TKT-018 / TKT-019 spend engineering on new capability, stress
the **locked baseline** they build on: the GDDR7 tensor DMA, the banked 1W1R
operand SRAM (TKT-012), the `gcb_max_reduce` DSP macro (TKT-016), the Cyclopter
pgvector store + scavenger (TKT-011 / TKT-013), and the DigitalJS/ELK dashboard
(TKT-001). Two adversarial personas:

* **Red Team** — attack the architecture for fatal flaws and hard physical
  boundaries the current verification cannot see.
* **Yellow Team** — audit the integration seams for hard-coded assumptions and
  process fragility that will fracture at 5nm or on a presentation machine.

This ticket is an **assessment deliverable**, not graded execution. It produces
findings + recommended gate tickets; it changes no RTL or code.

## Scope (locked baseline under audit)

| Component | Artifact | Locked by |
|---|---|---|
| Tensor operand SRAM | `gcb_sram_sp1w1r.sv`, `gcb_tensor_operand_sram.sv`, `gcb_tensor_sram_controller.sv` | TKT-012 |
| GDDR7 DMA | `gcb_tensor_dma_arbiter.sv` + generated CSR wrapper | TKT-008/009/010 |
| Max-reduce DSP | `gcb_max_reduce.sv` + Cocotb equivalence TB | TKT-016 |
| Cyclopter KG | `pbg_telemetry` pgvector table, `load_telemetry_pg.py`, `cyclopter_scavenger.py` | TKT-011/013 |
| Dashboard | `build_visuals.py`, `render/digitaljs_render.mjs` | TKT-001 |
| Optical boundary | `gcb_bitplane_tx_mapper.sv`, `gcb_wavelength_router.sv`, `gcb_rx_digital_recombiner.sv`, `gcb_dwdm_dualmode_top.sv` | TKT-015 doctrine |

## Method

Findings are grounded in the checked-in RTL/code (`file:symbol` cited), not
generic risk. Each Red finding states the **failure scenario**, **why the
existing test suite is blind to it** (usually: the Cocotb TB and the DUT share
the same behavioural model), and a **containment** direction. Each Yellow finding
states the **hard-coded assumption** and the **fracture point**.

---

## Task 1 — Red Team: Fatal Flaws & Hard Boundaries

### R1 — Banked SRAM: no reset, no write-coverage guard → silent numeric corruption on any partial tile

**Claim.** The "0 dropped beats / 0 read stalls" proof holds only for a
conformant BFM that writes **every** operand address before the grid reads it.
Nothing in the RTL enforces that, and there is no reset to fall back on.

**Evidence.**
* `gcb_sram_sp1w1r.sv`: `logic [DW-1:0] mem [0:DEPTH-1];` — **no initial value**,
  **no `rst_n` port**. Write is `always_ff @(posedge clk) if (we) mem[waddr] <= wdata;`.
  Read is `assign rdata = mem[raddr];` (`RD_REG=0`) or an **un-reset flop**
  (`RD_REG=1`).
* `gcb_tensor_operand_sram.sv` and `gcb_tensor_sram_controller.sv` carry no
  reset into the storage either; `ST_PRIME` only waits for the loader's
  `a_load_done` / `b_load_done` **pulses** — it never checks that
  `LANES × K_STEPS` (A) / `LANES × N_SUBTILES × K_STEPS` (B) distinct addresses
  were actually written.

**Failure scenario.** A real GDDR7 transfer with a short final burst, a K tail
shorter than `K_MAX`, a predicated/masked tile, or a loader that asserts
`*_load_done` early, leaves a subset of macro addresses unwritten. The grid then
reads them and the INT4 MAC array multiplies by **whatever was there**:
`0` under Verilator's default zero-init (so the Cocotb suite is green), **`X` →
random in gate-level sim and silicon**. No exception, no stall, no X-propagation
assertion — a wrong matmul result that looks like a converged model.

**Why the tests miss it.** `test_operand_sram.py` / `sram_contention_tb_top.sv`
drive a fully-populating write stream and compare against the same Python model
that also fully populates. Neither the DUT nor the reference has an
"address never written" state, so the equivalence is vacuously satisfied.

**Containment.** Add `rst_n` + a defined power-on pattern to `gcb_sram_sp1w1r`;
add an elaboration-time / simulation `assert` in the controller that every
resident address in a bank was written since the last swap (a per-bank written
bitmap in `SIMULATION`); a directed TB case that loads `K_STEPS-1` of `K_STEPS`
and expects a flagged error, not a silent `0`.

### R2 — Optical→digital boundary: the reconstruction algebra assumes a perfect channel that silicon will never provide

**Claim.** Every bit-exact bitplane/QAM equivalence result to date was produced
against a **lossless, noiseless** channel model. The digital reconstruction path
has **no error detection** and the `>>> 2` is a truncating divide that is only
exact when the numerator is divisible by 4.

**Evidence.**
* `gcb_rx_digital_recombiner.sv`: `num_s = lij_ext + (usx(m_a[i])<<<1) +
  (usx(m_b[j])<<<1) - usx(k_len); s_ij_c = num_s >>> 2;` — arithmetic
  right-shift **floors toward −∞**; there is no rounding term and no
  "divisible-by-4" check. `y_c += ACC_W'(WW[i][j]) * s_ij_c` with
  `WW` up to `{... 64}` (max |W_i·W_j| = 64), then `result_c = 16'(y_c)` —
  a **silent** narrowing cast.
* `k_len` (the lane-active count `K`) is a **digital** value the RX must know
  exactly to subtract; Tx and Rx derive it independently.
* `sim/optical_mesh_dpi.cpp` is behavioural and lossless — the DPI the
  dual-mode TB uses.
* `gcb_dwdm_dualmode_top.sv` **shares** the datapath between QAM and bitplane
  modes on a mode select.

**Failure scenario.** (a) A single ADC LSB error on one `L_ij` propagates
through `>>> 2` and a `×64` weight → up to **~64 LSB swing** in the INT16 `Y`,
undetected (no parity/CRC/FEC/soft-decision anywhere in the digital path).
(b) A one-count Tx/Rx disagreement on `k_len` (deskew slip, dropped pilot, a
wavelength that failed to illuminate) biases **every** `S_ij` by `1/4` and the
`16'(y_c)` cast hides the resulting overflow. (c) A mode-select glitch or an
in-flight reconfiguration of the shared dual-mode datapath corrupts a whole
operand block with nothing to catch it. **TKT-019 scales wavelength count**,
which scales crosstalk and per-λ skew — precisely the non-idealities the current
model omits.

**Why the tests miss it.** The TB channel (`optical_mesh_dpi`) delivers the
exact integer sums the algebra assumes, so `S_ij` is always exactly divisible by
4 and `k_len` always agrees. The proof is real — for a channel that cannot be
built.

**Containment.** Before TKT-019: a noisy/lossy channel model (AWGN + crosstalk +
per-λ skew) as a TB mode; a BER/eye harness; an end-to-end integrity check
(operand-block CRC or a parity plane) in the digital path; explicit rounding
policy on `>>> 2`; a saturating (not wrapping) final cast with an overflow flag.

### R3 — Cyclopter scavenger: it cannot invent data, but it can *launder* a transient/biased read into a trusted artifact

**Claim.** The scavenger's writes are safe (read-only `SELECT` for noise,
idempotent `ON CONFLICT DO UPDATE` upsert). The exposure is that it treats
**on-disk Markdown at poll time** and **a same-day-seeded "random" sample** as
ground truth, and publishes both with provenance stamps that downstream agents
trust.

**Evidence.**
* `cyclopter_scavenger.py`: the debounce gate is **hash-stability**, not
  parse-validity — "a burst of editor writes … collapses into a single run once
  the file's hash has been stable for `--debounce` seconds." It then shells
  `parse_pbg_telemetry.py` against whatever is on disk.
* `emit_noise()`: `seed = int(self.args.seed) if given else` **UTC `YYYYMMDD`**
  (`--seed` help: "default: UTC YYYYMMDD"). `rnd = random.Random(seed)` over the
  non-pending rows, tagged `"provenance": "random_sample"`.
* KNN uses `KNN_COSINE` (`telemetry_vec <=> query`); there is no pre-flight
  "corpus sane" check (NULL / wrong-dimension vectors, NaN norms).

**Failure scenario.** (a) A ticket file that is hash-stable but semantically
broken mid-`git` operation — a merge-conflict marker in the frontmatter, a
half-typed `telemetry_color`, a truncated `telemetry:` block — can still parse
to a frontmatter dict and be **upserted as a confident wrong grade**. Because
the upsert is idempotent, re-running never repairs it; only a genuine re-grade
transition does. (b) The "M random non-pending rows" are **identical for 24 h**
(same day-seed): a daily RAG planner sees the same 3 "random" tickets all day —
a fixed bias wearing a `random_sample` label. (c) One malformed
`telemetry_vec` row (loader bug, manual DB poke, migration drift) either errors
the whole noise pass or is silently ranked by `<=>`. In every case the KG
context other agents consume is wrong, and the provenance stamp makes a human
auditor trust it.

**Why the tests miss it.** The TKT-013 restart-safety tests drive *well-formed*
transitions and check row counts converge; they never feed a syntactically
broken-but-hash-stable file, and the "random" sample is only checked for
*reproducibility* (which the day-seed trivially satisfies).

**Containment.** Validate the parsed frontmatter (schema + vector dimension +
`‖T‖ ≤ √3`) before upsert, and quarantine (log, don't upsert) on failure; seed
the random sample from `(day, corpus-hash, run-nonce)` not the bare date, or
draw without a fixed seed and record the drawn ids; a `corpus_sane()` pre-flight
(no NULL/'' vectors, all dimension 3) before any noise artifact is written.

---

## Task 2 — Yellow Team: Technical Debt & Integration Friction

### Y1 — Hard-coded assumptions that fracture at 5nm / OpenROAD

1. **Single clock, single async reset, zero CDC scaffolding.** Every module is
   `always_ff @(posedge clk or negedge rst_n)` on one `clk`. The GDDR7 PHY, the
   optical line-rate serdes, and the compute core are physically ≥3 clock
   domains; there is not one synchroniser, `ASYNC_REG`, or CDC constraint in the
   RTL, and **no SDC exists anywhere**. OpenROAD CTS will build one clock tree;
   TKT-018/019 introduce the second and third domains with nothing to cross them
   safely.
2. **`gcb_max_reduce` is combinational at every baseline instantiation.** The
   `always_comb` tournament fold is `⌈log₂N⌉` deep (6 levels for N=64) of
   16-bit signed compare + index mux; `REG_STAGES` defaults to `0` and the TB
   wrapper instances (`u_soft`, `u_qam`) all use `0`. Yosys `synth -flatten`
   gave a **cell count, not a timing path**. At a 1–2 GHz 5nm target this path
   will not close; pipelining it back adds flops that erode the headline
   **15.8 % area saving** (which was measured on the un-pipelined envelope).
3. **Power-of-two geometry baked into the address math.** `gcb_tensor_operand_sram.sv`
   computes `MACRO_AW'(wr_sub) * MACRO_AW'(DEPTH_K) + MACRO_AW'(wr_k)` with the
   in-source justification "DEPTH_K / SUBTILES are powers of two … the multiply
   is a shift." Any floorplan-driven non-power-of-two tiling (reticle fit, SRAM
   compiler aspect ratio, redundancy columns) turns that into a real multiplier
   in the address path and invalidates the "lossless cast" comments.
4. **The baseline has never been synthesised at its real size.** The Doc 12/05
   sizes are *default parameters* (`M_TOTAL=4096`, `N_TILE=1024`, `K_STEPS=256`,
   4 MiB B-tile). The TKT-012/016 Yosys runs used `-chparam` to **shrink**
   (`K_TOTAL 512`, `N_TILE 64`) because full geometry was too slow. OpenROAD on
   the full 4 MiB array is the first real place-and-route data point.
5. **`SRAM_LATENCY` (controller flop pipe) and `RD_REG` (macro read latency) are
   independent parameters with no consistency check.** The synthesizable path
   *requires* `RD_REG=1` synchronous macros at 5nm (a 4 MiB async register file
   is not a thing); nothing forces `SRAM_LATENCY` to track the macro's true
   latency, and a real 1W1R compiler may be 2-cycle. Mismatch → `done` /
   `sram_valid` present stale `sram_rdata` to `gcb_tensor_broadcast_fabric`.

### Y2 — Python orchestration fragility for a live presentation

1. **Silent-skip that looks like success.** `build_visuals.py::DigitalRtlBuilder.is_available()`
   needs `sv2v` + `yosys` + `node` + `node_modules/` all on PATH — true only
   inside WSL Ubuntu — but the VS Code task runs `python3 build_visuals.py` from
   a Windows `cwd`. If WSL isn't started, or `npm ci` wasn't run, the builder
   logs `skip … (preconditions not met)` and **exits 0**, and the dashboard
   shows **stale `outputs/*.svg`** with no error. A demo that silently serves
   yesterday's chip.
2. **Multi-minute layout with no progress.** `render/digitaljs_render.mjs` took
   minutes and 200+ MB on `greencoyote_dma_axi_master` (its SVG is **6.9 MB** —
   heavy for a browser tab), ~40 s on `greencoyote_top`. "Regenerate the
   visuals" on stage is a silent hang.
3. **The KG lives in an ephemeral, git-divergent DB.** pgvector runs as a
   `pgserver` instance in WSL **`/tmp/pgv`** (gone on reboot) with a **patched
   migration** — the Doc 09 `vec_norm` STORED expression swapped to
   `vector_norm()` because pgserver's pgvector 0.6.2 lacks `vector[i]`
   subscripting. **The committed `001_pbg_telemetry.sql` is not what is
   running.** Every Cyclopter/KNN demo depends on a hand-primed local DB rebuilt
   from memory (uv + pgserver + prime) after any restart, and there is a latent
   schema-drift bug for whoever first runs the *committed* migration.
4. **Three interpreters, no lockfile.** Windows `.venv` (3.13.7), WSL `/tmp/pgv`
   (3.12, `uv pip` only — `frontmatter`/`yaml`/`numpy` hand-installed), WSL
   `/tmp/cocotb19` (3.12). No `requirements.txt` pins any of them.
5. **Warning wall.** `parse_pbg_telemetry.py` prints 5 `WARNING: legacy scalar
   telemetry` lines (TKT-003..007 lack a `telemetry:` block). Harmless, but on a
   projector it reads as breakage.

---

## Severity ranking

| # | Finding | Present in locked baseline? | Blast radius | Caught by current tests? |
|---|---|---|---|---|
| **R1** | Unreset / write-coverage-free SRAM → silent garbage on partial tiles | **Yes** | Every non-power-of-two-K matmul; all of TKT-017 | No (shared model) |
| **R2** | Reconstruction proof assumes a perfect optical channel | **Yes** (proof scope) | All of TKT-019; any live optical demo | No (lossless DPI) |
| **R3** | Scavenger launders transient/biased reads into trusted artifacts | **Yes** | Every downstream RAG/KG consumer | No |
| **Y1** | Single-clock / no-SDC / combinational `max_reduce` / never synthesised at size | **Yes** | All of TKT-018 | N/A (no PD flow yet) |
| **Y2** | Win/WSL split, ephemeral git-divergent DB, silent-skip visuals | **Yes** | Every live demo | N/A |

---

## Most dangerous finding — each persona

### Red Team — R1: silent SRAM corruption on partial loads

It is **already in the locked baseline**, it is **silent** (0 in sim, random in
silicon — no crash, no X-assert), the Cocotb suite is **structurally blind** to
it because the TB and DUT share a model that never has an unwritten address, and
it becomes load-bearing the moment TKT-017 streams a real transformer tile whose
K dimension isn't a clean multiple of `K_MAX`. A demo of "bit-exact GEMM" could
show a wrong number that looks converged. **Gate:** add reset + a
write-coverage `assert` + a directed short-load test *before* TKT-017 starts.

### Yellow Team — Y2.1 + Y2.3: the demo substrate fails silently as success

`build_visuals.py` exits 0 and serves stale SVGs when its WSL toolchain isn't
present, and the entire Cyclopter KG runs on a `/tmp` pgserver whose actual
migration isn't the committed one and doesn't survive a reboot. Both are
"looks-fine-until-it-doesn't" on exactly the machine and day it matters. **Gate:**
a `make doctor` preflight that hard-fails (non-zero, loud) on any missing tool
or a stale `outputs/`, and a committed, reproducible DB bring-up
(`docker`-free script + the *real* migration reconciled into git) before any
Epic demo is scheduled.

---

## Recommended gate tickets (before TKT-017/018/019)

1. **TKT-017 gate:** `gcb_sram_sp1w1r` reset + per-bank write-coverage assert +
   short-load directed test (closes R1).
2. **TKT-019 gate:** non-ideal optical channel model + BER/eye harness +
   operand-block integrity check + explicit `>>> 2` rounding / saturating cast
   (closes R2).
3. **TKT-018 gate:** first real SDC + a single-clock-domain declaration, a
   `REG_STAGES` timing study for `gcb_max_reduce`, and one full-geometry Yosys
   run before OpenROAD (closes Y1 items 1/2/4).
4. **Cross-cutting:** scavenger frontmatter/corpus validation + non-date noise
   seed (closes R3); `make doctor` preflight + committed reproducible DB
   bring-up (closes Y2).

---
## Execution Log

### Audit (assessment only — no code/RTL change)
* **Auditor:** dual-persona (Red / Yellow), session `01Rpa9VJGe7xypzp5FkukSco`.
* **Inputs reviewed:** `gcb_sram_sp1w1r.sv`, `gcb_tensor_operand_sram.sv`,
  `gcb_tensor_sram_controller.sv`, `gcb_max_reduce.sv`,
  `gcb_rx_digital_recombiner.sv` (+ dual-mode top), `cyclopter_scavenger.py`,
  `build_visuals.py`, `render/digitaljs_render.mjs`, Doc 09/12 telemetry + SRAM
  strategy.

### R1 hotfix — SRAM X-state / write-coverage (Hardening Sprint, session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-09)

**Status: R1 patched and verified at the RTL level.** `hardware-silicon`
workspace; `gcb-wdm-transceiver` only. Not committed (Release Engineer to lock).

**RTL patches** (all new logic guarded `` `ifdef SIMULATION `` → compiled out of
`sim/lint.sh` and the `sv2v`→Yosys path; no frozen interface touched, no new
port, no reset added to the macro):

* `rtl/gcb_sram_sp1w1r.sv` — simulation-only power-up **poison** of `mem[]`.
  4-state signoff sim: literal `{DW{1'bx}}` so an unwritten read propagates X.
  Verilator (2-state, where `'x` folds to 0 and would re-hide the bug):
  `` `ifdef VERILATOR `` → an address-dependent non-zero sentinel `~(DW'(i))`
  (`0xFF…` at addr 0, then a ramp) so a never-written read is visibly wrong,
  never a plausible zero operand.
* `rtl/gcb_tensor_sram_controller.sv` — per-bank **write-coverage tracker** +
  assertion. `a_cov[bank][lane][macro-addr]` / `b_cov[…]` bitmaps: cleared for
  the non-resident (fill-target) bank on each load-request rising edge
  (prime + steady-state prefetch), set on every accepted write beat with the
  same `we` qualification and the exact `gcb_tensor_operand_sram` address math
  (`sub*K_STEPS + k` for B). Combinational `a_rd_covered` / `b_rd_covered`
  check all `GRID_DIM` lanes of the word the grid is addressing this cycle;
  on any issued read beat (`advancing`) of an uncovered word a sticky
  `cov_violation` latches, `cov_events` increments, and a non-stopping
  `%Error TKT-020/R1 …` line prints. The same condition is also written as a
  concurrent `assert property (advancing |-> a_rd_covered && b_rd_covered)`
  with `disable iff (!rst_n)` — live on an event-driven signoff simulator
  (Verilator `$stop`s on a failing SVA, so the Cocotb proof keys on the
  `cov_violation` / `cov_events` flags instead).

**Directed test** — `sim/cocotb/test_operand_sram.py` (+ new
`sram_partial_load_tb_top.sv`, `Makefile.sram_partial`; the module now hosts
two test sets selected by `GCB_SRAM_TB`). Tiny controller geometry
`GRID_DIM=2, K_MAX=2, K_STEPS=4, N_SUBTILES=2, M_BANDS=2, N_PASSES=1`:

* `partial_load_read_unwritten_hardfails` — the A loader writes only
  `K_STEPS-1` of `K_STEPS` beats for `(band 0, row 0)` (omits `k=3`) but still
  pulses `a_load_done`; B is fully loaded. Result: on the first grid read of
  macro-addr 3 the guard fires — **`cov_violation=1`, `cov_events=2`,
  `%Error TKT-020/R1 @78000 … A bank 1 maddr 3 covered=0` in the log** —
  instead of the pre-fix silent `0`. **PASS.**
* `full_load_no_coverage_violation` — conformant loader writes every address;
  the full sequence completes, `done` pulses, `cov_violation=0`,
  `cov_events=0` (no false positive). **PASS.**

**Verification run (WSL, Verilator 5.032, cocotb 1.9.2):**

| Check | Result |
|---|---|
| `make -f Makefile.sram_partial` | `TESTS=5 PASS=2 FAIL=0 SKIP=3` (2 controller tests pass; 3 array tests skip) |
| `make -f Makefile.sram` (regression) | `TESTS=5 PASS=3 FAIL=0 SKIP=2` (3 array tests unchanged; 2 controller tests skip) |
| `make -f Makefile.max_reduce` (regression) | `TESTS=5 PASS=5 FAIL=0` |
| `make` / `dma_tb_top` (regression — instantiates the controller with `-DSIMULATION`) | `TESTS=2 PASS=2 FAIL=0`, coverage guard silent on the conformant flow |
| `bash sim/lint.sh` | `lint OK`, exit 0 (28 tops; SIMULATION blocks invisible to lint) |
| `sv2v` → Yosys `hierarchy -check` + `proc` + `check -assert` (all 3 modules) | OK — synth view unchanged (guarded blocks absent) |
| Yosys `synth -flatten` + `select -assert-count 0 t:$dlatch/$dlatchsr/$sr` | latch-free |

**Also wired:** the new harness into `sim/run_tb.sh` (guarded cocotb stanza,
after the operand-SRAM one) and `.gitignore` (`sim_build_sram_partial/`,
`results_sram_partial.xml`).

**Files touched:** `gcb-wdm-transceiver/rtl/gcb_sram_sp1w1r.sv`,
`rtl/gcb_tensor_sram_controller.sv`, `sim/cocotb/test_operand_sram.py`,
`sim/cocotb/sram_partial_load_tb_top.sv` (new),
`sim/cocotb/Makefile.sram_partial` (new), `sim/run_tb.sh`, `.gitignore`.

### Y2 hotfix — presentation-environment hardening (Hardening Sprint, session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-09)

**Status: Y2 patched and verified with two new presentation scripts.**
`software-control` workspace; `gcb-dashboard` + `gcb-python-orchestrator`. Not
committed (Release Engineer to lock).

**Y2.1 / Y2.2 — silent-skip visuals → `gcb-dashboard/Makefile` (new) with a
`doctor` preflight.** `make doctor` refuses to let a demo start on a broken
render substrate: it exits non-zero (recipe `exit 1`; `make` surfaces it) with a
coloured, readable `FAIL` line on any of —

1. **`sv2v` / `yosys` / `node` not on `$PATH`** — the headless DigitalJS
   pipeline can't run (the message points at the WSL toolchain).
2. **`node_modules/` absent, or missing `node_modules/yosys2digitaljs` /
   `node_modules/elkjs`** — tells the user to run `npm ci` (matches
   `build_visuals.py::is_available`).
3. **`outputs/` missing or empty of `*.svg`** — visuals never generated.
4. **`outputs/` stale** — newest `*.sv` / `*.v` under the render-input dirs is
   newer than the oldest generated SVG; prints the offending RTL file and the
   lag in seconds, then fails.

   *Discrepancy vs. the relayed prompt:* the prompt named
   `../gcb-wdm-transceiver/rtl/` as the staleness source, but `build_visuals.py`
   provably reads only `../gcb-rtl/rtl`, `../gcb-rtl/rtl/generated` and
   `../gcb-photonic-qam-v2/rtl` (its `outputs/` are `greencoyote_*` +
   `gcb_qam_*`, nothing from wdm-transceiver). Including wdm-transceiver/rtl in
   the fatal check would false-`STALE` on every wdm RTL edit — e.g. today's R1
   SRAM patch. The default `RTL_DIRS` is therefore the three real inputs;
   `make doctor RTL_DIRS="… ../gcb-wdm-transceiver/rtl"` re-adds it if the
   dashboard ever renders those tops.

   *Verified (WSL, sv2v 0.0.12 / Yosys 0.52 / node 22.22):* clean tree →
   `doctor: OK`, exit 0. Forced-fail paths all exit non-zero with the right
   message — PATH without `sv2v`; `touch ../gcb-rtl/rtl/greencoyote_top.sv` →
   `stale newest RTL: …/greencoyote_top.sv` → `FAIL … outputs/ is STALE`
   (mtime restored after, `gcb-rtl` left clean). `make visuals` runs `doctor`
   then `python3 build_visuals.py`.

**Y2.3 / Y2.4 — ephemeral, git-divergent KG DB →
`gcb-python-orchestrator/deploy/cyclopter/db_up.sh` (new).** One-click,
repeatable, documented bring-up that uses the **committed, unmodified**
migration — no more `/tmp` `pgserver` with a hand-patched `vector_norm()`
`vec_norm` expression:

1. resolves a Compose driver (`docker compose` v2 or `docker-compose` v1; loud
   `die` with the no-Docker fallback if neither);
2. `compose -f deploy/cyclopter/docker-compose.yml up -d`
   (`pgvector/pgvector:pg16`, host `5433`); creates `.env` from `.env.example`
   if absent so `load_telemetry_pg.py`'s DSN resolution matches;
3. polls `docker inspect -f '{{.State.Health.Status}}'` until `healthy`
   (90 s timeout, points at `compose … logs` on failure);
4. **applies `migrations/001_pbg_telemetry.sql` verbatim** via
   `docker exec -i cyclopter-db psql -v ON_ERROR_STOP=1 -f -` — the pg16 image
   has full pgvector, so the Doc 09 `telemetry_vec[i]` STORED `vec_norm`
   expression runs exactly as checked in;
5. verifies `extension vector` + `to_regclass('pbg_telemetry')` +
   `is_generated='ALWAYS'` on `vec_norm` + both HNSW indexes, `die`-ing if any
   is absent;
6. `--load` optionally runs `parse_pbg_telemetry.py` + `load_telemetry_pg.py`
   (venv python preferred) for a full data + KNN bring-up; `--down` /
   `--wipe` are the teardown modes.

   Idempotent (`compose up -d` no-op if up; migration is all
   `CREATE … IF NOT EXISTS`). *Verification limit:* this workstation has **no
   Docker** (the very condition Y2.3 documents), so `db_up.sh` is verified by
   `bash -n` (syntax clean) + line-by-line inspection + confirmed clean `die`
   (exit 1) when `docker` is absent; the committed SQL it applies is the same
   file `load_telemetry_pg.py` already applies successfully against pgvector.
   `deploy/cyclopter/README.md` bring-up section updated to point at it.

**Files touched:** `gcb-dashboard/Makefile` (new);
`gcb-python-orchestrator/deploy/cyclopter/db_up.sh` (new),
`deploy/cyclopter/README.md`.

---
## Telemetry & Evaluation
*(To be populated if this audit is itself graded)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
