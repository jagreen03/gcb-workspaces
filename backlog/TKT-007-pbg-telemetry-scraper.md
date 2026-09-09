---
id: TKT-007
title: "PBG telemetry scraper — backlog frontmatter to pgvector JSONL"
date_created: 2026-09-08
status: done
telemetry_color: green
tags:
  - backlog
  - software
  - telemetry
  - tooling
---

# Objective

Build `parse_pbg_telemetry.py` — the scraper that turns the backlog's PBG
telemetry into rows for the `pgvector` store defined in
`gcb-wiki/09_pbg_telemetry_vector_space.md`. It crawls
`gcb-workspaces/backlog/TKT-*.md`, reads each file's YAML frontmatter with a
real parser (not regex), builds the vector `T = (spec, quality, emergence)` per
the doc-09 contract, computes `||T||_2`, validates the derived
`telemetry_color`, and emits one JSONL object per ticket aligned with the
`pbg_telemetry` table columns.

## Context & Constraints

* **Current State:**
  * `gcb-wiki/09` §5.3 fixes the **frontmatter contract**: a `telemetry:` block
    of `{spec, quality, emergence}` floats in `[-1, 1]` is the *source* of the
    vector; `telemetry_color` is a **derived** dominant-spoke label the scraper
    *validates*, not the source. An absent or all-zero `telemetry:` block means
    `pending`.
  * `gcb-wiki/09` §5.1 / §5.2 fix the **target**: table
    `pbg_telemetry(ticket_id, title, status, telemetry_vec vector(3),
    telemetry_color, vec_norm [generated], updated_at)`; cosine primary ANN
    index (pending rows excluded), L2 secondary, HNSW.
  * Today **no ticket carries a `telemetry:` block** — TKT-002..006 have only
    `telemetry_color: green`. The scraper must therefore also handle the
    migration case "colour present, vector block absent".
  * The `architecture-doctrine.code-workspace` launch config points its
    `program` at `${workspaceFolder:gcb-workspaces}/scripts/
    parse_pbg_telemetry.py`; this ticket places the script in
    `gcb-python-orchestrator/scripts/`. One must move — recommend the script
    lives in the orchestrator repo (Python control-plane tooling) and the
    launch-config path is corrected here.
* **Constraint:** Real YAML parsing via `python-frontmatter` (PyYAML beneath) —
  no regex frontmatter extraction. Missing / malformed inputs are reported and
  skipped, not fatal, unless `--strict`. **No database connection** in this
  script — it emits JSONL only, for a separate bulk-load step. Output keys
  match the `pbg_telemetry` columns exactly, minus the DB-generated `vec_norm`
  (the script emits it as `norm` for validation).

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-007 is Green:** a robust scraper that reads the doc-09
`telemetry:` contract with a real parser, degrades gracefully, maps the six
colours to the three axes exactly as `gcb-wiki/09` §2–3 define, computes
`||T||_2`, cross-checks `telemetry_color`, and emits clean JSONL.

* **Green (target):** `parse_pbg_telemetry.py` using `python-frontmatter` +
  `pyyaml`. Primary path reads the `telemetry: {spec, quality, emergence}`
  block; `norm = sqrt(x^2 + y^2 + z^2)`; derives the dominant-spoke label
  (doc-09 §3.4) and warns when it disagrees with the written `telemetry_color`.
  Legacy fallback synthesises the *pure spoke* vector from `telemetry_color`
  with a warning. Missing frontmatter / bad YAML / unknown colour / missing
  `id` are logged with the file path and skipped (non-zero exit only under
  `--strict`). One JSONL object per ticket:
  `{ticket_id, title, status, telemetry_vec: [x,y,z], telemetry_color, norm,
  updated_at}`. CLI: `--backlog <dir>`, `--emit jsonl`, `--out <path|->`,
  `--strict`. `requirements.txt` updated; the doctrine-workspace launch-config
  path reconciled.

* **Yellow (reject):** A regex parser that greps `telemetry_color:` out of the
  first `---` block. Breaks on any legal YAML variation (quoting, comments,
  key order, block scalars), silently misreads, and cannot see the nested
  `telemetry:` sub-block at all.

