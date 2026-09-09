# TKT-014 — Findings: SV ↔ MD knowledge-graph gap analysis

**Spike, time-boxed.** Script: `gcb-python-orchestrator/scripts/kg_gap_analysis_spike.py`.
Reproduce: `python scripts/kg_gap_analysis_spike.py --json out.json`
(add `--pg-dsn <DSN>` for the throwaway `doc_rtl_embed` `pgvector` round-trip).

---

## 1. Method

| | |
|---|---|
| **Corpus** | `gcb-wdm-transceiver/rtl/*.sv` → **26 files / 27 module chunks** (one chunk per `module`/`package`); `gcb-wiki/*.md` → **17 files / 156 section chunks** (one chunk per `#`/`##`/`###` heading block, chunks < 8 tokens dropped). |
| **Embedding** | Deterministic **TF-IDF bag-of-identifiers**. No model weights, no network. Identifiers are split on `snake_case` / `camelCase` (`gcb_tensor_dma_arbiter` → `tensor`, `dma`, `arbiter`); SV keywords + English/Markdown stopwords dropped; `tf·idf` per chunk, `idf = ln((1+N)/(1+df)) + 1`, L2-normalised. Shared vocabulary **2779** terms. |
| **Similarity** | cosine (`v·w` on normalised vectors); cosine **distance** `= 1 − sim`. |
| **Gap rule** | `nearest cross-type cosine distance > τ`, **τ = 0.92** (i.e. best cross-type cosine similarity `< 0.08`). Applied per chunk and aggregated per file (a file's tie = the min distance over its chunks; the file's *worst* such tie is its headline number). |
| **Serendipity rule** | `rtl ↔ doc` pairs with `cos_sim ≥ 0.10`, ranked by `surprise = cos_sim / (surface_Jaccard + 1e-3)` (Jaccard on raw token *sets*, pre-IDF), tie-broken toward pairs whose **least-rare shared term is still rare** (`idf`). High surprise ⇒ the pair scores similar on weighted content but shares almost no literal words ⇒ the link rides on a few rare shared terms. |
| **Storage** | in-memory NumPy. `--pg-dsn` additionally builds a **throwaway** `doc_rtl_embed (id, kind CHECK IN ('rtl','doc'), source, chunk, embedding vector(N))` with an HNSW `vector_cosine_ops` index, cross-checks one KNN query (`<=>`) against NumPy, then `DROP`s the table. **`pbg_telemetry` is never touched.** |
| **Determinism** | Same inputs → byte-identical JSON on re-run (verified). `--seed` only orders exact-tie score groups. |

**`--pg-dsn` round-trip result** (ephemeral pgserver PG16 + pgvector, `--pg-dim 400`):
`doc_rtl_embed(vector(400))` + HNSW cosine index, **183 rows** inserted, KNN probe
(`gcb_tensor_broadcast_fabric`) — SQL `<=>` top-3 **= NumPy top-3 exactly**
(`0.5384, 0.6690, 0.6859`), table dropped. The pgvector path is a faithful mirror
of the in-memory math.

---

## 2. The Gap

### 2a. Undocumented silicon — `gcb_bitplane_tx_mapper.sv`

The **loneliest RTL module in the design**: nearest doctrine chunk at
**cos_dist 0.9289 / cos_sim 0.0711**, and even that "nearest" is a spurious tie to
`03_dual_mode_integration.md :: "Retained by V1.0"`. Past τ = 0.92 ⇒ **gap**.

Independent verification — `grep -niE 'bit[- ]?plane' gcb-wiki/*.md`:

* `03_dual_mode_integration.md:94` — one table cell (a V2.0 drive-scheme row).
* `goal.md:53` — one line ("bit-plane Tx buffers" in an SRAM budget table).
* `intent.md:12` — one line ("prepares the unweighted bit-planes").

Three incidental mentions, **zero doctrine sections**. Nothing in the wiki
specifies:

* how an INT4 (or INT16) operand decomposes into signed bit-planes,
* the per-colour × I/Q lane assignment the mapper drives
  (`a_c0_i`, `a_c0_q`, `a_c1_i`, `a_c1_q`, …),
* the algebraic INT16 reconstruction on the receive side.

Three RTL files depend on the concept — `gcb_bitplane_tx_mapper`,
`gcb_qam_datapath_top`, `gcb_wavelength_router` — and it is the **load-bearing
encoding that bridges the INT4 tensor datapath and the optical transport**. It
currently exists only in RTL header comments. **Actionable: a `gcb-wiki` note on
the bit-plane transmit encoding.** The next-loneliest modules — `gcb_dwdm_pkg`
(0.910), `gcb_dwdm_deskew` (0.900), `gcb_wavelength_router` (0.853),
`gcb_color_mux` (0.826) — are the same low-level DWDM-PHY cluster and are thinly
covered for the same reason.

