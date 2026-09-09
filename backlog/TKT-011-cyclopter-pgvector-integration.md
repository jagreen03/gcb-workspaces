---
id: TKT-011
title: "Cyclopter pgvector integration — ingest telemetry JSONL, KNN over ticket outcomes"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - software
  - database
  - pgvector
  - telemetry
  - cyclopter
---

# Objective

Stand up the PostgreSQL + `pgvector` store that `parse_pbg_telemetry.py`
(`TKT-007`) targets, load `telemetry_export.jsonl`, and run KNN queries over the
ticket-outcome vectors. This initialises the **Cyclopter** orchestration
substrate: a durable, queryable record of every ticket's PBG outcome that
survives a session, so orchestration can ask "what past work is nearest, in
outcome shape, to what I'm about to attempt".

## Context & Constraints

* **Current State:**
  * `TKT-007` delivered the scraper; its JSONL rows are keyed exactly to the
    `pbg_telemetry` columns defined in `gcb-wiki/09_pbg_telemetry_vector_space.md`
    §5.1 — `ticket_id, title, status, telemetry_vec vector(3), telemetry_color,
    vec_norm (generated), updated_at`. §5.2 already specifies the indexes: a
    **cosine** primary HNSW index (`vector_cosine_ops`, `pending` rows
    excluded) and an **L2** secondary. This ticket *instantiates* that schema;
    it does not redesign it.
  * `TKT-007` explicitly deferred to a later ticket: "the Postgres / pgvector
    instance, the `CREATE TABLE`, and the bulk-load step that consumes this
    JSONL." This is that ticket.
  * The current export is small (6 rows: TKT-003..008; TKT-001/002 skipped as
    `pending`). TKT-008 already carries a doc-09 `telemetry:` block; the rest
    are legacy scalar. KNN results must be checked against these known rows.
  * `gcb-wiki/04_ai_protocols_and_blue_wording.md` boundary invariant:
    PBG / Cyclopter are prompt-layer protocols and **must not be scaffolded
    into any hardware or host-orchestration repository**. The database, its
    migrations, and the loader therefore live in `gcb-python-orchestrator`
    (Python control-plane tooling) or a dedicated `gcb-workspaces` location —
    **not** in `gcb-rtl`, `gcb-wdm-transceiver`, or `gcb-host`.
  * `redhat.vscode-yaml` / Python tooling is already in the
    `software-control` / `architecture-doctrine` workspaces.
* **Constraint:** A repeatable, checked-in path — a schema migration (SQL or a
  migration tool) and an idempotent loader, not a one-off `psql` paste. The
  loader upserts on `ticket_id` so re-ingesting a fresh export is safe. No
  secret material committed; connection config via env / a sample `.env`. The
  DB service definition (e.g. `docker-compose.yml` pinning a `pgvector/pgvector`
  image) is committed so the store is reproducible on a laptop.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-011 is Green, with a mild Purple lean** — it operationalises
existing doctrine (Green), but a durable cross-session vector store is the first
concrete piece of the Cyclopter orchestration substrate, which is net-new
capability the rest of the roadmap builds on.

* **Green (target):** `pgvector` extension enabled; the `pbg_telemetry` table
  and both indexes created exactly per Doc 09 §5.1/§5.2; an idempotent loader
  that bulk-upserts `telemetry_export.jsonl`; and demonstrated KNN — cosine
  nearest-N over `telemetry_vec` with `pending` excluded — returning the
  correct rows against the current export, all reproducible from a committed
  `docker-compose` + migration + loader.

* **Yellow (reject):** Loading the JSONL into a plain table with no `vector(3)`
  column and no ANN index (that is the single-scalar model `TKT-005` retired,
  rebuilt in SQL), or a hand-run `psql` session with no migration or loader
  script to reproduce it.

* **Red (reject):** Standing the database or its tooling up **inside**
  `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host` (violates the Doc 04 boundary
  invariant), or redefining the Doc 09 schema (column set, vector dimension,
  distance ops) rather than instantiating it.

* **Purple / Light-gray:** A full Cyclopter orchestration engine on top of the
  store is Purple / a later ticket. Leaving telemetry as a flat JSONL file that
  nothing queries (Light-gray) is the gap this closes.

**Explicitly out of scope (separate tickets):**
1. The Cyclopter orchestration logic that *uses* the store (retrieval-augmented
   planning, session-context assembly).
2. Any dashboard / visualisation over the vectors.
3. Scheduled / CI ingestion (a cron or hook that re-runs the scraper + loader).
4. Backfilling `telemetry:` blocks into TKT-001..007 and the template — still a
   `TKT-005` follow-on; this ticket ingests whatever the scraper currently
   emits.

## The "Green" Target

1. A committed DB service definition (`docker-compose.yml` or equivalent)
   pinning a `pgvector`-enabled PostgreSQL image, plus a sample `.env` /
   connection-config template (no secrets committed).
2. A migration (SQL file or migration-tool revision) that enables
   `CREATE EXTENSION vector` and creates `pbg_telemetry` with the exact Doc 09
   §5.1 columns (`telemetry_vec vector(3)`, generated `vec_norm`) and the two
   §5.2 indexes (HNSW `vector_cosine_ops` filtered `WHERE telemetry_color <>
   'pending'`, and `vector_l2_ops`).
3. An idempotent loader (Python, in `gcb-python-orchestrator`) that reads
   `telemetry_export.jsonl` and `INSERT ... ON CONFLICT (ticket_id) DO UPDATE`
   — re-running after a fresh scrape converges, does not duplicate.
4. End-to-end run demonstrated: `parse_pbg_telemetry.py --out
   telemetry_export.jsonl` -> loader -> `SELECT count(*)` matches the emitted
   row count (6 today).
5. KNN demonstrated: a cosine nearest-N query
   (`ORDER BY telemetry_vec <=> '[...]'`, `pending` excluded) returns the
   expected ordering against the known rows (e.g. nearest to `[1,0.5,0.5]`
   surfaces TKT-008 first), plus one L2 query for contrast.
6. A short `README` (in the DB tooling dir) with the bring-up sequence:
   compose up -> migrate -> scrape -> load -> query.
7. `requirements.txt` gains the DB driver (`psycopg[binary]` or similar); the
   loader has `--help` and a `--dsn` / env override.
8. Nothing lands in `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host`; the Doc 09
   schema is instantiated, not modified.

---
## Execution Log
*(To be populated during execution)*
* **Agent ID:**
* **Commands Run:**
* **Artifacts Touched:**

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
