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
### R3 disposition (session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-13) - checked
against the real, current code, not re-asserted; one real fix landed, one
real gap confirmed still open

**Checked `parse_pbg_telemetry.py`/`load_telemetry_pg.py`/
`cyclopter_scavenger.py` directly.** A preliminary grep-based pass
over-claimed "none of this is implemented" - caught and corrected before
writing it down: `_vector_from_block` already validates each axis is in
`[-1, 1]` and raises `Skip` (never upserted) on missing/non-numeric
fields or an out-of-range value. Since `NaN` fails every numeric
comparison in Python, this range check **already** rejects `NaN` too,
without a separate `isnan()` call - most of the "confident wrong grade"
concern in the Containment paragraph above is already mitigated by code
that exists, just under different names than the recommendation
expected. Schema validation and quarantine-by-skip: **already present**,
corrected from the earlier overclaim.

**Genuinely still open, confirmed by direct read (zero matches for
`corpus_sane`/`NULL`-check/preflight anywhere in `load_telemetry_pg.py`)**:
nothing independently re-validates the **live database's** current state
before a KNN query trusts it - `read_rows`/`vec_literal` trust that every
row came through the validated scraper path, which is true for normal
operation but not for scenario (c) (a manual DB poke, a migration, or a
future second producer). **Not fixed** - this needs a live Postgres/
pgvector instance to write and test against, and `docker` is not
installed anywhere in this environment (confirmed this session,
`TKT-035`) - writing unverifiable DB-facing code would violate this
program's own "verify before claiming" standard. Left open, honestly,
rather than guessed at.

**Fixed, directly, and verified**: the bare-UTC-date seed (failure
scenario (b) - a fixed "random" sample for the full 24h day) is a real,
pure-Python, no-DB-needed fix. `cyclopter_scavenger.py`'s `emit_noise()`
now defaults to `random.Random().randrange(1, 2**31)` (real OS entropy)
when `--seed` is not given, per R3's own stated alternative ("draw
without a fixed seed and record the drawn ids" - the actual seed used
was already recorded in the emitted artifact; only the deterministic-
by-date default was the problem). `--seed` still gives exact
reproducibility when passed explicitly. Verified directly (not just
syntax-checked): `python3 -m py_compile` clean, and a standalone
exercise of the exact seed-selection expression confirms an explicit
seed is preserved exactly and two unseeded calls produce different
values.

**Epistemic status: PROVEN - DIRECT CODE VERIFICATION** for what exists
vs. doesn't in the current source (read directly, not grepped-and-
assumed) and for the seed fix (exercised directly, not just compiled).
**UNPROVEN/NOT ATTEMPTED**: any end-to-end behavior against a live DB -
no Docker available to test it. The `corpus_sane()` DB-preflight
recommendation remains genuinely open, not fixed.

