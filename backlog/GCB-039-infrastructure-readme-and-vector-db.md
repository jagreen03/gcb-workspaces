---
id: GCB-039
title: "Infrastructure health: repository README audit + local Postgres/pgvector persistent retrieval layer (architecture, not implementation)"
date_created: 2026-09-11
status: open
telemetry_color: pending
tags:
  - backlog
  - infrastructure
  - mlops
  - documentation
---

# Objective

Two infrastructure-health workstreams, both scoped to **assessment and
architecture, not implementation** (Objective B) or **targeted, justified
fixes** (Objective A) — this ticket is not a rubber stamp for touching every
repo, and it does not claim either workstream closes anything in EPIC
`TKT-019` (the optical-transport integrity work in [[TKT-019.8]] remains open,
independently of this ticket).

## Objective A — Repository health (README audit)

Enumerate every `gcb-*` sibling directory under the workspace root and, for
each, determine: does a README exist; does it accurately describe the
directory's actual current architectural role; is a README appropriate for
this directory at all (a generated-output, vendor, or build-artifact
directory may correctly have none, or a short "this is generated, do not
hand-edit" notice rather than a narrative README); and, if a gap exists,
create/update/leave-as-is. Changes must stay concise and scoped to the
directory's actual role — this is a correctness pass, not a rewrite pass, and
thinness alone (a short but accurate README) is not a defect.

## Objective B — Local PostgreSQL + pgvector architecture

Architect (do not implement beyond what already exists) a local,
Docker-based PostgreSQL + pgvector deployment as a **persistent retrieval and
memory layer** for AI agents working this codebase across sessions. This is
**not** proposed from zero: `gcb-python-orchestrator/deploy/cyclopter/`
already runs exactly this stack (`pgvector/pgvector:pg16`, host port 5433,
the `gcb-wiki/04` control-plane-boundary invariant — this state lives in
`gcb-python-orchestrator`, never in `gcb-rtl`/`gcb-wdm-transceiver`/
`gcb-host`) with one live table, `pbg_telemetry` (`gcb-wiki/09` §5): the 3-D
PBG outcome vector `(spec, quality, emergence)` per ticket, clustered by
cosine/L2 HNSW index, kept current by a restart-safe scavenger daemon
(TKT-013) watching `gcb-workspaces/backlog/*.md`.

That existing table answers one question well — "what past *outcome* is
nearest, in PBG shape, to what I'm about to attempt" — and was never meant to
answer a different one: "what did we *decide*, and *why*, about this specific
mechanism/invariant/finding, in whatever document that lives in." This
ticket's Objective B is the architecture for that second question: a
**semantic retrieval index** layered onto the **same** Postgres instance,
never competing with or duplicating `pbg_telemetry`, and — this is the
non-negotiable invariant — **never authoritative**. The repository's files,
ticket frontmatter, commit history, and the architectural invariants written
into doctrine documents remain the canonical record, exactly as they are
today, whether or not this layer exists, is populated, is stale, or is down.

A vector index is a *retrieval convenience*, not a source of truth, and
pgvector by itself does not "solve context collapse" — it is a proposed
persistent retrieval/memory layer an agent can consult, with structured
filtering, alongside (never instead of) actually reading the canonical files
it points to.

### Canonical record vs. semantic index — the distinction that must not blur

| | **Canonical architectural record** | **Semantic retrieval index** |
|---|---|---|
| What it is | The repo files themselves: ticket Markdown + frontmatter, RTL, commit history, doctrine documents | Chunked text + embeddings of those same files, stored for similarity search |
| Who/what is authoritative | Always. A ticket's `status`/`telemetry_color` in its own frontmatter is the truth; a stale copy in the index is a bug, not a second opinion | Never. It is a pointer/ranking mechanism — "these N chunks looked relevant" — not a claim about current state |
| How it's kept current | Git commits, direct edits — already exists, already works | Re-embedding on change, ideally event-driven (see Scavenger precedent below); can lag |
| Failure mode if trusted wrongly | N/A — it's the ground truth | An agent answers from a stale or irrelevant chunk as if it were current fact |

### Proposed data model (additive to, not replacing, `pbg_telemetry`)

All tables below are new; `pbg_telemetry` is unchanged and remains the
canonical PBG-outcome-vector store. Proposed, not implemented:

| Column group | Fields | Notes |
|---|---|---|
| Identity | `ticket_id` (nullable — a doctrine doc has no ticket), `doc_path` (repo-relative, e.g. `gcb-wiki/14-Optical-Transport-Doctrine.md`), `repo` (`gcb-workspaces`, `gcb-wiki`, `gcb-wdm-transceiver`, ...) | one row of *metadata* per source document, not per chunk |
| Canonical state (mirrored, never authoritative) | `status`, `telemetry_color`, `spec`/`quality`/`emergence` (nullable — mirrors `pbg_telemetry` for tickets that have it; doctrine docs have none) | a foreign-key-shaped join to `pbg_telemetry.ticket_id` where one exists is preferable to duplicating columns, to avoid a second place these can drift |
| Provenance | `git_commit` (the commit this snapshot was embedded from), `source_updated_at` (the file's own mtime/commit time), `embedded_at` (when this row's vector was computed) | the gap between `source_updated_at` and `embedded_at` is the staleness signal — see below |
| Findings/invariants (structured, queryable without touching the vector index at all) | `orange_team_findings` (jsonb array: finding id, severity, status — e.g. TKT-019.8 Findings A/B), `architectural_invariants` (jsonb array: invariant id, short text, which ticket/doc defines it) | these must be **filterable columns**, not buried in embedded prose, precisely so a query like "show me every OPEN architectural defect" never depends on semantic luck |
| Content | `chunk_index`, `chunk_text`, `chunk_char_range` | one row per chunk; a document is N rows, not 1 — chunking strategy (size/overlap) is an implementation decision for a later ticket, not fixed here |
| Vector | `embedding vector(D)` (D = the chosen model's dimension — unlike `pbg_telemetry`'s fixed, doctrine-mandated `vector(3)`, this D is an implementation choice, e.g. 384/768/1536 depending on the embedding model selected later) | HNSW cosine index, same pattern as `pbg_telemetry_cos` |
| Relationships | `related_doc_ids` or a separate `doc_relationships(from_id, to_id, kind)` table (`supersedes`, `references`, `depends_on`) | captures e.g. "TKT-019.6 is superseded-in-part-by TKT-019.7's trade study," or "gcb-wdm-transceiver's RTL forked from gcb-photonic-qam-v2" (see README audit finding below) — structured, not left to the embedding to imply |

### Hybrid retrieval

A query combines a **structured filter** (SQL `WHERE`, e.g. `repo =
'gcb-wdm-transceiver' AND 'OPEN_DEFECT' = ANY(...)`) with a **semantic
rank** (`ORDER BY embedding <=> query_vec`) — the filter narrows to what is
*eligible* to be canonically relevant; the vector search ranks *within* that
set by topical similarity. This is the same two-layer shape `pbg_telemetry`
already uses (`WHERE telemetry_color <> 'pending' ORDER BY ... <=> ...`),
extended from a 3-D outcome vector to an open-dimension text embedding.

### Versioning, staleness, re-embedding

- Every row carries `git_commit` + `source_updated_at` + `embedded_at`. An
  agent consuming a result should treat `embedded_at < source_updated_at`
  (the source changed since this chunk was embedded) as **stale**, and
  either re-fetch the live file or flag the result as possibly outdated —
  never silently trust an old chunk as current.
- Re-embedding trigger: the existing Scavenger daemon (TKT-013) already
  solves exactly this problem for `pbg_telemetry` — it polls
  `gcb-workspaces/backlog/*.md` by `stat` + content hash and reconciles on
  change, restart-safe, no `watchdog` dependency. The same mechanism,
  extended to watch the additional doc roots this index covers (`gcb-wiki/`,
  RTL headers, etc.), is the proposed re-embedding trigger — not a new
  polling design.
- Conflict handling: if a retrieved chunk's embedded content and the live
  file disagree (detected via the staleness check above, or an explicit
  drift audit), the **live file wins**, unconditionally. The index is never
  corrected by "trusting the embedding more" — it is re-embedded from the
  live file, or the stale row is deleted/flagged.

### Local/private operation and agent query workflow

Runs exactly like the existing Cyclopter deployment: `docker compose up -d`
on the existing `cyclopter-db` service (the same container, a new migration
adding these tables — not a second container/port), local-only, no network
exposure beyond the existing `localhost:5433` bind. Proposed agent workflow:
an agent with a question about "why does X work this way" issues a
structured+semantic query as above, receives N chunks each carrying
`doc_path` + `git_commit` + a staleness flag, and is expected to **read the
live file at `doc_path` before asserting anything as current fact** — the
index's job is to say *where to look*, never to BE the look.

## Out of scope (this ticket)

1. Implementing any of Objective B's schema, migration, or embedding
   pipeline — architecture only, per the explicit instruction not to build it
   yet.
2. Selecting a specific embedding model or chunking strategy — a later
   ticket's decision, once Objective B's architecture is reviewed.
3. Any claim that this layer would have prevented, or will prevent, a
   specific past context/continuity issue — this is a proposed capability,
   not a diagnosed-and-fixed incident.
4. Anything related to EPIC `TKT-019`'s optical-transport integrity work —
   [[TKT-019.8]] Findings A and B remain open, unaffected by this ticket.

---
## Execution Log — Objective A (README audit)

See the companion report delivered alongside this ticket for the full
per-directory disposition (inspected / created / updated / left unchanged /
ambiguous). Summary of the two most significant findings, both corrected:

1. **`gcb-wdm-transceiver/README.md`** claimed "Architecturally independent:
   this repository shares nothing with, and does not depend on, any prior
   GreenCoyote-Bay compute-tier work." This is factually incorrect:
   `gcb_wavelength_router.sv`, `gcb_bitplane_tx_mapper.sv`,
   `gcb_rx_digital_recombiner.sv`, and `gcb_qam_datapath_top.sv` were forked
   (copied, then independently modified — `gcb_wavelength_router.sv` has
   since diverged under TKT-019.1's `N_LAMBDA` parameterisation;
   `gcb_bitplane_tx_mapper.sv`/`gcb_rx_digital_recombiner.sv` remain
   byte-identical to their `gcb-photonic-qam-v2` originals) from
   `gcb-photonic-qam-v2`, with no cross-reference in either repo's README
   before this ticket. Corrected.
2. **`gcb-photonic-qam-v2`** (the fork source above) had **no README at
   all**, despite being a real, substantial, hand-written RTL+sim+tb+model
   project — created, documenting both its own role and the fork
   relationship.

## Execution Log — Objective B (architecture only)

Architecture proposed above. Not implemented. No migration written, no
container started, no schema applied.

---
## Telemetry & Evaluation

No PBG grade assigned — this ticket documents an audit and a proposed
architecture, not a closed build; Objective B is explicitly not implemented.

**Final State:** `open | pending`
