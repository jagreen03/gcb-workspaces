---
id: TKT-014
title: "Research spike — vector-space gap analysis between SV modules and Markdown doctrine"
date_created: 2026-09-09
status: done
telemetry_color: green
telemetry:
  spec: 1.0
  quality: 1.0
  emergence: 0.5
tags:
  - backlog
  - research
  - spike
  - cyclopter
  - pgvector
  - knowledge-graph
---

# Objective

**Research spike (time-boxed).** Embed SystemVerilog module definitions and
Markdown doctrine into one vector space via the Cyclopter `pgvector` store, and
use cross-type cosine distance to (a) find **architectural gaps** — an RTL module
with no doctrine near it, or a doctrine section with no RTL near it — and (b)
surface **unexpected semantic correlations** ("computational serendipity") worth
a human look. The deliverable is a documented proof-of-concept script plus a
findings write-up, **not** a maintained pipeline.

## Context & Constraints

* **Current State:**
  * The Cyclopter store exists (`TKT-011`) but holds only 3-D ticket-outcome
    vectors in `pbg_telemetry`. Text embeddings are a different dimension and a
    different table — this spike defines a **throwaway** schema and never
    touches `pbg_telemetry`.
  * Corpus is small and stable: `gcb-*/rtl/*.sv` module headers / definitions
    and `gcb-wiki/*.md` section text.
  * No sentence-embedding model is wired into the orchestrator today (`torch` is
    in `requirements.txt`; an embedding model is not). Offline / local execution
    is required; if no model is available the spike may use a documented
    deterministic fallback embedder and say so plainly.
  * `gcb-wiki/04` boundary: research tooling lives in `gcb-python-orchestrator`
    or a `gcb-workspaces/research/` dir — never scaffolded into `gcb-rtl` /
    `gcb-wdm-transceiver` / `gcb-host`.
  * "Gap" and "serendipity" need operational definitions up front so the spike
    is falsifiable: a *gap* is a chunk whose nearest cross-type neighbour is
    beyond a stated cosine threshold τ; *serendipity* is a high-similarity
    `rtl <-> doc` pair that shares few surface keywords.
* **Constraint:** This is a spike — a self-contained, reproducible Python PoC
  plus a short findings `.md`, explicitly **not** a long-lived service. Local
  offline embedding, fixed random seed, deterministic re-run. A throwaway
  `doc_rtl_embed` table (`vector(N)`), scripted create/drop, separate from
  `pbg_telemetry`. No committed model weights. The findings must name at least
  one concrete gap and one concrete correlation, each with its distance, and a
  "what this does / does not prove" section.

### AI Orchestration Priorities (PBG Evaluation)

Taxonomy: **Purple** = strategic net-new platform capability; **Blue** = solid
sustainable engineering on the target architecture; **Green** = gap cleanly
closed, in-spec, "done right"; **Yellow** = athletic / expedient workaround that
unblocks now but incurs architectural drift; **Red** = brittle technical debt,
high-maintenance, likely to regress; **Light-gray** = low-signal, deferrable, or
accept-the-limitation.

**The target for TKT-014 is Green (a spike delivered well), with a Purple
lean** — it probes a net-new direction: whether the vector store can drive
architectural QA and "wander" the space for correlations, which no current tool
does.

* **Green (target):** a committed `research/` PoC that embeds the SV + MD
  corpus into a `vector(N)` table with an HNSW cosine index, runs cross-type
  cosine KNN both directions, and a `FINDINGS` markdown that identifies **>= 1
  real gap** (module with no doctrine within τ, or orphan doctrine) and **>= 1
  non-obvious correlation**, each with numbers, plus a caveats section. Fully
  reproducible from the committed script + a fixed seed.

* **Yellow (reject):** eyeballing a t-SNE / UMAP plot with no queryable table,
  or embedding only one side (SV *or* MD) so no cross-type query is even
  possible, or a "finding" with no distance attached.

* **Red (reject):** mutating `pbg_telemetry` or reusing its 3-D vectors for
  text, committing multi-GB model weights, or presenting the spike output as a
  production-ready gap-analysis pipeline.

* **Purple / Light-gray:** a live "architectural gap dashboard" / always-on
  correlation service is Purple / a later ticket. Not running the spike
  (Light-gray) leaves the "can the store do architectural QA" question
  unanswered.

**Explicitly out of scope (separate tickets):**
1. Any always-on gap-analysis service, dashboard, or CI check.
2. Making the text-embedding table a permanent part of the Cyclopter store.
3. Fine-tuning or shipping an embedding model.
4. Acting on the gaps — filing the follow-on RTL / doctrine tickets is a human
   call informed by the findings.

## The "Green" Target

1. `gcb-python-orchestrator/research/kg_gap_analysis.py` (or
   `gcb-workspaces/research/…`) — reads a configurable set of `*.sv` + `*.md`,
   chunks at module / section granularity, embeds with a named local model or a
   documented deterministic fallback (fixed seed).
2. A throwaway table `doc_rtl_embed (id text, kind text CHECK (kind IN
   ('rtl','doc')), source text, chunk text, embedding vector(N))` plus an HNSW
   `vector_cosine_ops` index; create + drop scripted; **never** the same table
   as `pbg_telemetry`.
3. Cross-type cosine KNN: for each `rtl` chunk, its nearest `doc` chunks and the
   distances; and the reverse for each `doc` chunk.
4. A stated gap rule (`nearest cross-type distance > τ`, τ given) applied both
   ways; the resulting list of "module with no doctrine" / "doctrine with no
   RTL".
5. A serendipity pass: top-N high-similarity `rtl <-> doc` pairs with low
   surface-keyword overlap, for human review.
