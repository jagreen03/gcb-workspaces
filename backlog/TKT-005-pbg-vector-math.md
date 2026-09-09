---
id: TKT-005
title: "Formalize the PBG telemetry taxonomy as a 3D bipolar vector space"
date_created: 2026-09-08
status: done
telemetry_color: green
tags:
  - backlog
  - doctrine
  - wiki
  - telemetry
  - math
---

# Objective

Turn the PBG telemetry taxonomy from six qualitative labels into a computable
vector. Every backlog ticket already carries an "AI Orchestration Priorities
(PBG Evaluation)" section and a `telemetry_color` frontmatter field, but the
colours are prose — there is no way to say an outcome was "Green on
specification but Yellow on engineering quality", and nothing for the planned
`parse_pbg_telemetry.py` scraper (see `architecture-doctrine.code-workspace`) to
load into pgvector. This ticket authors a formal **design note in `gcb-wiki`**
defining the taxonomy as a 3D bipolar coordinate system in R^3: three
orthogonal axes, six poles ("spokes"), a per-axis scoring rubric, the L2
magnitude semantics, and the pgvector database schema the scraper will target
for telemetry clustering.

The axes, as fixed by doctrine:

| Axis | + pole (+1) | - pole (-1) | Reads as |
|---|---|---|---|
| **X — Specification** | Green | Red | in-spec / done-right  vs  brittle debt / spec violation |
| **Y — Quality** | Blue | Yellow | sustainable engineering  vs  athletic / expedient workaround |
| **Z — Emergence** | Purple | Light-Gray | strategic net-new capability  vs  low-signal / deferrable |

## Context & Constraints

* **Current State:**
  * PBG is six named labels — Purple, Blue, Green, Yellow, Red, Light-Gray —
    used qualitatively in each ticket's PBG-evaluation section and collapsed to
    a single `telemetry_color` enum (`pending` | `green` | ...) plus a free-text
    "Vector Summary" line in the Telemetry section.
  * A single scalar `telemetry_color` cannot represent a mixed outcome
    (e.g. Green-X with Yellow-Y). The six colours are *already* conceptually
    three opposed pairs; nobody has written that down as axes.
  * `architecture-doctrine.code-workspace` carries a launch config for a
    not-yet-written `parse_pbg_telemetry.py` that will "scrape the YAML
    frontmatter from our backlog tickets for our pgvector database". That
    script has no schema to target — this note defines it.
  * TKT-001..004 already carry prose PBG evaluations. The scheme must be able
    to encode those *as they stand*; backfilling their frontmatter with numbers
    is a follow-on, not this ticket.
  * `gcb-wiki/04_ai_protocols_and_blue_wording.md` already discusses the
    prompt-layer PBG/PGB protocol and states a boundary invariant: this
    protocol must not be scaffolded into any hardware or host-orchestration
    repository. The telemetry vector space is project-management doctrine — it
    lives in `gcb-wiki` and `gcb-workspaces` only.
* **Constraint:**
  * Deliverable is one Markdown design note in `gcb-wiki`, following the repo's
    `NN_topic.md` convention (next free index is `09_`), linked from
    `gcb-wiki/README.md` and noted in `gcb-wiki/DECISION_LEDGER.md`.
  * The six colour names are **fixed**. No renaming, no re-meaning, no adding a
    seventh. The note *binds* each existing colour to exactly one axis pole; it
    does not invent taxonomy.
  * The maths must be explicit and self-consistent: axis definitions, a bounded
    per-axis scoring rubric, the `||T||_2` formula with its range, and worked
    examples that round-trip against the rubric.
  * The pgvector section must be concrete enough to implement against: column
    type, distance operator + rationale, index recommendation, and the exact
    frontmatter key(s) and enum-to-number rules the scraper will parse.
  * No code. `parse_pbg_telemetry.py`, the Postgres instance, migrations, and
    any dashboard are out of scope.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-Gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-005 is Green:** a clean, mathematically sound Markdown
document in `gcb-wiki` detailing the axes, the pole definitions, the scoring
rubric, the magnitude semantics, worked examples, and the database-schema
implications — internally consistent, no hand-waving.

