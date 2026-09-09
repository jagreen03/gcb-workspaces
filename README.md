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
    └── TKT-002-opcode-dispatcher-wiring.md
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
| TKT-001 | Migrate RTL schematic rendering off netlistsvg to a headless chip-scale layout engine | open | pending |
| TKT-002 | Wire opcode-dispatcher decoded control signals into the tensor memory engine control ports | open | pending |
