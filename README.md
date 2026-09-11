# gcb-workspaces

Single source of truth for the two things that span every GreenCoyote-Bay
repository but belong in none of them:

1. **Developer context boundaries** — the VS Code multi-root workspaces that
   group the ~14 `gcb-*` repos into the three domains an engineer actually works
   in at one time.
2. **PBG telemetry** — the engineering backlog: architectural-requirement
   tickets, each carrying a Purple/Blue/Green/Yellow/Red/Light-gray evaluation
   of its execution options.

Keeping both here stops project-management state (tickets, telemetry, workspace
wiring) from polluting the silicon and software repos. Those repos hold only
their own artifact; this one holds the map and the plan.

## Layout

```
gcb-workspaces/
├── README.md
├── hardware-silicon.code-workspace       RTL, PIC, analog, WDM, dashboard
├── software-control.code-workspace       host stack + Python orchestrator
├── architecture-doctrine.code-workspace  spec, wiki, papers, grants, this repo
└── backlog/
    ├── TKT-000-orange-team-epoch-guidance.md   ← strategic doctrine (Physical Reality First)
    ├── TKT-001-netlistsvg-chip-scale-rendering.md
    ├── TKT-002-opcode-dispatcher-wiring.md
    ├── TKT-003-tensor-memory-addressing.md
    ├── TKT-004-address-translation-trade-study.md
    ├── TKT-005-pbg-vector-math.md
    ├── TKT-006-dispatcher-reserved-byte-plumbing.md
    ├── TKT-007-pbg-telemetry-scraper.md
    ├── TKT-008-gddr7-dma-engine-scoping.md
    ├── TKT-009-gddr7-dma-rtl-implementation.md
    ├── TKT-010-dma-jinja2-generator.md
    ├── TKT-011-cyclopter-pgvector-integration.md
    ├── TKT-012-tensor-memory-engine-sram-controller.md
    ├── TKT-013-cyclopter-scavenger-agent.md
    ├── TKT-014-knowledge-graph-gap-analysis-research.md
    ├── TKT-014-FINDINGS.md
    ├── TKT-015-bitplane-tx-mapper-doctrine.md
    ├── TKT-016-shared-max-reduce-macro.md
    ├── TKT-017-epic-compute-execution-units.md
    ├── TKT-018-epic-openroad-physical-layout.md
    ├── TKT-019-epic-optical-wdm-transport.md
    ├── TKT-020-red-yellow-audit.md
    ├── TKT-021-openroad-wsl-toolchain-compilation.md
    ├── TKT-022-mac-tile-array.md
    ├── TKT-023-tile-requantize.md
    ├── TKT-024-operand-staging.md
    ├── TKT-025-compute-e2e-integration.md
    ├── GCB-026-namespace-migration.md          ← GCB-### namespace cutover
    ├── GCB-027-max-reduce-physical-measurement.md
    ├── GCB-027-FINDINGS.md                      ← first physical measurement (Orange)
    ├── GCB-028-max-reduce-pipeline-integration.md
    ├── GCB-029-max-reduce-physical-validation.md
    ├── GCB-029-FINDINGS.md                      ← GCB-027 vs GCB-029 transfer function
    ├── GCB-030-max-reduce-retiming-remeasure.md
    ├── GCB-030-FINDINGS.md                      ← retiming closes it, at 818 flops
    ├── GCB-031-max-reduce-midtree-pipeline.md   ← RTL response: mid-tree pipeline cuts (no retiming)
    ├── GCB-032-max-reduce-midtree-physical-validation.md
    ├── GCB-032-FINDINGS.md                      ← mid-tree closes 1 ns w/o retiming, 372 flops
    ├── GCB-033-retire-synth-retime-consolidate-ppa.md  ← retiming retired, PPA burn-down rolled up
    ├── GCB-034-optical-transport-contract.md    ← EPIC TKT-019 Story 1: the ratified dual-regime transport contract (done|green)
    ├── GCB-034-LOOK-AROUND.md                   ← orthogonal-discovery pass: constraints D4 full-K-local silently accepts
    ├── GCB-035-optical-line-rate-derivation.md  ← TKT-019 V1+V2: Alt A ≈2.4 Gbps vs Alt B ≈17.9·P Gbps
    ├── GCB-036-out-w-numeric-consequences.md    ← TKT-019 V3: INT4 fails the 25 dB budget → D2 provisionally INT8
    ├── GCB-037-optical-link-budget.md           ← TKT-019 V4: Alt A closes on 1 λ; Alt B needs ≈60 λ; KP4 load-bearing
    ├── GCB-038-partitioning-constraints.md      ← TKT-019 V5: full-K-local K ceiling ≈45k → D4 is a mode; Falsification Test complete
    ├── TKT-019.1-lambda-count-parameterisation.md  ← EPIC TKT-019 build story 1: gcb_wavelength_router N_LAMBDA=2..64, doc-13 bit-exact (done|blue)
    ├── TKT-019.3-dwdm-deskew-scaling.md          ← EPIC TKT-019 story 3 (re-prioritised ahead of .2): deskew FIFO depth + CDC characterisation for Mode B, gcb_dwdm_deskew_cdc built (done|blue)
    ├── TKT-019.2-dwdm-payload-muxing.md          ← EPIC TKT-019 story 2 (resumed after .3): GCB-034 logical payload muxing onto color_word_t, gcb_dwdm_payload_mux/demux built (done|blue)
    ├── TKT-019.4-top-level-link-integration.md   ← EPIC TKT-019 story 4: mux->[channel]->CDC-deskew->demux composed, 5-vector Orange-Team digital-only stress test (done|blue)
    └── TKT-019.5-transport-failure-semantics.md  ← EPIC TKT-019 story 5: Orange architectural audit — Ghost Payload epoch contamination CONFIRMED, REQ-TX-* requirements extracted, no mitigation selected (done, no PBG grade)
```
(Physical-measurement artifacts — `report.json`, layout PNGs, ORFS config, curated
reports — live under `eda/GCB-0NN/` per run; `eda/gcb_max_reduce/` is the standing
ORFS/ASAP7 config for that block (GCB-033); full P&R outputs stay in the isolated
P&R environment, out of git, per [[TKT-000]].)

