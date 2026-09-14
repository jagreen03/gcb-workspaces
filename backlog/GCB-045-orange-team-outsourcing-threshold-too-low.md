---
id: GCB-045
title: "Orange-Team Collaborator outsourcing threshold is set too low - drafting the gcb-kelvin prompt did most of the diagnostic work internally, at medium effort, before any external AI was involved"
date_created: 2026-09-13
status: open
telemetry_color: pending
priority: low - deferred
tags:
  - backlog
  - process
  - research-operations
  - orange-team
  - doctrine
---

# Objective

Fix a real process flaw the Architect identified directly, not
inferred: drafting this session's rewritten `gcb-kelvin` prompt for
`gcb-wiki/appendices/orange-team-collaborator.md` required finding a
real, previously-missed analytic tool (`comparator_noise.py`),
re-deriving its noise-bandwidth formula, and ranking three candidate
causes for a real ≈2× `g_m` discrepancy — genuine diagnostic reasoning,
done at whatever effort this session was running, **before** any
external frontier AI was ever consulted. **That is direct evidence the
page's implicit threshold for "this needs outsourcing to a frontier
model" is set too low** — the page's own premise (external high-effort
reasoning is needed for blockers internal medium-effort work can't
close) was undermined by the same turn that built the outsourcing
prompt.

**Explicitly deferred, per the Architect's own instruction**: this is
real, identified work, not urgent — fix it later, when token budget
allows higher-effort attention, not now while deliberately running at
medium effort. Filed at low priority so it doesn't compete with active
medium-effort-appropriate backlog items.

## The Architect's own words, quoted directly

> "I am asking for an improvement in the wiki so we do not ask external
> help that is not needed. This response proves the wiki ORANGE-TEAM
> added effort is at least partially flawed and we got help we did not
> need."

## What actually happened, traced plainly

1. The Architect asked for the three `orange-team-collaborator.md`
   prompts to be rewritten in a frontier-optimized structure (persona,
   failure ledger, hard constraints, output contract).
2. While rewriting the `gcb-kelvin` prompt specifically — an act of
   *drafting a request for external help* — this session's own
   fact-checking pass found: (a) today's earlier single-transistor
   noise estimate used the wrong load topology, (b) a real,
   already-built multi-stage analytic noise roll-up script
   (`comparator_noise.py`) existed in `gcb-spec` and had simply never
   been connected to the day's `g_m`/`g_ds` extraction, and (c) that
   script's own measured `g_m` values disagree with today's direct
   extraction by roughly 2×.
3. **All of that — including a first-pass ranking of candidate causes
   for the discrepancy — was produced internally, as a side effect of
   writing the prompt, not as the prompt's intended output.** The
   external-AI prompt that resulted asks a frontier model to do
   diagnostic work this session had already substantially started
   doing itself, unprompted, at whatever effort level was active.

## Why this is a real process flaw, not just "the prompt was thorough"

The Orange-Team Collaborator's own stated purpose
(`research-operations.md`) is to route a genuine blocker to an
external Research Scientist (human or AI) **only once internal work has
established that the blocker is real and internal effort alone can't
close it.** This session's own behavior shows the opposite order
happening in practice: the act of *preparing* the outsourcing prompt
routinely surfaces real findings that weren't there before drafting
started, which means the page is being reached for — or at least
drafted against — before confirming internal medium-effort work has
actually been exhausted first.

**This is not a claim that outsourcing to frontier AI is never useful**
— `gcb-lumen`'s own Pass 1 (the external AI's genuinely useful SAX
suggestion, evaluated and partly adopted this same day) is a real
counter-example where outsourcing added value this program's own
effort hadn't yet reached. The flaw is specifically: **no gate exists
between "a problem repo has an open question" and "draft an external-AI
prompt for it"** — nothing currently forces a documented internal pass
first, at the effort level actually available, before reaching for the
page.

## What a fix should probably look like (not designed here — deferred)

Sketched only, not committed to, since this ticket is explicitly
deferred:

- Add an explicit gate to `research-operations.md` and/or
  `orange-team-collaborator.md`: before drafting (not just before
  sending) an outsourcing prompt, state in writing what internal,
  medium-effort-available work was actually tried and where it
  stalled — the same discipline `TKT-033`/`GCB-044` already apply to
  *findings*, extended to cover the *decision to outsource* itself.
- Possibly restructure the workflow so "draft the external prompt" is
  a later step than "do a real internal diagnostic pass and write down
  what's left over" — rather than the drafting step being where the
  internal diagnostic work happens to occur, as it did this session.
- Re-examine whether `gcb-lambda`'s Task-1 "stress-test these findings"
  framing (this session's other rewritten prompt) has the same issue —
  it asks an external AI to critique internally-produced findings,
  which may be legitimate external-review value (the
  `research-operations.md` "External Reviewer" role, distinct from
  "Research Scientist") or may be more internal-effort work dressed as
  an outsourcing prompt. Not resolved here.

## What this ticket is NOT

Not a claim that today's `orange-team-collaborator.md` rewrite was
wasted work — the real findings it surfaced (the load-topology error,
the `comparator_noise.py` discovery, the `g_m` discrepancy) are real
and already committed (`gcb-kelvin@ce381ec`). Not a mandate to revert
the rewrite. Not urgent — explicitly deferred per the Architect's own
instruction to work on this "later work when we can afford tokens."

## Related

`gcb-wiki/appendices/orange-team-collaborator.md` (the page this
concerns), `gcb-wiki/appendices/research-operations.md` (the roles/
workflow this ticket proposes tightening), `gcb-kelvin/
FINDINGS-2026-09-13-manual-noise-v1.md`'s correction section (the real
diagnostic work that triggered this finding), `GCB-044` (the adjacent
doctrine ticket on ticket-lifecycle discipline — this is a sibling
doctrine question about the outsourcing *decision* rather than ticket
*lifecycle*).

## Update, 2026-09-14 — a second, live confirming instance, same day as filing

Continuing the standing loop (at medium effort, per the Architect's own
instruction not to spend higher effort on this ticket specifically),
the `gcb-kelvin` `g_m` "discrepancy" this ticket's own motivating
example cited — the one the rewritten wiki prompt asked a frontier AI
to diagnose — was itself resolved by internal, medium-effort checking
within the same day: re-running the real extraction deck found roughly
half of all attempts deterministically fail to converge to a physical
operating point, and the original 779 µS figure was never checked for
that before being trusted (`gcb-kelvin@a27f1f0`). The wiki prompt was
corrected in place (`gcb-wiki@845c0b5`) rather than left pointing at a
resolved non-issue. **This is not new evidence requiring this ticket's
own scope to change** — it's a second live instance of exactly the
pattern this ticket already describes, recorded here because it
happened to the same example this ticket cites, not because the fix
sketched above was designed or implemented (it still hasn't been).

## Telemetry & Evaluation

No PBG grade yet — `status: open`, a real finding filed for later
work, same category as `GCB-041`/`GCB-043`'s "filed, not yet actioned"
pattern. Will be graded once actually addressed, not before.

**Final State:** `open | pending`, priority explicitly **low/deferred**
per the Architect's own instruction — not to be picked up by the
standing `/loop` ahead of medium-effort-appropriate work; revisit when
higher-effort token budget is available.
