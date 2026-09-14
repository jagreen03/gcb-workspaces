---
id: GCB-044
title: "Ticket/prompt lifecycle discipline: filtering resolved work from active exploration via frontmatter, PBG telemetry, and append-only corrections"
date_created: 2026-09-13
status: done
# No telemetry_color / telemetry: block - by this ticket's own stated
# rule, a doctrine deliverable is never graded on the standard R^3
# vector (same pattern as TKT-000 and TKT-019.5). "done" here means
# the doctrine document is written and cross-referenced, not that any
# work was measured or ratified.
tags:
  - backlog
  - doctrine
  - process
  - pbg
  - research-operations
---

# Objective

Capture, as an explicit doctrine, a pattern this program has already
been following consistently across dozens of real tickets — but has
never written down anywhere, unlike Orange-Team doctrine
(`TKT-000-orange-team-epoch-guidance.md`). This is a **doctrine
deliverable, not graded execution** — it changes no ticket, no RTL, no
code; its only artifact is this document plus the cross-references
added to `gcb-wiki/09_pbg_telemetry_vector_space.md` and
`gcb-workspaces/README.md`.

**Why this exists now:** the Architect described the pattern from
outside — as something they'd noticed the workflow relies on — and it
matched, almost line for line, what this program's own tickets already
do. That's worth writing down precisely because it was never actually
specified: every session so far has followed it by imitation (copying
the shape of prior tickets), not by reading a rule.

## The rule, stated precisely

**Never delete a superseded or resolved ticket, prompt, or exploration
path.** Filter it out of active focus by updating its *metadata*, not
by rewriting or removing its *content*.

### 1. Frontmatter status flips

A ticket's `status:`/`telemetry_color:` frontmatter is the machine-
and human-readable filter between "active, unresolved" and "historical
record." Real, already-in-use values, not invented for this doctrine:

| `status` | `telemetry_color` | Means |
|---|---|---|
| `open` | `pending` | Active — genuinely unresolved, or explicitly awaiting Architect disposition (`GCB-041`, `GCB-043`) |
| `done` | `blue` | Resolved, real work executed and verified (`GCB-040`) |
| `done` | `green` | Resolved **and ratified** — the strongest close, used for  ratified architectural decisions (`GCB-034`) |
| `open` | `pending`, but "Update" sections present | Substantively answered but deliberately left open by design — a validation record, not the decision ticket (`GCB-035`–`GCB-038`, each explicitly "does not self-close" per their own text) |
| `done` | *(omitted, with an explanatory comment)* | Closed, real work done, but deliberately never gradeable on Spec/Quality/Emergence (an audit or doctrine deliverable, not a build) — states so explicitly rather than forcing a score (`TKT-019.5`, `TKT-000`, this ticket) |

**The status flip is the filter.** A backlog scan, a Cyclopter query, or
a human skimming the tree-view index in `gcb-workspaces/README.md` can
separate "needs attention" from "settled" without reading every
ticket's full body — but only if the frontmatter is kept honest.

### 2. PBG grading triage

