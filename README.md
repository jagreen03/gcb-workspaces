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
    └── TKT-025-compute-e2e-integration.md
```

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
- **The "Green" Target** — the acceptance definition for a Green outcome.
- **Execution Log** — populated during execution (agent id, commands, artifacts).
- **Telemetry & Evaluation** — populated post-execution (final state, vector
  summary).

Frontmatter carries `id`, `status` (`open` → `in-progress` → `done`), and
`telemetry_color` (`pending` until the work is graded).

### Index

| Ticket | Title | Status | Color |
|---|---|---|---|
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
| TKT-017 | EPIC — Compute execution units: verified INT4 matrix-multiply tiles between the SRAM macros and the Softmax/QAM blocks | open | pending |
| TKT-018 | EPIC — OpenROAD physical layout: push the verified SV-2017 logic to a 5nm-class GDSII | open | pending |
| TKT-019 | EPIC — Optical WDM transport: scale the WDM PHY and transceiver logic on the bitplane doctrine | open | pending |
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
