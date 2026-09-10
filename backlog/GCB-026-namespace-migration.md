---
id: GCB-026
title: "Namespace migration — deprecate the legacy TKT-### prefix, adopt the enterprise GCB-### project key"
date_created: 2026-09-10
status: done
telemetry_color: blue
telemetry:
  spec: 0.5
  quality: 1.0
  emergence: 0.0
tags:
  - backlog
  - process
  - tooling
  - namespace
  - project-management
---

# Objective

`TKT-000` was taken literally, which breaks standard enterprise project-planning
convention (Jira-style keys run `KEY-1, KEY-2, …`; there is no ticket zero).
**We do not rewrite Git history.** Instead, cut over cleanly at a namespace
boundary: deprecate the `TKT-###` prefix and adopt the enterprise
**`GCB-###`** project key for all future work, continuing the running counter
(`GCB-026` = this ticket).

This is a **process / tooling ticket**. It renumbers nothing, re-commits
nothing, and rewrites no history; its artifact is this record plus the
restructured `gcb-workspaces/README.md` index.

## Context & Constraints

* Renumbering `TKT-000 … TKT-025` would rewrite 26 files, invalidate every
  commit trailer and every Cyclopter `pbg_telemetry.ticket_id` row that
  references them, and destroy the provenance chain the knowledge graph is
  built on — a destructive operation for a cosmetic gain. Rejected.
* A clean forward cutover costs one ticket and one README restructure, keeps
  the historical record immutable, and is exactly how a real project migrates a
  Jira key.
* The three EPIC ids — `TKT-017` (compute), `TKT-018` (physical measurement),
  `TKT-019` (optical transport) — **retain their numbers**; their child stories
  from `GCB-027` onward are `GCB-###`.
* Cyclopter's `pbg_telemetry.ticket_id` is already an arbitrary string column —
  it stores `TKT-###` and `GCB-###` side by side with **no schema change**; the
  TKT-013 scavenger ingests both.

## AI Orchestration Priorities (PBG Evaluation)

**The target for GCB-026 is Blue:** a sustainable enterprise-standard convention
adopted at a clean boundary with zero destructive history operations.

* **Blue (target):** forward cutover — new prefix from here, legacy ids frozen
  in place, README restructured into a current `GCB-###` section over the
  legacy `TKT-###` record, one commit.
* **Green:** n/a — this closes no engineering gap; it is a naming convention.
* **Yellow (reject):** leaving `TKT-000` as an unremarked anomaly and hoping
  nobody notices; or a half-migration where some new tickets are `GCB-###` and
  some still `TKT-###`.
* **Red (reject):** `git filter-branch` / history rewrite to renumber the
  legacy tickets — breaks trailers, Cyclopter rows, and every external
  reference for a cosmetic result.
* **Purple / Light-gray:** not a new capability (not Purple); doing nothing
  (Light-gray) leaves the convention broken for every future ticket.

---
## Execution Log

* **Agent ID:** Technical Program Manager / Lead Architect (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`.

### Epoch record

* **`TKT-001` … `TKT-025` — the "Digital Compute Epoch."** The
  functional-verification era: headless chip-scale schematic rendering (001);
  opcode dispatch + tensor-memory addressing / SRAM controller (002–006, 012);
  the Cyclopter pgvector knowledge graph + scraper + scavenger (007, 011, 013);
  the GDDR7 tensor-operand DMA (008–010); PBG / bitplane / KG-gap doctrine
  (005, 014, 015); the shared `gcb_max_reduce` primitive (016); the Red/Yellow
  foundation audit (020); the OpenROAD toolchain provisioning + Yellow-Team
  re-pin (021); and **EPIC `TKT-017`'s four compute sub-stories (022–025)** —
  `gcb_mac_tile_array`, `gcb_tile_requantize`, `gcb_operand_stage`, and the
  end-to-end integration closing at **4096 MAC/cycle, 0 SRAM read stalls**.
* **`TKT-000` — foundational out-of-band advisory.** *Not* part of the
  `TKT-001…025` sequence. A foundational Orange Team advisory that initiated the
  **"Physical Reality Epoch"**: *Physical Reality First*, the RTL / P&R
  toolchain split, and the **Orange (PBG-O)** grade. It keeps its `TKT-000` id
  permanently, as the historical marker of the epoch boundary — it is not
  renumbered into the `GCB-###` space.

### Mandate

* **From this ticket forward, all new tickets use the `GCB-###` prefix**,
  continuing the running counter: `GCB-026` (this), `GCB-027` (first
  Measurement-Epoch story), …
* Existing `TKT-###` tickets are **not renumbered, not re-committed, not
  rewritten** — they are the immutable Digital Compute Epoch + `TKT-000`
  record.
* EPIC ids `TKT-017` / `TKT-018` / `TKT-019` are unchanged; their new child
  stories are `GCB-###` (e.g. `GCB-027` is Story 1 of `TKT-018`).
* No Cyclopter schema change; `ticket_id` already holds arbitrary strings.

### Actions

* Authored this ticket.
* Drafted `GCB-027-max-reduce-physical-measurement.md` (Story 1 of the
  `TKT-018` Measurement Epoch).
* Restructured `gcb-workspaces/README.md`: a new
  **`### GCB-### Namespace (current)`** section over the legacy
  **`### TKT-### — Digital Compute Epoch + TKT-000 (frozen record)`** table.
* **Not changed:** any `TKT-###` file, any commit, any trailer, any Cyclopter
  row; `gcb-wiki/09` (PBG maths); the EPIC ids.

---
## Telemetry & Evaluation

**Final State:** `blue`

**Vector Summary:** `T = (spec +0.5, quality +1.0, emergence 0.0)`,
`‖T‖₂ = √1.25 ≈ 1.118`.

* **X — Specification `+0.5`.** The cutover is clean and complete — new prefix
  from here, legacy ids frozen, README restructured, one commit — but this is a
  naming convention, not an engineering deliverable, so it does not earn a full
  `+1.0`.
* **Y — Quality `+1.0`.** Blue by definition: the enterprise-standard `KEY-###`
  convention adopted at a namespace boundary with **zero destructive history
  operations** — no `filter-branch`, no renumber, no broken trailers or
  Cyclopter rows. The historical record stays immutable and the migration is
  exactly the pattern a real project uses.
* **Z — Emergence `0.0`.** A process improvement, not a new capability.

Dominant spoke: `|y| = 1.0 > |x| = 0.5`; tie-break has `y` win → `Y+` →
**Blue**. Cyclopter scavenger (TKT-013) ingests this vector — the first
`GCB-###` node and the marker for the namespace cutover.