6. `research/FINDINGS-kg-gap.md`: method, τ, the embedder used, **>= 1 named gap
   and >= 1 named correlation with distances**, and an explicit "what this
   does / does not prove" section.
7. `--help`, a fixed seed, deterministic re-run; `requirements.txt` notes the
   embedding dependency (or records that the fallback needs none).
8. Nothing lands in `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host`;
   `pbg_telemetry` is untouched; the script and its table are self-contained and
   disposable.

---
## Execution Log

* **Agent ID:** Lead AI Researcher (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`

* **Commands Run:**
  * `python scripts/kg_gap_analysis_spike.py --json out.json` — the spike:
    26 `.sv` → 27 module chunks, 17 `.md` → 156 section chunks, vocab 2779,
    deterministic TF-IDF + cosine, τ = 0.92.
  * `python scripts/kg_gap_analysis_spike.py --json a.json` ×2 →
    **byte-identical** output (deterministic re-run confirmed).
  * `python scripts/kg_gap_analysis_spike.py --pg-dsn <pgserver> --pg-dim 400`
    — builds a throwaway `doc_rtl_embed(id, kind CHECK IN ('rtl','doc'),
    source, chunk, embedding vector(400))` + HNSW `vector_cosine_ops` index,
    183 rows, KNN probe SQL `<=>` top-3 **== NumPy cosine top-3 exactly**
    (`agree: True`), then `DROP TABLE`. `pbg_telemetry` untouched.
  * `grep -niE 'bit[- ]?plane' gcb-wiki/*.md` — 3 incidental one-line
    mentions, **zero doctrine sections** → confirms the headline gap.

* **Findings** (full detail: `backlog/TKT-014-FINDINGS.md`):
  * **Gap — undocumented silicon:** `gcb_bitplane_tx_mapper.sv` is the
    loneliest RTL module (nearest doctrine `cos_dist 0.9289 / cos_sim 0.0711`,
    past τ). grep confirms the bit-plane transmit encoding — the load-bearing
    bridge between the INT4 tensor datapath and the optical transport — has no
    `gcb-wiki` section. The symmetric "doctrine with no silicon" set
    (`04_ai_protocols…`, `09` axis sections, `10_open_source_eda…` at
    `cos_dist ≈ 1.0`) is **not a defect** — the method re-derives the
    `gcb-wiki/04` prompt-layer/silicon boundary and shows it is holding.
  * **Serendipitous correlation:** `gcb_qam_datapath_top` ↔
    `07_inline_vector_softmax.md` §3, `cos_sim 0.2099`, surface Jaccard 0.010,
    linked *only* by `max` (surprise 19.95, top of the ranking). Both pipelines
    open with a small-vector **max-reduction** as their first numerically
    load-bearing step — QAM max-likelihood slice vs. softmax max-subtraction —
    so a shared `argmax`/`max`-reduce primitive is a candidate for common
    hardware across the photonic RX and the Vortex softmax unit. Runner-up
    (structural): `gcb_tensor_address_translation` ↔ `03_dual_mode_integration`
    linked only by `csr`.

* **Artifacts Touched:**
  * `gcb-python-orchestrator/scripts/kg_gap_analysis_spike.py` (new) — the PoC
    (per the Task-1 instruction; `scripts/` rather than the ticket-draft's
    `research/` path, and the findings live in this backlog as
    `TKT-014-FINDINGS.md` rather than `research/FINDINGS-kg-gap.md`, both per
    the executing instruction).
  * `gcb-python-orchestrator/requirements.txt` — comment recording that the
    TF-IDF fallback embedder needs no extra dependency (numpy suffices).
  * `gcb-workspaces/backlog/TKT-014-FINDINGS.md` (new) — method, τ, the gap,
    the correlation, and a "what this does / does not prove" section.
  * Nothing in `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host`; `pbg_telemetry`
    untouched; the `doc_rtl_embed` table is created and dropped by the script.

---
## Telemetry & Evaluation

**Final State:** `Green`

**Vector Summary:** `T = (spec +1.0, quality +1.0, emergence +0.5)`,
`‖T‖₂ = √2.25 = 1.5`.

* **X — Specification `+1.0`.** All eight Green-Target criteria met: a
  configurable PoC that chunks `*.sv` at module and `*.md` at section
  granularity, embeds both with a documented deterministic fallback (fixed by
  construction), runs cross-type cosine KNN **both directions**, applies a
  stated gap rule (`τ = 0.92`), runs a low-surface-overlap serendipity pass,
  and — via `--pg-dsn` — round-trips a throwaway `doc_rtl_embed` `vector(N)`
  table with an HNSW cosine index that reproduces the NumPy ranking exactly
  before dropping itself. `--help`, fixed seed, byte-identical re-run. A
  `FINDINGS` doc names a real gap and a real correlation with numbers and a
  caveats section. Nothing touches the hardware repos or `pbg_telemetry`.

* **Y — Quality `+1.0`** (to the spike's own bar). Deterministic and
  reproducible; the pgvector path is a genuine cross-check, not decoration
  (`SQL <=> == NumPy`, `agree: True`); the caveats section explicitly
  down-scopes the serendipity signal to a human lead-generator and states the
  TF-IDF-is-not-semantics limitation; configurable globs / τ / thresholds; no
  `pbg_telemetry` contamination.

* **Z — Emergence `+0.5`.** The Purple lean the ticket names: it probes — and
  answers yes to — "can the vector store drive architectural QA and surface
  serendipitous cross-domain links", which no current tool does. Bounded
  (throwaway table, no service), so a lean, not full Purple. The always-on
  gap-analysis service remains Purple / a later ticket.

Dominant spoke: `|x| = |y| = 1.0 > |z| = 0.5`; tie-break `X > Y > Z` → `X+` →
**Green**, with a mild Purple lean.