### 2b. Doctrine with no silicon — and why that one is *not* a defect

The symmetric direction finds several doc chunks at **cos_dist ≈ 1.0000**
(exactly orthogonal to every RTL module):

| doc chunk | worst cos_dist |
|---|---|
| `04_ai_protocols_and_blue_wording.md` (Cyclopter / Blue-wording) | 1.0000 (file 0.9281) |
| `09_pbg_telemetry_vector_space.md` axis sections `3.1 X` / `3.2 Y` / `3.3 Z` | 1.0000 / 0.987 |
| `10_open_source_eda_toolchain.md` (build doctrine) | 0.9415 |
| `DECISION_LEDGER.md` | 0.9824 |

This is the method **independently rediscovering the `gcb-wiki/04` boundary
invariant**: PBG / Cyclopter / the telemetry taxonomy are *prompt-layer
protocols* that are deliberately never scaffolded into a hardware repo, and
`10_open_source_eda_toolchain.md` governs *how* RTL is built, not *what* it is.
`cos_dist → 1.0` there is empirical evidence that **no prompt-layer vocabulary
has leaked into the silicon — the boundary is holding.** So the honest reading:
**one genuine undocumented-silicon gap (2a); the "doctrine without silicon" set
is fully explained by an intentional separation, which the method usefully
confirms rather than flags.**

---

## 3. The Serendipitous Correlation

**`gcb_qam_datapath_top` ↔ `07_inline_vector_softmax.md` §3 "Hardware Softmax, Structural"**

| metric | value |
|---|---|
| cosine similarity | **0.2099** |
| surface Jaccard | 0.010 (they share ≈ 1 % of their vocabulary) |
| shared terms | **`max`** (single term, `idf` 2.63) |
| surprise score | **19.95** (top of the ranking) |

Two modules in domains that otherwise share almost nothing:

* **`gcb_qam_datapath_top`** — the optical **QAM receive datapath**. Its
  correctness-critical first step is a **max-selection** (max-likelihood /
  min-distance slice) to demodulate a received symbol to the nearest
  constellation point.
* **`07 §3`** — the **hardware softmax unit** on the transformer attention path.
  Its correctness-critical first step is the **max-subtraction** `x − max(x)`
  that keeps `exp()` from overflowing.

**The non-obvious link:** both pipelines *open with a small-vector max-reduction
as their first numerically load-bearing operation* — one for demodulation, one
for numerical stability — for entirely unrelated reasons. The same fixed-function
`argmax` / `max`-reduce primitive is a candidate for **shared hardware between the
photonic RX slicer and the Vortex softmax unit**. No prose in either corpus draws
this parallel.

### Supporting hits

* **Structural** — `gcb_tensor_address_translation` ↔ `03_dual_mode_integration.md`,
  linked *only* by **`csr`** (surprise 11.48, cos_sim 0.135): the tensor-compute
  control plane and the photonic-transport control plane independently converge on
  the same CSR / MMIO register-interface idiom.
* **Positive control** — `gcb_tensor_operand_sram` ↔
  `12_tensor_sram_allocation_strategy.md` §3.2 (shared `bank`, `macro`, `lane`;
  surface Jaccard 0.06): the method correctly connects the TKT-012 module to its
  own TKT-012 doctrine *through* the prose↔SV representation gap — evidence the
  cross-type matching does what it should.

---

## 4. What this does / does not prove

**Does:**

* Cross-type cosine over a shared identifier vocabulary is enough to (a) rank
  modules by how thinly they are documented and surface a real gap
  (`gcb_bitplane_tx_mapper`), and (b) surface a genuine cross-domain
  vocabulary collision worth a human look (`max`: QAM slice ↔ softmax).
* A `pgvector` table + HNSW cosine index reproduces the in-memory ranking exactly
  — a persistent "architectural QA" index is technically viable on the existing
  Cyclopter stack.
* The method re-derives the Doc 04 prompt-layer/silicon boundary from data alone.

**Does not:**

* **Semantic** understanding — TF-IDF matches *terminology*, not meaning. A gap
  here means "shares few identifiers with any doctrine", which is a strong hint,
  not proof of missing documentation; a human confirms (as done for
  `bit-plane`).
* **Robustness of the serendipity signal** — a single shared token drives the top
  hit. It is a lead-generator for human review, not an automated finding.
  Different `--tau` / `--sim-hi` / stoplist choices reorder the tail.
* **Coverage** — 27 module chunks and 156 section chunks is a small, hand-tuned
  corpus. Nothing here justifies an always-on service; that is Purple / a later
  ticket (TKT-014 out-of-scope items 1–2).
* **Nothing was changed** in `gcb-rtl` / `gcb-wdm-transceiver` / `gcb-host`, and
  `pbg_telemetry` was not touched. Filing the follow-on bit-plane doctrine ticket
  is a human call informed by this note.
