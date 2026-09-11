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
    ├── GCB-034-optical-transport-contract.md    ← EPIC TKT-019 Story 1: what the optical layer must carry (provisional; open)
    ├── GCB-034-LOOK-AROUND.md                   ← orthogonal-discovery pass: constraints D4 full-K-local silently accepts
    ├── GCB-035-optical-line-rate-derivation.md  ← TKT-019 V1+V2: Alt A ≈2.4 Gbps vs Alt B ≈17.9·P Gbps
    └── GCB-036-out-w-numeric-consequences.md    ← TKT-019 V3: INT4 fails the 25 dB budget → D2 provisionally INT8
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
| GCB-034 | **Story 1 of EPIC `TKT-019` (Optical WDM Transport)** — Orange-**method** data-movement contract (authored under it; *not* a PBG grade). From the ASAP7 measurements: what leaves a compute tile (→ the requantised INT4 `q_tile` + `q_scale`, ~140 B), width/cadence at 1 GHz (one tile per `K_STEPS` = 512 cycles → ~0.27 GB/s, ~1000× below the 256 GB/s electrical operand bus), continuity (deterministically periodic), reduction (`K_TOTAL:1` + `32b:4b` electrical). **Provisional decisions D1 = POST-REQUANTIZATION, D4 = FULL-K LOCAL REDUCTION** (D2/D3 open) — a testable hypothesis, *not* a fact. **Purple candidate:** the electrical compute domain as an enormous compression boundary. Stays **`open`** until EPIC `TKT-019` runs the falsification pass. See `GCB-034-LOOK-AROUND.md` | open | pending |
| GCB-034-LOOK-AROUND | **Orthogonal-discovery pass on GCB-034** — what architectural constraints we silently accept because the ~1000× compression looks so good (C1–C11). D4 deep-dive: strict full-K-local eliminates K-parallelism, sizes the node by the model not the fabric, serialises K-latency, and caps single-request horizontal scale — likely correct only as a *workload-class mode*, with Alternative B kept live. Feeds `TKT-019` V5 | open | pending |
| GCB-035 | **TKT-019 falsification V1 + V2** — payload bit-accounting and line-rate derivation. Alt A (post-requant, 140 B / `K_STEPS=512` @ 1 GHz): **2.19 Gbps raw → ≈ 2.4 Gbps** with 64b/66b + KP4 (9.14 % coding, carried at 12 %) → single ≤ 10 G lane. Alt B (INT32 partial, 1024 B): **16.0 Gbps raw → ≈ 17.9 Gbps** → 25 G-class lane; and **`~7.3·P×` per link, `~7.3·P²×` at the accumulator** once the K-split is real (P = 4 → 71.7 Gbps/link, 286 Gbps aggregate). V1 HOLDS; V2 HOLDS for FFN, conditional-fail for small-K layers → escalates D3 | open | pending |
| GCB-036 | **TKT-019 falsification V3** — numeric consequences of `OUT_W` (D2). INT4 block FP has only ~18 dB (~8×) usable in-block dynamic range; against a 25 dB SQNR budget it needs `r_max ≤ 1.56×` while real transformer activation blocks span 4–50× (outlier channels) → **V3 CONTRACT FAILS for INT4 as a general default**. **D2 → provisionally INT8, PER_ROW, RNE** (INT4 opt-in for QAT / verified-narrow-range). INT8 payload 143 B → **~271 B**, line rate 2.4 → **~4.7 Gbps** — still a single ≤ 10 G lane, ~0 dB optical-SNR penalty (spend baud not constellation). Purple compression ratio ~850× → **~432×** (hypothesis holds) | open | pending |

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