## Workspaces

All three bind sibling repositories by **relative path** (`../gcb-*`), so a
clone of the full `gcb-*` set under one parent directory resolves them with no
per-machine path edits.

| Workspace | Bound repos | For |
|---|---|---|
| `hardware-silicon` | gcb-rtl, gcb-photonic-qam-v2, gcb-pic-core, gcb-analog-rx, gcb-wdm-transceiver, gcb-dashboard | RTL / photonic / analog design and hardware visualization |
| `software-control` | gcb-host, gcb-python-orchestrator | host-side control plane and orchestration |
| `architecture-doctrine` | gcb-spec, gcb-wiki, gcb-papers, gcb-grants, gcb-workspaces | specification, documentation, publications, funding, and this backlog |

Open one with **File → Open Workspace from File…**, or `code <name>.code-workspace`.

Each workspace also carries its own `launch` configurations and `tasks` tuned to
that domain (visualization / RTL lint for `hardware-silicon`, orchestrator debug
and control-plane `pytest` for `software-control`, PBG telemetry parsing and
Markdown lint for `architecture-doctrine`).

### Recommended extensions

Every workspace declares an `extensions.recommendations` list scoped to its
engineering domain. The first time you open a workspace, VS Code shows a
notification offering to install exactly the extensions that domain needs — you
never hand-pick them, and a hardware engineer is never prompted to install
Markdown tooling (or vice versa). Run **Extensions: Show Recommended Extensions**
from the Command Palette to see or install them later.

| Workspace | Recommended extensions | Purpose |
|---|---|---|
| `hardware-silicon` | `mshr-h.veriloghdl`, `eirikpre.systemverilog`, `yosyshq.digitaljs`, `ms-python.python` | SystemVerilog/Verilog linting, DigitalJS schematic rendering, `build_visuals.py` |
| `software-control` | `ms-python.python`, `ms-python.vscode-pylance`, `ms-python.debugpy` | Python editing, type analysis, and debugging |
| `architecture-doctrine` | `davidanson.vscode-markdownlint`, `redhat.vscode-yaml`, `yzhang.markdown-all-in-one` | Markdown linting, YAML parsing for PBG ticket frontmatter, Markdown authoring |