* **Green (target):** The `gcb-wiki` design note as scoped: three orthogonal
  bipolar axes each bound to two of the six existing colours; a bounded
  per-axis scoring rubric; `T = (x, y, z)` in `[-1, 1]^3` with `||T||_2 =
  sqrt(x^2 + y^2 + z^2)` in `[0, sqrt(3)]` and its interpretation (direction =
  flavour, magnitude = decisiveness, origin = pending); >= 3 worked examples
  drawn from real tickets; a pgvector schema section (column, distance metric,
  index, frontmatter contract). Dimensional analysis and the examples check
  out.

* **Yellow (reject):** A prose "here is roughly how the colours feel" note with
  no numeric rubric and no schema. It leaves `parse_pbg_telemetry.py` still
  undefined and re-imports the subjectivity that vectorising PBG is meant to
  remove.

* **Red (reject):** Renaming or re-meaning any of the six colours, adding a
  seventh, or collapsing the three axes into a single "good vs bad" scale to
  make it "simpler". That breaks every existing ticket's PBG section and
  discards the orthogonality that is the entire point.

* **Blue:** the rigour — explicit rubric, dimensional analysis, examples that
  encode and decode consistently, a schema an engineer can run `CREATE TABLE`
  against.

* **Purple / Light-Gray (not the target):** This formalises existing doctrine;
  it is not a new platform capability (not Purple). Leaving PBG as unstructured
  labels indefinitely (Light-Gray) blocks the telemetry-clustering roadmap and
  is not acceptable.

**Explicitly out of scope (separate tickets):**
1. Writing `parse_pbg_telemetry.py` — this note defines the contract it
   consumes.
2. Backfilling TKT-001..004 (and the template) with numeric telemetry vectors.
3. Standing up Postgres + pgvector, migrations, and the ingestion pipeline.
4. Any clustering visualisation or dashboard over the vectors.
5. Changing the qualitative PBG-evaluation prose format used in tickets.

## The "Green" Target

A "Green" outcome is a single `gcb-wiki` design note such that:

1. It is committed as `gcb-wiki/09_pbg_telemetry_vector_space.md` (or the next
   free `NN_`), linked from `gcb-wiki/README.md`, with a one-line entry in
   `gcb-wiki/DECISION_LEDGER.md`.
2. The three axes — Specification (X), Quality (Y), Emergence (Z) — are each
   defined as orthogonal and bipolar, with each pole bound to exactly one of
   the six existing colour names: `+X = Green, -X = Red; +Y = Blue, -Y =
   Yellow; +Z = Purple, -Z = Light-Gray`. No colour is renamed or redefined.
3. A per-axis **scoring rubric** on a bounded ordinal scale (e.g.
   `{-1, -0.5, 0, +0.5, +1}`) with a one-line criterion for each level on each
   axis, so two readers scoring the same ticket land on the same vector.
4. The telemetry vector is defined as `T = (x, y, z)` with each component in
   `[-1, 1]`; the note gives `||T||_2 = sqrt(x^2 + y^2 + z^2)`, its range
   `[0, sqrt(3)]`, and the semantics: unit direction `T / ||T||_2` = the
   outcome's *flavour*, magnitude = *decisiveness/intensity*, origin `(0,0,0)` =
   pending / uncharacterised. It notes the single-axis Green result `(1,0,0)`
   has norm 1 and a strong two-axis result such as Green+Blue `(1,1,0)` has
   norm `sqrt(2)`.
5. At least **three worked examples** encoding real tickets — e.g. TKT-002
   (pure structural pass, ~`(1, 0, 0)`), TKT-004 (decisive in-spec decision
   delivered with rigour, ~`(1, 0.5, 0)` or similar), and a mixed case
   (Green spec / Yellow quality, e.g. `(0.5, -0.5, 0)`) — each with its
   computed norm and a sentence of justification.
6. A **pgvector schema** section: a `telemetry_vec vector(3)` column sketch
   (`CREATE TABLE` / `ALTER TABLE` DDL), the chosen distance operator for
   telemetry clustering (cosine vs L2) **with rationale**, an ANN index
   recommendation (HNSW or IVFFlat + `vector_cosine_ops` / `vector_l2_ops`),
   and the exact ticket-frontmatter contract the future scraper reads — key
   name(s), whether values are the colour enums or the numeric scores, and the
   enum-to-number mapping.
7. A backwards-compatibility statement: `telemetry_color` stays as a
   human-readable **derived** label (dominant spoke = `argmax |axis|` with its
   sign), and existing prose PBG-evaluation sections are untouched.
8. The document is internally consistent: dimensional analysis holds and every
   worked example encodes and decodes against the stated rubric.
9. No code, no schema migration run, none of the five out-of-scope items
   touched.