`gcb-wiki/09_pbg_telemetry_vector_space.md` already defines the
scoring mechanics (the `telemetry:` vector, the frontmatter contract,
§5.3) — this doctrine adds the missing *lifecycle* rule that document
doesn't state: **`status: done` does not, by itself, mean graded** —
`TKT-019.5` is `done` with `telemetry_color` omitted entirely (its own
frontmatter comment: "by explicit Architect/Orange-Team mandate this
audit is never graded"). **The real rule: a ticket is graded only when
it represents a measured or ratified outcome on the Spec/Quality/
Emergence axes at all** — an open finding filed *for disposition*
(`GCB-041`, `GCB-043`), a closed-but-deliberately-ungraded audit
(`TKT-019.5`, `TKT-019.6`–`.8`), and a doctrine deliverable (`TKT-000`,
this ticket) are **all real, valid ways to carry no grade**,
independent of whether `status` reads `open` or `done`. **A missing
grade is not an oversight; it
is itself a signal** that the ticket is a finding, not a decision.

### 3. Append-only corrections

When a later check finds a real error in an already-written ticket,
spec entry, or code comment, **append a dated correction; do not
rewrite the original text.** Real, already-executed examples, not
hypothetical:

- `gcb-workspaces/backlog/GCB-041-single-slope-readout-integration-gap.md`: the original finding text is
  untouched; a later, dated paragraph states plainly what was checked
  and corrected, without deleting the earlier (partially superseded)
  framing.
- `gcb-spec/registers.yaml`'s `defects:` block: `DEFECT-002`/`DEFECT-004`
  kept their original `summary:`/`fix:` text verbatim; `status:
  resolved` and `fixed_in: gcb-rtl 652e21e` were **added**, not
  substituted, and the per-register `defects:` bullets were rewritten
  to say `"RESOLVED (...): [original problem, past tense] ... Kept as
  a historical record, not a live defect"` — preserving what the
  defect *was* alongside the fact that it's fixed.
- `gcb-wiki/16_hardware_parts_systems_specification.md` Part 9: a
  `**Correction, 2026-09-13**` paragraph was inserted **before** the
  original text, explicitly naming what was wrong and why, rather than
  silently replacing the incorrect claim.
- `gcb-pic-core/mmi_power_tree.py`'s own docstring: documents its own
  predecessor's `K=16` WDM-framing error inline, in the same file,
  rather than deleting the earlier reasoning — the same discipline
  applied inside source code, not only ticket prose.

**The shape is consistent across all four**: state what the earlier
text said, state what's actually true, state the evidence, and leave
both visible. A future reader — human or AI — should never have to
guess whether a claim was corrected or simply never revisited.

## What this is NOT

Not a license to leave every ticket open forever "just in case," and
not a mandate to add a correction paragraph for a merely reworded
sentence. It applies specifically to: (1) a real factual or
architectural claim that turned out to be wrong, and (2) a ticket
whose disposition (open→closed, or graded→ungraded) genuinely changed.
Cosmetic edits don't need this ceremony.

## Section 2 of the Architect's message — wiki compaction

The Architect also asked about keeping `gcb-wiki`'s derived human
views clean — pointing completed architecture questions to their
finalized `gcb-spec` counterpart, or folding them behind the 4
consolidated lenses (`lenses/`) — rather than letting resolved
material accumulate as untethered pages. **This is already this
session's own practice** (every appendix added this session cites its
real `gcb-spec`/`gcb-rtl` source rather than re-deriving facts; the
4-lens consolidation itself, done earlier this session, exists
specifically to fold what were 8+ standalone persona documents behind
fewer, broader entry points). No dedicated compaction pass was run as
part of *this* ticket — flagged as a real, separate follow-on if the
Architect wants a full audit of `gcb-wiki` for accumulated staleness,
not assumed necessary here.

**On `/compact`**: this is a Claude Code CLI command the Architect runs
in their own terminal session to compact *that session's own
conversation context* — it is not a tool this session can invoke on
the Architect's behalf, and it doesn't act on the repository content
at all (it manages the AI session's working memory, not the wiki
files). Noted for accuracy, not actioned, since it isn't something to
action from this side.

---
## Execution Log

* **Agent ID:** Lead Architect / Project Manager (Claude Sonnet 5) —
  `https://claude.ai/code/session_01Rpa9VJGe7xypzp5FkukSco`.
* **Source:** Architect's direct description of the workflow's own
  existing pattern, relayed 2026-09-13.
* **Actions:** authored this doctrine document; cross-referenced it
  from `gcb-wiki/09_pbg_telemetry_vector_space.md` §6 (Consistency
  notes) and `gcb-workspaces/README.md`'s ticket index.
* **Not changed:** any existing ticket's status, grade, or content —
  every example cited above was already in this state before this
  ticket was written; this ticket documents the pattern, it does not
  create new instances of it.

---
## Telemetry & Evaluation

No PBG grade — a doctrine deliverable, same category as `TKT-000`.

**Final State:** `done` (the doctrine document itself is complete and
cross-referenced) — there is no further "closing" action for a
doctrine ticket beyond existing and being findable.