## Backlog

Each `backlog/TKT-NNN-*.md` follows a fixed template:

- **Objective** — the engineering gap, stated concretely.
- **Context & Constraints** — current state, hard constraints, and the
  **AI Orchestration Priorities (PBG Evaluation)**: every execution option
  scored on the PBG taxonomy.
  - **Purple** — strategic net-new platform capability.
  - **Blue** — solid, sustainable engineering on the target architecture.
  - **Green** — the gap cleanly closed, in-spec, "done right".
  - **Yellow** — athletic / expedient workaround; unblocks now, drifts the
    architecture.
  - **Red** — brittle technical debt, high-maintenance, likely to regress.
  - **Light-gray** — low-signal, deferrable, or accept-the-limitation.
  - **Orange** *(PBG-O, [[TKT-000]])* — Physical Falsifiability: the deliverable's
    worth is a **measurement that can contradict an architectural assumption**
    (area, timing, congestion, power, DRC). Orthogonal to the R³ PBG axes; a
    "bad" number is a *positive* Orange result.
- **The "Green" Target** — the acceptance definition for a Green outcome.
- **Execution Log** — populated during execution (agent id, commands, artifacts).
- **Telemetry & Evaluation** — populated post-execution (final state, vector
  summary).

Frontmatter carries `id`, `status` (`open` → `in-progress` → `done`), and
`telemetry_color` (`pending` until the work is graded).

### GCB-### Namespace (current)

The enterprise Jira-style project key. **All work from `GCB-026` (2026-09-10)
forward uses the `GCB-###` prefix**, continuing the running counter. The legacy
`TKT-###` tickets below are the immutable Digital Compute Epoch record — not
renumbered, not re-committed (see [[GCB-026]]). EPIC ids `TKT-017` / `TKT-018` /
`TKT-019` keep their numbers; their child stories from `GCB-027` on are
`GCB-###`.

