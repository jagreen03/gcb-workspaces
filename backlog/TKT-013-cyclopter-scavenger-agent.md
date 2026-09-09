---
id: TKT-013
title: "Cyclopter scavenger agent — auto-ingest on ticket closure + bounded retrieval diversification"
date_created: 2026-09-09
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.5
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

* **Agent ID:** Lead Python Developer (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`

* **Commands Run:**
  * `python scripts/cyclopter_scavenger.py --help` — CLI surface confirmed
    (`--once`, `--interval`, `--debounce`, `--backlog`, `--dsn`, `--migration`,
    `--dry-run`, `--noise K`, `--noise-random M`, `--noise-vector`, `--seed`,
    `--force`, `--verbose`).
  * `python scripts/cyclopter_scavenger.py --once --dry-run --noise 5` — detect
    + log only; verified it never scrapes / upserts / writes the state file.
  * **Live demonstration** against an ephemeral `pgserver` (bundled PG16 +
    pgvector 0.6.2; a local `--migration` shim swaps only the `vec_norm`
    generated-column expr to `vector_norm(telemetry_vec)` — identical value,
    committed migration untouched — same stand-in as TKT-011, since the box has
    no Docker / pgvector ≥ 0.7), driving the **real**
    `scripts/cyclopter_scavenger.py` as a subprocess daemon over a temp copy of
    this backlog:
    1. `--once` baseline → `event=reconcile` → `scraped rows=10` →
       `upserted db_rows=10`.
    2. Daemon running; edit a scratch `TKT-999` `open → done + telemetry_color:
       green` → `event=queued ticket=TKT-999 debounce=1.0s` →
       `event=detected ticket=TKT-999 status=done color=green` →
       `event=scraped rows=11` → `event=upserted db_rows=11` →
       `event=noise-emitted path=deploy/cyclopter/noise/…_TKT-999.json` →
       `SIGTERM` → `event=shutdown signal=SIGTERM` → `event=stopped`.
       **DB row count 10 → 11, TKT-999 present, no human step.**
    3. Restart the daemon → `re-fired TKT-999? False`, row count **stable at
       11** (state file suppresses the redundant run; the startup reconcile is
       still idempotent).
    4. `SIGKILL` mid-debounce (lock file orphaned) → restart with `--force` →
       `event=lock-stale … taking over`, the pending re-grade
       (`green → blue`) is caught and upserted, row count still 11, TKT-999 now
       `color=blue vec=[0,1,0]`.

* **Artifacts Touched:**
  * `gcb-python-orchestrator/scripts/cyclopter_scavenger.py` (new) — the daemon.
  * `gcb-python-orchestrator/deploy/cyclopter/README.md` — new
    "Scavenger agent (TKT-013)" section: run recipes + the stochastic-noise
    artifact contract.
  * `gcb-python-orchestrator/.gitignore` — ignores
    `deploy/cyclopter/noise/`, `.scavenger_state.json`, `.scavenger.lock`.
  * No change to `parse_pbg_telemetry.py`, `load_telemetry_pg.py`, the Doc 09
    schema, or `pbg_telemetry`'s contents outside the existing loader path.
  * `requirements.txt` unchanged — the daemon uses stdlib `stat` + content-hash
    polling, no `watchdog` dependency.

---
## Telemetry & Evaluation

**Final State:** `Green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence +0.5)`,
`‖T‖₂ = √2.25 = 1.5`.

* **X — Specification `+1.0`.** All eight Green-Target criteria met: a
  long-running watcher over `../gcb-workspaces/backlog/*.md`; a *real* state
  transition (`status: done` **and** `telemetry_color != pending`, or a content
  change to an already-closed ticket) — not "any file write" — that is
  debounced and lock-guarded before it invokes the unchanged
  `parse_pbg_telemetry.py` + `load_telemetry_pg.py`, converging the store with
  no human step (demo: 10 → 11 rows); the full flag set; a module-header +
  `deploy/cyclopter/README.md` definition of the read-only, provenance-tagged
  K-cosine-+-M-random noise artifact; demonstrated restart-safety (kill
  mid-watch → restart → DB converged, row count stable, no duplicates); one
  `event=…` line per event with clean `SIGINT`/`SIGTERM`; stdlib polling so
  `requirements.txt` is untouched; the diff confined to `gcb-python-
  orchestrator` with `pbg_telemetry` touched only through the existing loader.

* **Y — Quality `+1.0`.** Blue-grade: reuses the existing frontmatter parser
  and the DSN / vector helpers rather than re-implementing them (the Red the
  ticket calls out), PID lock + stale-lock takeover + in-process critical-
  section lock, atomic state-file writes, per-file hash-stable debounce,
  interruptible sleep, `--dry-run` that never mutates on-disk state, best-effort
  cross-platform PID liveness. No hard-coded path or DSN, no `while True:
  sleep()` without debounce/lock.

* **Z — Emergence `+0.5`.** The Purple lean the ticket names: the first agent
  that makes Cyclopter *self-maintaining*, and the noise artifact is a net-new
  input class for later retrieval-augmented planning. Bounded and opt-in, and
  the consuming planner is a separate ticket, so a lean — not full Purple.

Dominant spoke: `|x| = |y| = 1.0 > |z| = 0.5`; tie-break `X > Y > Z` → `X+` →
**Green**, with a mild Purple lean.