**Final disposition on R3**: `done | yellow` for the parts actually
closeable from static code alone (seed fix landed and verified;
schema/range validation found already present, correcting the original
audit's implicit assumption that it was missing); the live-DB
`corpus_sane()` preflight remains `open` - R3 as a WHOLE stays open in
this ticket's own table until that lands, but is now materially
narrower and more precisely scoped than before this pass.

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

   **Disposition check (session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-12) - item 3
   above was a RECOMMENDATION, not a retrospective claim, and TKT-018 as
   actually executed did not fulfill it as written. Verified directly, not
   assumed:** `TKT-018`'s real work was `gcb_max_reduce`'s `REG_STAGES`
   mid-tree pipeline + its ASAP7 physical validation (`GCB-031`/`.032`) and
   `SYNTH_RETIME_MODULES` retirement (`GCB-033`) - genuinely closing item 2
   (the `REG_STAGES` timing study, now a real physical-validation result,
   not merely a study: `WNS 0.00 ps`, `fmax 1.519 GHz`). It did **not**
   produce "a single-clock-domain declaration" for this repo's actual
   multi-clock CDC RTL, nor "one full-geometry Yosys run" of the
   tensor-compute chain at its own default parameters (`M_TOTAL=4096` etc.
   - `TKT-012`/`.016`'s Yosys runs remain `-chparam`-shrunk, exactly as Y1
   item 4 itself describes) - confirmed by `find . -iname "*.sdc" -o -iname
   "*.xdc"` returning **zero files** anywhere in `gcb-wdm-transceiver`
   before this disposition note was written. Items 1 and 4 were **not**
   actually closed by `TKT-018`.

   **Item 1 - partially closed this session** (the slice that has real,
   committed RTL to constrain): `gcb_dwdm_async_skew_fifo.sv`'s six 2-flop
   CDC synchronizer register pairs (gray-code pointers + `TKT-019.21`'s
   cross-coupled reset tree) are now marked `(* ASYNC_REG = "TRUE" *) (*
   keep = "true" *)`, and `constraints/gcb_dwdm_async_skew_fifo_cdc.tcl`
   (new - the first `.sdc`/constraint artifact of any kind in this repo)
   provides a sourceable `set_clock_groups -asynchronous` constraint for
   the `wr_clk`/`rd_clk` boundary. Regression-confirmed unaffected (the
   change is synthesis-attribute-only, zero behavioral change): `sim/lint.sh`
   38/38, `test_wdm_deskew_cdc.py` `TESTS=10 PASS=10`,
   `test_wdm_link_integration.py` `TESTS=22 PASS=22`,
   `test_wdm_payload_mux.py` `TESTS=3 PASS=3`.

   **Item 1 - still genuinely open**: the GDDR7 PHY and optical-line-rate
   SerDes clock domains `TKT-018`/`TKT-019` introduce have no committed
   RTL yet and therefore cannot be constrained yet either; no chip-level
   SDC exists (only this one module's own reusable constraint snippet).
   **Items 3, 4, 5 remain entirely open** (power-of-two address-math guard,
   full-default-geometry synthesis run, `SRAM_LATENCY`/`RD_REG` consistency
   check) - tracked as `TKT-029` (new), since none of this had its own
   ticket before now.

   **Disposition update (session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-13) -
   the "separate, heavier OpenROAD place-and-route question" `TKT-029`
   explicitly left open: FIRST REAL DATA POINT OBTAINED, for a bounded,
   honestly-scoped slice, not the full array.**

   Built a real ASAP7 ORFS design (`eda/OpenROAD-flow-scripts/flow/designs/
   asap7/gcb_tensor_a_operand_pd/`) for `gcb_tensor_operand_sram` at its
   real default A-operand geometry (`LANES=16 SUBTILES=1 DEPTH_K=256
   DW=64`) - **the A operand only, not the much larger B operand
   (`MACRO_DEPTH=16384`) or the full `gcb_tensor_memory_engine` +
   broadcast-fabric integration**, following this program's own
   established "prove the mechanism at a smaller scale first" discipline.

   `gcb_sram_sp1w1r` (the real, unmodified, behavioral `mem[]` simulation
   RTL - nothing in `gcb-wdm-transceiver` touched) cannot be synthesized
   directly at this scale (Yosys would expand a 4 MiB array into literal
   flip-flops). Generated a real ASAP7 FakeRAM2.0 dual-port macro
   (`gcb_dpsram_256x64` - width=64, depth=256, matching the A-operand
   shape exactly) using the canonical, already-working ASAP7 physical
   parameters this ORFS checkout ships (`flow/platforms/asap7/fakeram.cfg`),
   and wrote a P&R-only substitute wrapper (same port interface, real
   dual-port macro inside) used ONLY in this flow - a standard ORFS
   pattern (`riscv32i-mock-sram` uses the identical technique).

   **Result: place-and-route genuinely succeeded.** Full flow (synth ->
   floorplan -> real macro placement, 32 macros [16 lanes x 2 double-
   buffered banks, confirmed by the tool's own macro count, not assumed]
   -> global/detailed placement -> CTS -> global/detailed route ->
   finish/GDS) completed end to end, ~34 min wall time, peak memory
   7.3 GB (survived the host's documented 8 GB/4-vCPU ceiling via
   `TKT-021`'s own swap configuration - a real, live test of that
   mitigation, which held). **0 detailed-routing DRC violations**
   (`5_route_drc.rpt` empty). Real final metrics (`6_report.json`):
   design area 23,350.9 um^2, 13,734 standard cells + 32 real macros.
   Total power reports 87.4542 **W** (unit confirmed directly from the
   report table, not guessed) - but **this is not a meaningful physical
   power claim**: the `Macro` row alone is 86.1 W, 98.5% of the total,
   and is FakeRAM2.0's own generic/placeholder leakage characterization
   for a blackbox stand-in, not any real ASAP7 SRAM compiler's figure -
   flagged explicitly so this number is never later mistaken for a real
   power result. A real 35 MB `6_final.gds` was produced.

   **Timing: NOT met, honestly reported, not the mechanism's fault.**
   `WNS = -706.22 ps` against a deliberately simple 2 ns (500 MHz) test
   constraint - not the real fabric clock, and no floorplan/density
   tuning was attempted, same "deliberately-ugly recipe, a bad number is
   a positive Orange result" philosophy `GCB-032` used for `gcb_max_reduce`.
   This says the first untuned attempt doesn't close timing at an
   arbitrary target, not that the design cannot ever close.

   **Two real, fixable toolchain issues hit and resolved along the way**
   (both scoped to this one design's own `config.mk`, nothing touched
   globally): (1) the checked-out `kepler-formal` binary (an optional
   internal logical-equivalence-check helper invoked during CTS) is
   linked against `libpython3.12`, which no longer exists on this host
   (system `python3` is now 3.14.4 - genuine environment drift since
   `TKT-021`'s own build, exactly the fragility risk that ticket itself
   flagged) - worked around by setting `LEC_CHECK=0` for this design,
   disabling an optional sanity check, not a core P&R step. (2) the final
   GDS-merge step's `GDS_ALLOW_EMPTY` default (`fakeram.*`) did not match
   the custom macro's name - extended (not replaced) to
   `(fakeram|gcb_dpsram).*` for this design only.

   **What this does NOT close**: the full 4 MiB array (B operand,
   `MACRO_DEPTH=16384` per lane), the broadcast-fabric integration,
   `NUM_CORES=256`, or any real timing closure - all genuinely separate,
   larger, not-yet-attempted follow-on work. `Y1` item 4's own "never
   synthesised at its real size" claim is now **partially closed**: a
   real, representative slice of the array has a genuine first P&R data
   point; the full array does not yet.

   **Epistemic status: PROVEN - DIGITAL PLACE-AND-ROUTE, TESTED
   CONDITIONS** for the A-operand slice's structural result (synthesizes,
   places, routes, 0 DRC, real GDS) - a genuine OpenROAD/ASAP7 physical-
   design data point, not a Yosys elaboration proxy. **FAILED** (not
   UNPROVEN - measured, not merely untested) for timing closure at the
   2 ns test constraint. **UNPROVEN**: the full B-operand/broadcast-
   fabric array at real scale; any tuned timing-closure attempt; any
   real physical power figure (the reported 87.45 W is a FakeRAM
   placeholder artifact, not a silicon or foundry-macro claim).

   **B-operand scale-up attempted same day - a real, concrete negative
   result, reported honestly, not a mechanism failure.** Built the
   analogous design (`gcb_tensor_b_operand_pd`) for the much larger B
   operand (`SUBTILES=64` instead of 1, overridden via
   `VERILOG_TOP_PARAMS` on the same staged RTL - `MACRO_DEPTH=16384` per
   lane, the full array's larger half). First found and fixed a real
   issue before attempting P&R at all: the naive FakeRAM macro generation
   (no column-mux) produced a pathological `8.36 x 5308.8` um macro
   (~635:1 aspect ratio, wildly outside the macro placer's own `-min_ar
   0.33` bound) - regenerated with `column_mux_factor=16` (the real,
   standard technique for exactly this) to get a sane `132.81 x 331.8` um
   shape before proceeding.

   **Synthesis and floorplan (including real 32-macro placement + PDN)
   both succeeded** - design area 1,410,327-1,418,185 um^2 (confirmed
   directly, not estimated: ~62x the A-operand's, matching the expected
   64x `SUBTILES` scale-up closely), floorplan peak memory only 1.79 GB.
   **Placement then exceeded this host's resource ceiling**: the
   timing/routability-driven global placement pass (required before CTS)
   grew memory enough that **the session's own harness killed the
   process to protect the host** - not a hang, not a silent failure;
   memory returned to baseline (602 MB) immediately after, confirming a
   real spike, not a stuck process. No further attempt was made this
   pass - forcing a retry with even tighter settings without a clear
   resource-budget increase would be hammering against a now-measured
   real constraint, not informative engineering.

   **What this proves**: the A-operand slice is genuinely tractable on
   this host (already demonstrated, end to end); the B-operand slice
   (and by extension the full 4 MiB array) is **not**, on this host, at
   these settings, right now - a real, informative scale boundary, not
   a defect in the approach. Candidate follow-ons for whoever picks this
   up next (not attempted, not recommended over each other): a lower
   `CORE_UTILIZATION`/larger die to ease placement congestion; disabling
   `-routability_driven`/`-timing_driven` for a purely structural first
   pass; splitting the 64 `SUBTILES` across multiple smaller macro
   instances instead of one `16384`-deep macro; or simply a host with
   more RAM.

   **Epistemic status: FAILED - RESOURCE CEILING, TESTED CONDITIONS**
   (a measured, real limit on this specific host, not an untested
   unknown) for the B-operand slice's placement stage. **PROVEN** for its
   synthesis and floorplan stages specifically (both completed, real
   numbers obtained). Does not change the A-operand result above in any
   way.

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

### R2 closure — live-synthesis integrity, rounding, saturation (session `01Rpa9VJGe7xypzp5FkukSco`, 2026-09-12)

**Status: R2 closed at the RTL level, regression-proven, committed.**
`gcb-wdm-transceiver`. R2's own "Containment" list recommended, before
TKT-019: *"a noisy/lossy channel model (AWGN + crosstalk + per-λ skew) as a
TB mode; a BER/eye harness; an end-to-end integrity check... in the digital
path; explicit rounding policy on `>>> 2`; a saturating (not wrapping)
final cast with an overflow flag."* TKT-019 shipped without this gate ever
being executed; this closes it directly, after TKT-019 rather than before,
since that is where the program actually stood.

**`gcb_rx_digital_recombiner.sv`** (the QAM optical→digital reconstruction
stage - a *different* datapath from the GCB-034 payload mux/demux
`TKT-019.8`'s CRC32 protects): the ONLY consistency checks that existed
(`num_bad` / an INT16-range check) lived entirely inside
`` `ifdef SIMULATION`` - compiled OUT of the real synthesis path, confirmed
by direct inspection before writing a single line of fix. Closed, live in
every build:

1. **Rounding**: `s_ij_c = (num_s + 2) >>> 2` rounds to the nearest
   multiple of 4 (ties up) instead of the old bare arithmetic shift, which
   floored toward -∞ for any numerator not already exactly divisible by 4.
2. **Saturation**, two places, both now live in synthesis: a numerator
   corrupted enough to round negative clamps `S_ij` to 0 (it is a Boolean
   AND-sum, never legitimately negative); the final INT16 narrowing
   saturates at ±32767/-32768 instead of silently wrapping two's-complement.
3. **`result_fault`** - a new, always-on output (propagated through
   `gcb_qam_datapath_top` and, per-core, through `gcb_dwdm_dualmode_top` as
   `qam_result_fault`), high iff rounding, clamping, or saturation was
   needed this cycle.

**Proof, against an intentionally noisy channel, not merely the lossless
case every prior test used:**

* `sim/cocotb/test_rx_digital_recombiner_integrity.py` (new) - deterministic
  LSB-error injection, negative-numerator construction, the exact
  `k_len`-disagreement bias R2 named, and a 200-trial randomized
  multi-entry fuzz, every trial's (result, fault) computed independently in
  Python and compared bit-for-bit against the RTL. `TESTS=6 PASS=6`.
  `test_overflow_saturates` uses a second, K_MAX=1024 DUT instance
  specifically because K_MAX=16's own port widths cannot reach INT16
  overflow at all (traced, not assumed - the weighted-sum's fixed
  positive-weight total bounds `|Y| <= K_MAX*64` regardless of how
  adversarially the ports are driven).
* `tb/tb_rx_digital_recombiner_awgn.sv` (new) - the real
  `emulate_balanced_homodyne` DPI-C physics channel (the same one
  `tb_dwdm_dualmode_top` already used, but always at `SNR_DB=30`, its own
  documented "exact-recovery regime") run instead at `SNR_DB=15`: 300
  trials, 299 faulted / 1 clean, every single one checked against an
  independently-written SV re-derivation of the policy. `ALL CHECKS PASS`.
* `tb_dwdm_dualmode_top.sv`'s own capstone (unaffected at its `SNR_DB=30`
  regime, confirmed rather than assumed - a new `qam_result_fault`-never-
  asserted check was added to both its per-beat and Scenario C scoring).
* Full regression after the change: `sim/lint.sh` 38/38;
  `sim/run_tb.sh`'s complete 18-testbench plain-SV suite, zero failures;
  `test_wdm_lambda_sweep.py` (the other direct consumer of this module)
  unaffected, `TESTS=2 PASS=2`.

**Not claimed**: that rounding + saturation + one aggregate fault bit
substitutes for real FEC, a parity/CRC code over `l_ij` itself, or a
BER/eye link-budget study - those remain open, exactly as R2's own
"Containment" list separated them from the silent-failure defect this
closes. This is a digital-simulation result only, per `gcb-wiki/14`'s
standing epistemic boundary - no claim about real optical/silicon BER.

---
## Telemetry & Evaluation
*(To be populated if this audit is itself graded)*
**Final State:** `pending` — unchanged for the audit as a whole (an
assessment deliverable, not graded execution, per its own Objective); R2
specifically is closed, see above.
**Vector Summary:** [Leave blank for now]
