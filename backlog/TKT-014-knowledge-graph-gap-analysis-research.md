---
id: TKT-014
title: "Research spike — vector-space gap analysis between SV modules and Markdown doctrine"
date_created: 2026-09-09
status: open
telemetry_color: pending
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
*(To be populated during execution)*
* **Agent ID:**
* **Commands Run:**
* **Artifacts Touched:**

---
## Telemetry & Evaluation
*(To be populated post-execution)*
**Final State:** `pending`
**Vector Summary:** [Leave blank for now]