* **Red (reject):** Hard-coding the six colour→vector spokes as the *only*
  mapping and ignoring the `telemetry:` block — that rebuilds the single-scalar
  model TKT-005 replaced and discards every mixed outcome (Green-spec /
  Yellow-quality, etc.).

* **Purple / Light-gray:** not in play — this operationalises existing doctrine.

**Explicitly out of scope (separate tickets):**
1. Backfilling TKT-001..007 (and the ticket template) with `telemetry:` blocks.
2. The Postgres / pgvector instance, the `CREATE TABLE`, and the bulk-load step
   that consumes this JSONL.
3. Any clustering query, dashboard, or scheduled run.
4. Editing `gcb-wiki/09` — it is the spec this script conforms to.

## The "Green" Target

1. `gcb-python-orchestrator/scripts/parse_pbg_telemetry.py` exists, runs under
   the repo's `.venv`, and
   `python parse_pbg_telemetry.py --backlog ../gcb-workspaces/backlog --emit jsonl`
   writes valid JSONL to stdout.
2. Frontmatter is read with `python-frontmatter`; `requirements.txt` gains
   `python-frontmatter` (and `pyyaml` if not already transitive).
3. Per ticket the script builds `telemetry_vec = [spec, quality, emergence]`
   from the `telemetry:` block, each component range-checked to `[-1, 1]`.
4. `norm = sqrt(spec^2 + quality^2 + emergence^2)`, emitted to >= 6 decimals.
5. The dominant-spoke label is derived per `gcb-wiki/09` §3.4 (argmax |axis|,
   tie-break X > Y > Z, sign → spoke; norm 0 → `pending`); a mismatch with the
   file's `telemetry_color` emits a `WARNING` (fails under `--strict`).
6. Legacy handling: a file with `telemetry_color` but no `telemetry:` block
   yields the pure spoke vector — `green→[1,0,0]`, `red→[-1,0,0]`,
   `blue→[0,1,0]`, `yellow→[0,-1,0]`, `purple→[0,0,1]`,
   `light-gray→[0,0,-1]`, `pending→[0,0,0]` — plus `WARNING: legacy scalar
   telemetry`.
7. Robustness: no frontmatter, unparseable YAML, missing `id` / `title`,
   out-of-range component, unknown colour — each logged with the file path and
   skipped; exit 0 unless `--strict` (which exits non-zero if any file was
   skipped or any label mismatched).
8. Output objects use exactly the keys `ticket_id, title, status,
   telemetry_vec, telemetry_color, norm, updated_at` (`updated_at` = file mtime
   as ISO-8601 UTC). Column-aligned with `pbg_telemetry` minus the generated
   `vec_norm`.
9. The `architecture-doctrine.code-workspace` launch-config `program` path is
   updated to the orchestrator location (or the script is placed where the
   config already points — pick one, note it).
10. `--help` documents all four flags. No database driver is imported.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Lead Python Developer, software-control workspace)
* **Commands Run:**
  * `.venv/Scripts/python.exe -m pip install python-frontmatter` (pulls PyYAML
    6.0.3; `python-frontmatter` 1.3.0) into `gcb-python-orchestrator/.venv`
    (Python 3.13.7).
  * `python scripts/parse_pbg_telemetry.py --help` → all four flags documented.
  * `python scripts/parse_pbg_telemetry.py` → 4 rows emitted (TKT-003..006),
    3 skipped (TKT-001/002/007 `pending`), 4 legacy-scalar warnings, 0 colour
    mismatches; JSONL to stdout, log to stderr.
  * `... --out scripts/telemetry_export.jsonl` → file written; every line
    re-parses as JSON (validated); file removed after the check.
  * Synthetic `--backlog <scratch>` run with three `telemetry:`-block fixtures
    (mixed `(0.5,-0.5,0)` → norm 0.707; block/label disagreement
    `(0.5,1.0,0.5)` → derived `blue` vs written `green`, WARNING + counted;
    `(1.0,0.5,1.0)` no colour → derived `green`, norm 1.5) → `--strict`
    returned exit 1 on the disagreement. Fixtures removed.
  * `python -m py_compile scripts/parse_pbg_telemetry.py` → clean.
