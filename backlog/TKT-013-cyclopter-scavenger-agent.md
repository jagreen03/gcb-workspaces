---
id: TKT-013
title: "Cyclopter scavenger agent — auto-ingest on ticket closure + bounded retrieval diversification"
date_created: 2026-09-09
status: open
telemetry_color: pending
tags:
  - backlog
  - software
  - cyclopter
  - orchestration
  - daemon
---

# Objective

Build the first *active* Cyclopter agent: a restartable Python background process
that watches `gcb-workspaces/backlog/` for ticket state changes and, on a
detected closure, autonomously runs `parse_pbg_telemetry.py` +
`load_telemetry_pg.py` so the pgvector store converges with no human step.
Separately and opt-in, it emits a **bounded, clearly-labelled "stochastic noise"
context file** — a diversified sample of the store (K cosine neighbours + M
uniformly-random non-`pending` rows) — to widen what retrieval-augmented planning
sees. The noise is an *output artifact*, never a write into `pbg_telemetry`.

## Context & Constraints

* **Current State:**
  * `TKT-007` delivered the scraper (`scripts/parse_pbg_telemetry.py`);
    `TKT-011` delivered the store and `scripts/load_telemetry_pg.py` (idempotent
    `ON CONFLICT (ticket_id) DO UPDATE`, `--dsn` / `$CYCLOPTER_DSN` / `.env`
    resolution). Ingestion is entirely **manual** today.
  * The Cyclopter DB runs from `deploy/cyclopter/docker-compose.yml`
    (`pgvector/pgvector:pg16`, host port 5433); `.env` convention established.
  * Nothing watches the repo; `TKT-011` out-of-scope item 3 explicitly deferred
    "a cron or hook that re-runs the scraper + loader" — **this is that ticket**.
  * `gcb-wiki/04` boundary invariant: Cyclopter tooling stays in
    `gcb-python-orchestrator`, never in `gcb-rtl` / `gcb-wdm-transceiver` /
    `gcb-host`.
  * "Stochastic noise" needs a bounded, falsifiable definition before it is
    built: it is **retrieval diversification** — sampling the existing corpus to
    surface non-obvious neighbours — not perturbation of stored vectors and not
    synthetic rows.
* **Constraint:** Pure Python control-plane, `gcb-python-orchestrator` only. The
  daemon is restartable and idempotent (re-processing a ticket converges — the
  loader already upserts). No busy-loop: poll `mtime` / `git` on an interval, or
  use `watchdog`. Debounce + a single-run lock so a burst of edits or a restart
  cannot double-fire or race the DB. Structured logging, clean SIGINT/SIGTERM, a
  `--once` mode for CI. DSN via env / `.env`, no secrets committed. The
  noise-injection output is a separate file with provenance tags — never an
  `INSERT` into `pbg_telemetry`.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-013 is Green, with a Purple lean** — it removes a concrete
piece of toil (Green), but it is also the first agent that makes Cyclopter
*self-maintaining* rather than a passive store, which the orchestration roadmap
builds on.

* **Green (target):** a running daemon (`scripts/cyclopter_scavenger.py` or a
  `cyclopter/` package) that (a) detects a backlog ticket transitioning to a
  graded, closed state and autonomously runs scrape -> idempotent upsert so the
  DB row count reflects the closure with no human step, (b) on demand emits a
  bounded, provenance-tagged "diversified retrieval" context file, (c) has
  `--once`, `--interval`, `--dsn`, `--dry-run`, `--noise K`, structured logs,
  and clean signal handling; restart-safe (kill mid-watch, restart, DB
  converges, no duplicates).

* **Yellow (reject):** a `while True: sleep()` poller with no debounce or lock
  (double-runs, races the loader), or hard-coded backlog path / DSN, or a
  "closure" heuristic that fires on any file write rather than a real state
  transition.

* **Red (reject):** the agent writing synthetic / noise / perturbed rows into
  `pbg_telemetry` (poisons the KNN corpus — the noise artifact must live outside
  the store), redefining the Doc 09 schema or the scraper's frontmatter
  contract, or scaffolding the daemon into `gcb-rtl` / `gcb-wdm-transceiver` /
  `gcb-host`.

* **Purple / Light-gray:** a full event-driven orchestration bus / message
  queue is Purple / a later ticket. Leaving ingestion a manual two-command
  ritual (Light-gray) is the toil this removes.

**Explicitly out of scope (separate tickets):**
1. The retrieval-augmented planner that *consumes* the diversified context file.
2. CI wiring of the `--once` mode (a separate infra ticket).
3. GitHub-webhook / multi-repo triggering — local filesystem watch only here.
4. Any change to the Doc 09 schema, `parse_pbg_telemetry.py`, or
   `load_telemetry_pg.py`'s contract.

## The "Green" Target

1. `gcb-python-orchestrator/scripts/cyclopter_scavenger.py` (or a `cyclopter/`
   package) — a long-running watcher over `../gcb-workspaces/backlog/*.md`.
2. On a real transition to a graded, closed state (`status: done` **and**
   `telemetry_color != pending`), debounced and lock-guarded, it invokes the
   scrape and the idempotent upsert; the DB row count reflects the new closure
   with no human action.
3. Flags: `--once` (single pass then exit), `--interval N`, `--dsn`,
   `--dry-run`, `--noise K`, `--help`.
4. "Stochastic noise" is defined in the module header and a
   `deploy/cyclopter/README.md` paragraph: K cosine neighbours of a supplied /
   latest vector plus M uniformly-sampled non-`pending` rows, written to a
   timestamped context file with provenance tags; the store is **read-only** on
   this path.
5. Restart-safe: killing and restarting the daemon mid-watch re-processes
   cleanly — DB converges, row count stable, no duplicate rows — demonstrated.
6. Structured logging (one line per event: `detected` / `scraped` / `upserted`
   / `noise-emitted`), clean SIGINT / SIGTERM shutdown.
7. `requirements.txt` gains any watcher dependency (e.g. `watchdog`) or the
   script uses stdlib polling; the run recipe is added to
   `deploy/cyclopter/README.md`.
8. The diff is confined to `gcb-python-orchestrator`; nothing touches
   `pbg_telemetry`'s schema or its contents outside the existing loader path.

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