---
## Execution Log

* **Agent ID:** Claude Sonnet 5 — session_01Rpa9VJGe7xypzp5FkukSco (acting as
  Lead Technical Writer)
* **Commands Run:** none — authoring task. Cross-checked against
  `gcb-wiki/README.md` (doc-index convention), `gcb-wiki/DECISION_LEDGER.md`
  (ledger table columns), `gcb-wiki/04_ai_protocols_and_blue_wording.md` (the
  "PBG is not GCB hardware" boundary invariant), and TKT-001…004's PBG
  evaluation sections (the outcomes the scheme must be able to encode).
* **Artifacts Touched:**
  * `gcb-wiki/09_pbg_telemetry_vector_space.md` — NEW. The design note.
    * **§1** three orthogonal bipolar axes, each pole bound to one existing
      colour with no renaming: `+X` Green / `-X` Red (Specification), `+Y` Blue
      / `-Y` Yellow (Quality), `+Z` Purple / `-Z` Light-Gray (Emergence); an
      ASCII 3-axis sketch; the six spokes as $\pm$ unit basis vectors.
    * **§2** `T = (x, y, z)`, each component in `[-1.0, 1.0]`;
      `||T||_2 = sqrt(x^2+y^2+z^2)` in `[0, sqrt(3)]`; direction = flavour,
      magnitude = decisiveness, origin = pending; the `(1,0,0)=1`,
      `(1,1,0)=sqrt(2)`, `(1,1,1)=sqrt(3)` anchors.
    * **§3** per-axis scoring rubric on `{-1, -0.5, 0, +0.5, +1}` with a
      one-line criterion for every level on every axis, plus the derived
      `telemetry_color` rule (`argmax |axis|`, tie-break X>Y>Z, sign → spoke;
      norm 0 → `pending`).
    * **§4** four worked examples — TKT-002 `(1,0,0)` norm 1.000; TKT-004
      `(1,0.5,0)` norm 1.118; TKT-003 `(1,0.5,0.5)` norm 1.225; a hypothetical
      "shipped but hacked" `(0.5,-0.5,0)` norm 0.707 — each with reasoning and
      a round-trip consistency check.
    * **§5** `pgvector` schema: `telemetry_vec vector(3)` + generated
      `vec_norm` column DDL; **cosine** primary index (`vector_cosine_ops`,
      excluding `pending`) for flavour clustering with rationale, **L2**
      secondary; HNSW-over-IVFFlat justification; an example nearest-neighbour
      query; and the exact ticket-frontmatter contract — a new `telemetry:
      {spec, quality, emergence}` block of floats, `telemetry_color` kept as
      the validated derived label, `pending` when the block is absent/all-zero.
    * **§6** consistency notes — dimensional analysis, orthogonality as a
      modelling choice, "the label loses information by design".
  * `gcb-wiki/README.md` — added the row-09 entry to the hierarchical-document
    table.
  * `gcb-wiki/DECISION_LEDGER.md` — added
    `doctrine.pbg.telemetry-vector-space` (`Accepted`, evidence
    `09_…`; TKT-005, dated 2026-09-08).
* **Out of scope, unchanged (separate follow-ons):** `parse_pbg_telemetry.py`
  itself; backfilling TKT-001…005 and the ticket template with `telemetry:`
  blocks; standing up Postgres + pgvector; any dashboard.

---
## Telemetry & Evaluation

**Final State:** `green`

**Vector Summary:** Doctrine note delivered exactly to the Green Target.
`gcb-wiki/09_pbg_telemetry_vector_space.md` binds the six unchanged PBG colours
to the poles of three orthogonal bipolar axes (X Specification, Y Quality,
Z Emergence), defines `T ∈ [-1,1]^3` and `||T||_2 ∈ [0, √3]` with a
direction/magnitude reading, gives a `{-1,-0.5,0,+0.5,+1}` per-axis rubric with
per-level criteria, works four real/realistic ticket outcomes with norms and a
round-trip check, and specifies the `pgvector(3)` schema — cosine primary index
with rationale, L2 secondary, HNSW choice, and the `telemetry:` frontmatter
contract the scraper will validate `telemetry_color` against. Linked from
`gcb-wiki/README.md`; recorded in `DECISION_LEDGER.md`. No code, no schema
migration, no colour renamed. Follow-ons (the scraper, frontmatter backfill,
the database instance) are explicitly out of scope and untouched.