* **Artifacts Touched:**
  * `gcb-python-orchestrator/scripts/parse_pbg_telemetry.py` — NEW. Layered
    frontmatter reader (`python-frontmatter` → PyYAML → a small stdlib
    YAML-subset fallback for the ticket template, reached only if neither
    library is installed — not the primary path). Per file: resolve
    `ticket_id` (frontmatter `id`, else `TKT-NNN` from the filename), `title`,
    `status`.
    * **Primary path** — a `telemetry: {spec, quality, emergence}` block is the
      vector; each component range-checked to `[-1, 1]`; `telemetry_color` is
      derived per doc-09 §3.4 (`argmax |axis|`, tie-break X>Y>Z, sign→spoke;
      origin→`pending`) and a disagreement with the written `telemetry_color`
      logs a WARNING and counts as a mismatch.
    * **Legacy path** — `telemetry_color` present, no block → the pure spoke
      vector (`green→[1,0,0]`, …, `light-gray→[0,0,-1]`) + a
      `legacy scalar telemetry` WARNING.
    * Skips (logged with the file path, run continues): no frontmatter,
      unparseable YAML, no `id`/`title`, out-of-range component, unknown
      colour, and — unless `--include-pending` — `pending` / origin.
    * Emits one JSONL object per ticket with exactly
      `ticket_id, title, status, telemetry_vec ([x,y,z]), telemetry_color,
      norm (‖T‖₂, 9 dp), updated_at (file mtime, ISO-8601 UTC)` — aligned with
      the `pbg_telemetry` columns minus the DB-generated `vec_norm`.
    * CLI: `--backlog` (default `../../gcb-workspaces/backlog` relative to the
      script), `--emit jsonl`, `--out <path|->`, `--include-pending`,
      `--strict` (exit 1 if anything was skipped or any colour mismatched).
      No database driver imported.
  * `gcb-python-orchestrator/requirements.txt` — added `python-frontmatter`
    and `pyyaml`.
  * `gcb-workspaces/architecture-doctrine.code-workspace` — the
    `PBG: Parse backlog telemetry` launch config `program` path corrected to
    `${workspaceFolder:gcb-workspaces}/../gcb-python-orchestrator/scripts/
    parse_pbg_telemetry.py` (item 9 — script lives in the orchestrator repo).
  * NOT changed: `gcb-wiki/09` (the spec this conforms to); no DB stood up; no
    `telemetry:` blocks backfilled (separate ticket).
* **Sample output** (default run, current backlog):
  ```json
  {"ticket_id": "TKT-003", "title": "Widen tensor-memory addressing past 4 GiB with a formal translation layer", "status": "done", "telemetry_vec": [1.0, 0.0, 0.0], "telemetry_color": "green", "norm": 1.0, "updated_at": "2026-09-09T03:32:48.856526+00:00"}
  {"ticket_id": "TKT-006", "title": "Plumb the dispatcher [119:112] reserved byte to the BPR base-select override", "status": "done", "telemetry_vec": [1.0, 0.0, 0.0], "telemetry_color": "green", "norm": 1.0, "updated_at": "2026-09-09T03:51:09.244551+00:00"}
  ```

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** Scraper delivered to the Green Target.
`gcb-python-orchestrator/scripts/parse_pbg_telemetry.py` reads backlog
frontmatter with `python-frontmatter` + PyYAML (small stdlib fallback, not a
regex parser), builds `T = (spec, quality, emergence)` from the doc-09 §5.3
`telemetry:` block when present, otherwise synthesises the pure spoke from
`telemetry_color` with a legacy warning; validates the derived dominant-spoke
label (§3.4) and flags disagreements; computes `‖T‖₂`; skips pending / missing
/ malformed with logged reasons; emits JSONL keyed exactly to the
`pbg_telemetry` columns. Verified against the live backlog (4 emitted, 3
skipped, 0 mismatch) and synthetic `telemetry:`-block fixtures (mixed vectors,
a real derived-vs-written mismatch, `--strict` → exit 1). `requirements.txt`
updated; the `architecture-doctrine` launch-config path reconciled to the
orchestrator location. Out of scope and untouched: the `telemetry:`-block
backfill, the Postgres/pgvector instance, and any load step.