| Ticket | Title | Status | Color |
|---|---|---|---|
| GCB-026 | Namespace migration — deprecate the legacy `TKT-###` prefix, adopt the enterprise `GCB-###` project key | done | blue |
| GCB-027 | **Story 1 of the Measurement Epic (`TKT-018`)** — first unoptimized OpenROAD / ASAP7 pass of `gcb_max_reduce`: **TIMING-BOUND** (WNS −665 ps @ 1 ns; 619 µm²; 0 DRC). See `GCB-027-FINDINGS.md` + `eda/GCB-027/` | done | **orange** |
| GCB-028 | **Architecture-from-measurement (GCB-027 loop, CLOSED)** — `gcb_max_reduce` now instantiated `REG_STAGES=2` inside `gcb_tile_requantize` (`MAXRED_REG_STAGES`, default 2) + operand alignment; `test_compute_e2e.py` still 40/40 bit-exact with `stall_count == 0`; latch-free on Yosys 0.68 | done | green |
| GCB-029 | **Story 2 of the Measurement Epic (`TKT-018`)** — physical validation of the GCB-028 pipeline: same ASAP7 flow, `REG_STAGES=2`. Transfer function: **WNS −665 → −442 ps (+34 %)**, TNS −34 %, power −19 %, area +0.4 %; timing **still open** (output-only pipeline, no retiming). See `GCB-029-FINDINGS.md` | done | **orange** |
| GCB-030 | **Story 3 of the Measurement Epic (`TKT-018`)** — synth retiming enabled (one config line, RTL frozen): **WNS −442 → 0 ps, timing CLOSED**, cone broken into reg→reg segments — but retiming replicates 46 → **818 flops** (+63 % area, 57 slew DRVs). Points to a mid-tree pipelined RTL variant. See `GCB-030-FINDINGS.md` | done | **orange** |
| GCB-031 | **Architecture-from-measurement (GCB-030 loop)** — mid-tree pipelined `gcb_max_reduce`: `REG_STAGES>0` now places its registers *between* tournament levels (genvar-elaborated segments), **~442 flops** (N=64, REG_STAGES=2) vs GCB-030 retiming's 818 — no register replication, combinational cells unchanged. `REG_STAGES=0` byte-identical; `K`-cycle latency contract preserved → **no consumer edits**; `test_compute_e2e.py` 40/40 bit-exact, `stall_count == 0`; Yosys 0.68 latch-free (+ `max_reduce_p2` bless). Physical re-measure is GCB-032 | done | green |
| GCB-032 | **Story 4 of the Measurement Epic (`TKT-018`)** — physical validation of the GCB-031 mid-tree pipeline through the exact GCB-029 ASAP7 flow, **`SYNTH_RETIME_MODULES` unset**. **WNS 0.00 ps @ 1 ns, 0 setup violations, fmax 1.519 GHz — closes without retiming.** vs GCB-030 retiming: **372 flops (−54.5 %)**, synth area −29 %, power −23 %, wirelength −20 %, argmax cone intact; 38 max-slew DRVs remain (predicted 0 — falsified). 0 DRC. See `GCB-032-FINDINGS.md` + `eda/GCB-032/` | done | **orange** |
| GCB-033 | **Consolidation** — retired `SYNTH_RETIME_MODULES` for `gcb_max_reduce` (superseded by the GCB-031/032 mid-tree pipeline); promoted the GCB-032 config as the standing `eda/gcb_max_reduce/` P&R config; rolled the GCB-027 → GCB-032 physical arc + transfer function into `gcb-wdm-transceiver/docs/PPA_burndown.md`; "Resolved" note on `GCB-030-FINDINGS.md` + bless SUMMARY cross-link. Doc-only, no RTL change, no new flow run | done | green |
| GCB-034 | **Story 1 of EPIC `TKT-019` (Optical WDM Transport)** — the **ratified dual-regime Optical Transport Contract**, derived from the ASAP7 measurements and survived the TKT-019 V1–V5 Falsification Test. **D1** post-requantization · **D2** INT8/PER_ROW/RNE (V3 falsified INT4) · **D3** per-tile for `K ≥ ~2 k` / super-tile for small-`K` · **D4** selectable mode: **Mode A** full-K local (FFN throughput, ≈ 271 B, ≈ 4.74 Gbps, 1 λ, ≈ 432× compression) / **Mode B** K-split + INT32 partials (long-context `A·V` + latency-critical decode, ≈ 60 λ). PHY provisioned for Mode B. **Purple survived** (electrical compute domain as an enormous compression boundary). Graded `T = (+1.0, +1.0, +0.7)`; PBG-O flag `orange` (separate from the R³ grade) | done | green |
| GCB-034-LOOK-AROUND | **Orthogonal-discovery pass on GCB-034** — what architectural constraints we silently accept because the ~1000× compression looks so good (C1–C11). D4 deep-dive: strict full-K-local eliminates K-parallelism, sizes the node by the model not the fabric, serialises K-latency, and caps single-request horizontal scale — likely correct only as a *workload-class mode*, with Alternative B kept live. Feeds `TKT-019` V5 | open | pending |
| GCB-035 | **TKT-019 falsification V1 + V2** — payload bit-accounting and line-rate derivation. Alt A (post-requant, 140 B / `K_STEPS=512` @ 1 GHz): **2.19 Gbps raw → ≈ 2.4 Gbps** with 64b/66b + KP4 (9.14 % coding, carried at 12 %) → single ≤ 10 G lane. Alt B (INT32 partial, 1024 B): **16.0 Gbps raw → ≈ 17.9 Gbps** → 25 G-class lane; and **`~7.3·P×` per link, `~7.3·P²×` at the accumulator** once the K-split is real (P = 4 → 71.7 Gbps/link, 286 Gbps aggregate). V1 HOLDS; V2 HOLDS for FFN, conditional-fail for small-K layers → escalates D3 | open | pending |
| GCB-036 | **TKT-019 falsification V3** — numeric consequences of `OUT_W` (D2). INT4 block FP has only ~18 dB (~8×) usable in-block dynamic range; against a 25 dB SQNR budget it needs `r_max ≤ 1.56×` while real transformer activation blocks span 4–50× (outlier channels) → **V3 CONTRACT FAILS for INT4 as a general default**. **D2 → provisionally INT8, PER_ROW, RNE** (INT4 opt-in for QAT / verified-narrow-range). INT8 payload 143 B → **~271 B**, line rate 2.4 → **~4.7 Gbps** — still a single ≤ 10 G lane, ~0 dB optical-SNR penalty (spend baud not constellation). Purple compression ratio ~850× → **~432×** (hypothesis holds) | open | pending |
| GCB-037 | **TKT-019 falsification V4** — optical link budget vs the `gcb-wiki/13` 2-PAM/QPSK format + KP4. **Alt A (INT8, ~4.74 Gbps): LINK CLOSES on 1 λ** with +2.5…8 dB margin under integrated-photonics loss (13.5 dB) / sensitivity (−16 dBm) assumptions. **Alt B (K-split latency): does NOT close per-tile on 1 λ** (−3.3 dB at P=1 … −9.3 dB at P=4); closes only by spreading the 1024 B over **≈ 4·P λ per link → ≈ 60 λ at the P=4 accumulator** (~a full C-band comb). **KP4 is load-bearing** (6.05 dB — Alt A does not close without it); **2-PAM/QPSK only** (PAM4+ breaks closure). Dual-regime PHY is sized by the latency mode's ~60× λ count. V4 HOLDS (throughput) / HOLDS conditionally (latency) | open | pending |
| GCB-038 | **TKT-019 falsification V5 — partitioning constraints of D4 (full-K-local); completes the Falsification Test.** Per-node ceilings: accumulator not binding (`K ≤ ~16 M`); **SRAM residency binds at `K_TOTAL ≈ 45 k`** (8 MiB, `N_SUBTILES=20`); batch-1 decode ≈ 1.84 ms/FFN-block/token with **no K-parallel recovery lever** under full-K-local. Full-K-local **keeps** data + N-tensor + pipeline + expert parallelism, **loses** K-tensor + attention sequence parallelism. **V5 FAILS as a global law** — long-context attention `A·V` (≥ ~45 k) and latency-critical batch-1 decode force Alternative B — **HOLDS as a workload-class mode**. Contract **survives as a dual-regime contract**; `GCB-034` ready for Architect review to close | open | pending |
| TKT-019.1 | **EPIC `TKT-019` build story 1 — λ-count parameterisation.** `gcb_wavelength_router` now takes real `N_LAMBDA` (2..64) + `LAMBDA_MAP [4]` — pure permutation wiring (**0 logic cells** at every count, 3 `$adff` output banks); `N_LAMBDA = 2` + `'{0,0,1,1}` **bit-identical** to the old fixed 2-colour router; `gcb_qam_datapath_top` adapted (interface unchanged); `gcb_bitplane_tx_mapper` **frozen**. `gcb_dwdm_tx_packager` / `gcb_dwdm_deskew` were already `NUM_COLORS`-parameterised → verified at `NUM_COLORS=60`; `gcb_rx_digital_recombiner` is λ-agnostic. New cocotb `Makefile.wdm_lambda_sweep` **TESTS=2 PASS=2** (permutation exact + `gcb-wiki/13` `S_ij`/`Y` bit-exact through the RTL router + recombiner at `N_LAMBDA ∈ {2,4,8,16,32,48,60,64}`); `sim/run_tb.sh` full SV WDM regression green; Yosys 0.68 latch-free (`wavelength_router{,_l64}.stat`). Reusable `sim/cocotb/gcb_wdm_ref.py` | done | blue |
| TKT-019.3 | **EPIC `TKT-019` story 3 — DWDM deskew scaling (Architect re-prioritised ahead of TKT-019.2).** Orange-method characterisation of `gcb_dwdm_deskew` against the fixed Dual-Regime Contract input (1024 B / ≥ 60 λ Mode B), **then built the CDC-capable sibling**: chromatic-dispersion skew at short reach ≈ 21 ps (negligible); dominant, **unvalidated** term is inter-lane CDR/electrical skew (est. tens of ns) → `MAX_SKEW_CYCLES=128` placeholder; new `gcb_dwdm_async_skew_fifo` (Cummings-style dual-clock gray-code FIFO) + `gcb_dwdm_deskew_cdc` (one FIFO per colour on its own independent clock, bounded-wait barrier with named `stuck`/`txn_void` failure — replacing the old silent-drop/single-sticky-bit path) — **additive, `gcb_dwdm_deskew` unchanged**, CDC-architecture commitment (shared-clock vs. independent-CDR) left to the Architect per scope. `sim/lint.sh` 36/36 tops clean; new cocotb `Makefile.wdm_deskew_cdc` **TESTS=2 PASS=2** (async FIFO exact across 24 rounds on two incommensurate clocks; barrier + bounded-wait failure path exact on 4 independent clocks) after root-causing a cocotb read/write-ordering testbench hazard (cross-checked against the existing shipped `gcb_dwdm_skew_fifo`, not an RTL bug); Yosys 0.68 latch-free at cocotb geometry and the GCB-034 Mode B ceiling (`NUM_COLORS=60`). Orange Team question answered: no, the router was the cheap 5 % — deskew/CDC is where this epic's real cost lives. `T=(0.9,1.0,0.6)`, `pbg_o:orange` | done | blue |
| TKT-019.2 | **EPIC `TKT-019` build story 2 — GCB-034 payload muxing (resumed after TKT-019.3).** The logical-abstraction layer sitting above the physical transport: new `gcb_dwdm_payload_mux`/`gcb_dwdm_payload_demux` frame a variable-length logical result payload (Mode A `q_tile`+`q_scale` ≈ 271 B, Mode B `acc_tile` 1024 B) with an **in-band 3-byte header** (the GCB-034 D4 mode bit + length — travels inside the payload, not an extra sideband wire) and chunk it onto `color_word_t` words — **Mode A serialises on 1 λ (temporal), Mode B spreads across `MODE_B_LANES` λ (spatial)**, per GCB-037's link-budget finding. Additive: `gcb_dwdm_tx_packager` / `gcb_dwdm_deskew` / `gcb_wavelength_router` untouched — a second, parallel front/back end onto the same transport for the result-transport use case. `sim/lint.sh` 38/38 tops clean; new cocotb `Makefile.wdm_payload_mux` **TESTS=3 PASS=3** (Mode A + Mode B + back-to-back round trips, byte-exact). Yosys 0.68 bless required a real elaboration-scaling fix first (flatten unpacked word arrays to packed vectors, remove function calls from the large unrolled construction/unpack loops, hoist `int'()` casts out of those loops — the first revision passed lint + cocotb clean but made Yosys elaboration intractable even at the default geometry); after the fix, 0 problems / latch-free at cocotb geometry and the GCB-034 Mode B ceiling (`NUM_COLORS=MODE_B_LANES=60`). `T=(0.9,0.95,0.65)` | done | blue |
| TKT-019.4 | **EPIC `TKT-019` build story 4 — top-level digital link integration, Orange-Team epistemic boundary mandated.** Composes `gcb_dwdm_payload_mux` → **a cocotb Python "channel"** → `gcb_dwdm_deskew_cdc` → `gcb_dwdm_payload_demux` for the first time (router/tx_packager/sync-deskew deliberately excluded — not part of this chain). **Explicitly a digital contract test, not evidence about optical BER, link budget, or FEC** — none of which exist in or near this chain. 5 required vectors, `NUM_COLORS=MODE_B_LANES=60`: **V1** Mode A boundary sweep (1/13/16/271/1024 B) byte-exact; **V2** Mode B byte-exact across 60 genuinely-independent-period lane clocks; **V3** lane-skew, empirically-scanned 0-71 cycles (not hand-assumed) — monotonic, success/void transition ~8 cycles below the RTL's `ALIGN_TIMEOUT=64` (testbench overhead, not RTL), and **every voided case still completed late** once the delayed word arrived — `txn_void` is a bounded-wait alarm, not proof of loss; **V4** lane loss (1 of 60 withheld) → `txn_void`, `stuck` names exactly that lane, **no silent result, falsification attempt failed to falsify**; **V5** 5 deterministic single-bit-flip categories (payload body, header mode bit, header length bits, early/suppressed `is_tile_final`) — **every category silent/undetected, zero CRC anywhere in this transport**; the worst case (early false `is_tile_final`) reports a confidently-wrong **success** with the correct length header and silently-truncated data. Found + fixed two testbench bugs before trusting any result: a capture off-by-one that had produced passing-but-wrong results, and a recurrence of the TKT-019.3 clock-precision lesson. `sim/lint.sh` unaffected (38/38, no RTL changed this story). `T=(0.95,0.9,0.7)`, `pbg_o:orange` | done | blue |
| TKT-019.5 | **EPIC `TKT-019` story 5 — Orange architectural audit of transport failure semantics. No RTL touched; no PBG grade assigned (an audit, not a build story).** **Section A** ran the adversarial "Ghost Payload" test: transaction N forced to `txn_void` (1 of 60 lanes withheld), transaction N+1 started on the SAME lane set with `channel_enable` left untouched (the realistic case — nothing in the RTL forces a boundary). **Result: CONFIRMED** — `payload_valid` fired reporting a fully successful reconstruction of N (correct header, correct length) with one 16 B chunk (byte range 477–492) silently spliced in from N+1's data, no fault indication of any kind; mechanism fully traced (59 lanes still held N's unpopped words since the barrier never fired during N; the moment lane 30 got N+1's first word, all 60 were non-empty and the barrier popped a mix). **Section B** tabulated the exact state-machine reaction to 5 corruption categories (already-tested via [[TKT-019.4]]'s suite) — every one is either silently accepted as wrong or hangs with a fault signal that misattributes the cause; none both detects AND correctly identifies the fault. **Section C** extracted 8 requirements (REQ-TX-ID-001/002, REQ-TX-INT-001/002, REQ-TX-FRM-001/002, REQ-TX-REC-001/002), each traced to a specific observed failure, kept deliberately un-conflated across identity/integrity/framing/recovery. **Section D** enumerated 6 candidate mitigations (CRC, duplicated framing, sequence IDs, watchdog-flush, length cross-check, bounded finalize timeout) against what each prevents/detects/bounds and its relative cost — **none selected or recommended**, per the Architect's explicit mandate | done | — (no PBG grade) |

### TKT-### — Digital Compute Epoch + TKT-000 (frozen record)

Immutable. `TKT-000` is the Physical Reality Epoch boundary marker;
`TKT-001 … TKT-025` are the Digital Compute Epoch (functional verification,
closing at 4096 MAC/cycle / 0 stalls — EPIC `TKT-017`).

| Ticket | Title | Status | Color |
|---|---|---|---|
| **TKT-000** | **Orange Team epoch guidance** — Physical Reality First; the RTL/P&R toolchain split; introduces the **Orange** (PBG-O = Physical Falsifiability) grade | done | **orange** |
| TKT-001 | Migrate RTL schematic rendering off netlistsvg to a headless chip-scale layout engine | done | green |
| TKT-002 | Wire opcode-dispatcher decoded control signals into the tensor memory engine control ports | done | green |
| TKT-003 | Widen tensor-memory addressing past 4 GiB with a formal translation layer | done | green |
| TKT-004 | Address-translation mechanism trade study for tensor-memory addressing | done | green |
| TKT-005 | Formalize the PBG telemetry taxonomy as a 3D bipolar vector space | done | green |
| TKT-006 | Plumb the dispatcher [119:112] reserved byte to the BPR base-select override | done | green |
| TKT-007 | PBG telemetry scraper — backlog frontmatter to pgvector JSONL | done | green |
| TKT-008 | GDDR7 tensor-operand DMA engine — architecture scoping & trade study | done | green |
| TKT-009 | GDDR7 tensor-operand DMA — RTL implementation (arbiter + bank-group pipeline) | done | green |
| TKT-010 | DMA parameter / CSR wrapper generator — Python + Jinja2 -> SystemVerilog | done | green |
| TKT-011 | Cyclopter pgvector integration — ingest telemetry JSONL, KNN over ticket outcomes | done | green |
| TKT-012 | Tensor operand SRAM — allocation strategy + real controller behind the frozen engine | done | green |
| TKT-013 | Cyclopter scavenger agent — auto-ingest on ticket closure + bounded retrieval diversification | done | green |
| TKT-014 | Research spike — vector-space gap analysis between SV modules and Markdown doctrine | done | green |
| TKT-015 | Bit-plane Tx mapper doctrine — document the INT4↔optical encoding TKT-014 found undocumented | done | green |
| TKT-016 | Shared gcb_max_reduce macro — one verified max/argmax primitive for QAM slicing and softmax | done | green |
| TKT-017 | EPIC — Compute execution units: verified INT4 matrix-multiply tiles between the SRAM macros and the Softmax/QAM blocks (Stories TKT-022–025; e2e proven at 4096 MAC/cycle, 0 read stalls) | done | green |
| TKT-018 | EPIC — OpenROAD physical layout (**Measurement Epoch**, per TKT-000): extract area / timing / congestion / power / DRC on `gcb_max_reduce` — deliberately unoptimized — before optical scale-up | open | pending |
| TKT-019 | EPIC — Optical WDM transport (**re-chartered 2026-09-10, Orange method**): first validate or **falsify** the provisional `GCB-034` transport contract (V1–V5 + the Alternative B counterfactual — K-split + partial sums → substantially wider transport); only a surviving contract earns the WDM-PHY-scaling build on the `gcb-wiki/13` bitplane doctrine | open | pending |
| TKT-020 | Red/Yellow foundation audit — adversarial + tech-debt review of the locked baseline before the Epics | open | pending |
| TKT-021 | OpenROAD physical-design toolchain — from-source compilation on a constrained WSL2 host (**unblocks EPIC TKT-018**) | done | green |
| TKT-022 | **Story 1 of EPIC TKT-017** — `gcb_mac_tile_array`: verified INT4 MAC tile array (SRAM operands → dot-product grid → wide accumulators) | done | green |
| TKT-023 | **Story 2 of EPIC TKT-017** — `gcb_tile_requantize`: block-float requantization of the INT32 MAC tile to INT4/INT8 via the frozen `gcb_max_reduce` | done | green |
| TKT-024 | **Story 3 of EPIC TKT-017** — operand staging: the SRAM-read-port → MAC-grid staging / broadcast layer (`gcb_operand_stage`) | done | green |
| TKT-025 | **Story 4 (capstone) of EPIC TKT-017** — end-to-end integration TB: one real `gcb-wiki/06` tile through SRAM → stage → MAC → requantize → softmax hand-off, prints `MATCH` / `cycles/MAC` / `0 stalls` | done | green |

**Epic linkage:** TKT-021 is an out-of-band enablement ticket for **EPIC
TKT-018** (OpenROAD physical layout) — it provisions the P&R / signoff back end
that Epic's sub-stories build on. **EPIC TKT-017** (compute execution units) is
being delivered as a fan of Green sub-stories: **TKT-022** (Story 1) — the INT4
MAC tile array on the frozen SRAM read port; **TKT-023** (Story 2) — the INT32 →
INT4/INT8 block-float requantize stage, the third consumer of the TKT-016
`gcb_max_reduce` primitive; **TKT-024** (Story 3) — the operand-staging /
broadcast layer between the SRAM read port and the MAC grid; **TKT-025**
(Story 4, capstone) — the end-to-end integration TB + `make` artifact that runs
one real `gcb-wiki/06` tile through the full path and prints
`MATCH` / `cycles/MAC` / `0 read stalls`. TKT-025 Green lets EPIC TKT-017
itself be graded. TKT-022 carried the Yellow-Team AI check that re-pinned the
RTL toolchain after TKT-021's WSL changes; TKT-023/024/025 inherit that pinned
manifest.
