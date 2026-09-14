# Research Triage Log

Append-only, one entry per harvest pass — same pattern as
`spike_loop_summary.md`. Each entry: what was harvested, how it was
classified, what priority it got, and what was drafted from it (a new
research prompt, a new ticket, or neither). See
`gcb-wiki/appendices/research-operations.md` for the roles, the
priority scale, and the full workflow this log is the record of.

Nothing in this log is final. A drafted ticket sits `open` until the
PI (the Architect) reviews it, same as every other ticket in this
program's backlog.

---

## Pass 1 — 2026-09-13 — `gcb-lumen`

**Harvested:** `gcb-lumen/FINDINGS-2026-09-13.md` (an external AI's
SAX-based recommendation, checked and partly executed the same day)
and `gcb-lumen/ai-agents/ORANGE_TEAM.md`'s `MEASUREMENT STATE — V2`.

**Classification, three separate threads inside one finding:**

1. **The real per-junction insertion-loss number** — **needs more
   research.** The core blocking question is unchanged; only the
   framework for computing a system-level answer from it is now real.
   **Priority: P1** — blocks the fan-in decision (`optical.cell.fanin`
   in `DECISION_LEDGER.md`), which nothing is actively demanding
   *today*, but which the program's own docs already flag as the next
   real step once a loss number exists.
   **Drafted:** a refined next-research prompt, appended to
   `gcb-lumen/ai-agents/ORANGE_TEAM.md`, that assumes the SAX
   framework as given (no need to re-justify the toolchain choice) and
   asks specifically for a real, non-assumed loss number via a
   `femwell`-extension or a cited literature/vendor figure.
2. **The SAX-framework feasibility question** — **resolved.**
   Confirmed real and working by actually building and running it.
   No further action; already reflected in `gcb-lumen`'s own state.
3. **The unexplained file-name reference** (`k16_tile.py` /
   `mmi_power_tree.py` named by an external AI that was never given
   those names, against a private repo) — **ticket-worthy.** Not an
   engineering defect and not itself research — a process/trust
   observation about external-AI tool use that the PI should see and
   decide whether to act on (e.g., always paste the *full* briefing
   rather than a condensed one, to remove the ambiguity going
   forward). **Priority: P2** — nothing depends on resolving it today,
   but it's a real, recorded gap in this program's own AI-trust
   discipline.
   **Drafted:** `GCB-042` (see `gcb-workspaces/backlog/GCB-042-external-ai-unexplained-file-reference.md`).

**Roles exercised this pass:** the Architect (PI) brought the external
AI's response back — Research Scientist role, informally, by initiating
contact with an external AI. This session then acted as External
Reviewer (checked the response's claims against the real repo) and, in
writing this log entry, as Triage Coordinator. First real run of all
three non-PI roles in one pass, not yet split across separate sessions
or people — that's the next thing to actually try, not simulated here.

---

## Pass 2 — 2026-09-13 — `gcb-lambda`

**Harvested:** `gcb-lambda`'s own Deliverable 1 (reconciliation of
`gcb-wiki/16` Part 9's laser-bank "zero spec" claim), run directly this
pass rather than harvested from a prior session's output — the first
time this workflow has been used to *execute* a Research Scientist
task, not just triage one brought back from elsewhere.

**What happened:** the repo's own first-draft hypothesis ("two
different, compatible bench apparatuses") was re-checked against the
real source files per `ai-agents/ORANGE_TEAM.md`'s own hard rule to
read them "directly, in full" before trusting a prior pass's framing.
**The hypothesis was wrong.** Both `bench_emulation_parameters.md` and
`task3_physical_bom.md` label themselves "Task 3," and
`02_receiver_architecture.md`'s "Phase I — Guaranteed Bench" section
states one combined purpose for them (proving summation *and*
ratiometric-cancellation together) — they describe **the same bench**,
disagreeing on laser *count* (N independent diodes vs. one diode split
via a PM splitter), not two different experiments.

**Classification:**

1. **The reconciliation itself** — **resolved**, correctly (the real
   finding, not the original guess). `gcb-wiki/16` Part 9 corrected
   (detailed entry, summary table, "Known documentation gaps" item 2);
   `silicon-and-package-detail.md` and `intent.md` §0 corrected to
   match; `gcb-lambda`'s own `README.md`/`EXTERNAL_AI_BRIEFING.md`/
   `ai-agents/ORANGE_TEAM.md` updated to drop the superseded "two
   compatible experiments" framing everywhere it appeared.
2. **The laser-count conflict itself** — **ticket-worthy.** A real
   architecture choice with genuinely different engineering
   consequences (calibration complexity, failure mode, cost scaling)
   that this workflow does not get to pick a side on.
   **Priority: P1** — not blocking anything *today*, but it sits
   directly upstream of `gcb-lambda`'s own second deliverable
   (Phase-II scoping) and of any future procurement decision.
   **Drafted:** `GCB-043`.
3. **Phase-II laser/modulator scoping** (`gcb-lambda`'s own remaining
   deliverable) — **still needs more research**, unchanged by this
   pass. `EXTERNAL_AI_BRIEFING.md`'s question narrowed to this single
   remaining thread, now that the reconciliation is done. **Priority:
   P2** — foundational, nothing currently waiting on it.

**Roles exercised this pass:** this session acted as Research
Scientist (ran the actual reconciliation work), caught its own prior
pass's wrong hypothesis in the External Reviewer sense (checking a
finding — even one's own — against the real files before trusting it),
and as Triage Coordinator in writing this entry. A genuine
demonstration that "External Reviewer" isn't only useful against a
different AI's output — re-checking one's own earlier conclusion
caught a real error here.

---

## Pass 3 — 2026-09-13 — `gcb-kelvin`

**Harvested:** a real new angle found by this session while directly
working the repo, not brought back from elsewhere — checking whether
a real WSL-based `ngspice`+OSDI+BSIM-CMG toolchain (per
`gcb-spec/docs/spice_setup.md`) was reachable on this host, rather
than assuming no simulator access existed beyond what the repo's own
evidence docs already cited. It was reachable; used directly.

**What happened:** `.noise`'s known failure against the real BSIM-CMG
device was re-run and re-confirmed (exactly zero, 4 decades checked) —
not assumed stale. A separate `.op`/`.ac` probe then found something
not previously recorded anywhere: real small-signal parameters
(`gm`/`gds`/`cgg`) extract cleanly from the same real device model even
though internal noise-source synthesis (`.noise`) does not. This opens
a real, previously-speculative angle in the repo's own briefing (a
manual noise-injection model using the real device's own `gm`) from
"maybe possible" to "confirmed buildable, not yet built."

**Classification:**

1. **The core comparator-noise question** — **still needs more
   research**, unchanged. No comparator-circuit noise number was
   computed; a single transistor's `gm` is not a noise result.
   **Priority: P0 unchanged** — still the direct blocker on
   `CONDITIONAL GO → GO`.
2. **The manual noise-injection path itself** — **needs more
   research**, newly scoped rather than purely speculative. Requires
   real analog-IC noise-design judgment (node-by-node noise source
   placement/correlation, chopper/1-over-f modeling, latch
   regeneration noise) that this pass did not attempt — a circuit-
   design task, not a scripting one. **Priority: P1** — a real,
   untried alternative to waiting indefinitely on Spectre access, but
   not yet proven to actually narrow the uncertainty band.

Not ticket-worthy — no architecture decision or process question for
the Architect here, just a research path to hand to whoever (AI or
person) has real analog-IC noise-design expertise next.

**Drafted:** `gcb-kelvin/FINDINGS-2026-09-13.md`; `ai-agents/ORANGE_TEAM.md`
updated to V2 with this state; `EXTERNAL_AI_BRIEFING.md` updated so a
future external consultation builds on this rather than re-deriving
whether `.op`/`.ac` works on OSDI models (it does — confirmed).

**Roles exercised this pass:** Research Scientist (ran the real
toolchain checks directly) and Triage Coordinator (this entry). A
reminder folded into the repo's own hard rules: "no access to tool X"
should be checked directly each time a new session picks up a repo,
not carried forward as an assumption from the repo's own prior text.

---

## Pass 4 — 2026-09-13 — `gcb-lumen` (second pass, same day)

**Harvested:** a real new toolchain capability found by this session
while continuing to work the repo directly — checking whether real
FDTD access existed on this host (via `micromamba`/conda-forge, the
same mechanism already confirmed useful for `gcb-kelvin`'s WSL
toolchain finding earlier this session) rather than carrying forward
this repo's own prior "FDTD is effectively unavailable" framing.

**What happened:** real `pymeep` (1.34.0, the genuine conda-forge FDTD
package, not the PyPI name-collision impostor) installed and ran
cleanly. A real 2D effective-index-method FDTD model of the exact
`mmi1x2()` combiner geometry was built and run at three resolutions as
a basic convergence check. The 50:50 split ratio converged cleanly;
**the insertion-loss number did not** (4.36 → 9.06 → 2.86 dB across
resolutions 20/30/40 — non-monotonic, a real simulation bug, most
likely the flux-normalization reference, not yet fixed).

**Classification:**

1. **Real FDTD access** — **resolved** (as a toolchain-availability
   question). `EXTERNAL_AI_BRIEFING.md`'s prior framing corrected.
2. **The actual combiner insertion-loss number** — **still needs more
   research**, unchanged in substance but now much better-scoped: a
   real simulation exists with one specific, named, suspected bug
   (missing normalization reference run), rather than "no tool path
   known." **Priority: P1 unchanged** — still blocks
   `optical.cell.fanin`, nothing currently demanding it today.

Not ticket-worthy — a debugging task for the next Research Scientist
pass (human or AI), not an Architect decision.

**Drafted:** `gcb-lumen/FINDINGS-2026-09-13-fdtd.md`; `fdtd/mmi_fdtd.py`
(the real, reusable simulation script); `ai-agents/ORANGE_TEAM.md`
(V3) and `EXTERNAL_AI_BRIEFING.md` updated so the next session fixes
the known bug instead of re-deriving tool availability or re-running
an un-normalized first pass.

**Discipline note:** all three resolution results were reported, not
the most favorable one. A genuinely non-monotonic convergence sweep is
itself a real, useful Orange-Team result (a bad/unstable number is a
successful measurement of "this pipeline isn't trustworthy yet," not
a failure to hide) — the same principle this program already applies
to "deliberately ugly first passes" elsewhere.

---

## Pass 5 — 2026-09-13 — `gcb-lumen` (third pass, same day)

**Harvested:** this session's own prior recommendation
(`FINDINGS-2026-09-13-fdtd.md`'s "add a normalization reference run"
next step), executed directly rather than left for a future session.

**What happened:** built and ran the recommended fix
(`fdtd/mmi_fdtd_v2.py`). **It failed** - the non-convergence pattern
barely changed (4.36 → 10.94 → 2.87 dB; resolution 30 got *worse*, not
better). This is a real, useful negative result: it rules out
reflection contamination as the dominant cause, and a new observation
(the clean reference run's own `P_in` varies 2.3× across resolution)
points the diagnosis upstream, toward the simulation's run-duration/
stopping-criterion handling or the source's own power normalization.

**Classification:** the core insertion-loss question - **still needs
more research**, now on a sharper, narrower hypothesis than before
(fixed-duration run vs. decay-based stopping, not reflection
normalization). **Priority: P1 unchanged.** Not ticket-worthy - a
continuation of an existing debugging thread, not a new decision.

**Drafted:** `gcb-lumen/FINDINGS-2026-09-13-fdtd-v2.md`; `ai-agents/ORANGE_TEAM.md`
(V4) and `EXTERNAL_AI_BRIEFING.md` updated so a future session doesn't
re-suggest either of the two fixes already tried and ruled out today.

**Discipline note:** two real fixes attempted in one day, both
reported as failures rather than silently abandoned or re-run until a
better-looking number appeared. Debugging explicitly stopped here
rather than stacking a third rushed guess - this needs careful,
one-variable-at-a-time work, which this log records as the honest
state to resume from, not a result to paper over.

---

## Pass 6 — 2026-09-13 — `gcb-lumen` (fourth pass, same day)

**Harvested:** the prior tick's own recommended next step (a fixed,
resolution-independent `until=` to replace the decay-based stopping
criterion) — but its premise was checked directly before building
anything, rather than assumed correct because it sounded plausible.

**What happened:** the actual "run finished at t=..." logs across
every resolution already tried (20/30/40) are essentially identical
(reference run ≈150.0, junction run ≈200.0 at all three) — **the V4
"sharper diagnosis" was wrong too**, caught before wasting a tool call
building a fix for a problem that didn't exist. Tried a fourth, higher
resolution (60 px/µm) instead of a third guess: 2.30 dB, meaningfully
closer to res=40's 2.87 dB (~20% apart) than any earlier pair (2–4×
apart) — a real convergence signal. **Real conclusion**: resolutions
20/30 were simply too coarse to resolve the taper geometry (diagonal
edges staircasing onto the FDTD grid at only ~10 pixels across the
narrow end) — a normal FDTD sensitivity, not a bug.

**Classification:** the core insertion-loss question — **still needs
more research**, now with the actual cause understood (a standard, if
computationally expensive, convergence study) rather than an
unexplained bug. **Priority: P1 unchanged.** A directional (not final)
read — true loss likely ~2–2.5 dB/junction — recorded explicitly as
extrapolation, not a result. Not ticket-worthy.

**Drafted:** `gcb-lumen/FINDINGS-2026-09-13-fdtd-v3.md`;
`ai-agents/ORANGE_TEAM.md` (V5), `README.md`, and
`EXTERNAL_AI_BRIEFING.md` all updated so a future session continues
the convergence study (try 80, then 100+ px/µm) instead of re-
diagnosing a "why doesn't it converge" question that's now answered.

**Discipline note, the sharpest of this whole day-long arc:** three
separate hypotheses were tried and ruled out in sequence (same-run
monitor contamination → a separate reference run → run-duration
variation) before the real cause surfaced — and the second and third
were each checked directly against real log output *before* code was
written to fix them, catching two dead ends cheaply rather than after
a wasted implementation. This is the harvest/triage workflow's own
External Reviewer discipline applied continuously within a single
research thread, not just at hand-off boundaries between sessions.

---

## Pass 7 — 2026-09-13 — `gcb-lumen` (fifth pass, same day)

**Harvested:** the prior tick's own started background task
(resolution 80 of the FDTD combiner-loss convergence study) —
completed successfully, result harvested and written up rather than
left in a log file.

**What happened:** IL = 2.07 dB at resolution 80, split still exactly
50:50. Full sequence is now clean and monotonic: 2.87 (res=40) → 2.30
(res=60) → 2.07 (res=80) dB, with shrinking gaps (−0.57, then
−0.23 dB) — the real signature of genuine FDTD convergence, replacing
the earlier bounce that came from under-resolved (20/30 px/µm) runs.
A rough, explicitly-labeled extrapolation suggests a possible limit
near ~1.9 dB. A resolution-100 confirmatory run was started as a
further background task before this pass ended.

**Engineering note**: resolution 80's junction run alone took 745s,
too long for one bounded foreground call alongside its reference run
— split into a `mmi_fdtd_single.py` wrapper (same `build()` function,
no reimplementation) so each configuration runs as its own tracked
background task. A real, useful execution-mechanics lesson for
continuing this study at even higher resolution.

**Classification:** the core insertion-loss question — **still needs
confirmation**, but is now close: one more converging data point
(resolution 100, in progress) away from a real, trustworthy number.
**Priority: P1, trending toward resolution.** Not ticket-worthy yet —
once a final number exists, updating `optical.cell.fanin`
(`DECISION_LEDGER.md`) with it would be the natural promotion, at
that point likely warranting the PI's attention as a real, actionable
number rather than a research thread.

**Drafted:** `gcb-lumen/FINDINGS-2026-09-13-fdtd-v4.md`;
`fdtd/mmi_fdtd_single.py`; `ai-agents/ORANGE_TEAM.md` (V6), `README.md`,
`EXTERNAL_AI_BRIEFING.md` all updated with the clean convergence
result and a pointer to the in-progress resolution-100 run.

**Discipline note:** stated explicitly, twice (in the findings file
and in the repo state), that even this clean convergence is not yet a
number to act on — the fan-in decision implication was described
cautiously ("if this holds") rather than presented as settled, keeping
the distinction between "converging nicely" and "converged" intact
even as the result got genuinely encouraging.

---

## Pass 8 — 2026-09-13 — `gcb-lumen` (sixth pass, same day — arc complete)

**Harvested:** the resolution-100 background task, completed via a
real-time notification. Final result: IL = 1.96 dB, split exactly
0.5000:0.5000, completing a clean, consistently-decaying four-point
sequence (2.87 → 2.30 → 2.07 → 1.96 dB, gap ratios 0.40 then 0.48).

**What happened:** a geometric extrapolation from all four points gives
a limit near 1.87 dB — close enough to the res=100 value (under 0.1 dB
apart) that further resolution increases were judged not worth their
steeply rising cost (res=100's junction run alone took 1451s ≈ 24 min).
**Stopped the resolution sweep here, as converged-enough for
engineering use, not mathematically exact.** Fed both the measured
(1.96 dB, `[M]`) and extrapolated (1.87 dB, `[D]`) values into the real
`sax_combiner_model.py` rollup: N=8 tree loss ≈ 5.88/5.61 dB, N=16 ≈
7.84/7.48 dB.

**Classification:** the core insertion-loss question — **resolved to
the research repo's own standard** (real, resolution-converged FDTD
evidence), though explicitly **not** the bench measurement
`DECISION_LEDGER.md`'s `optical.cell.combiner-loss` entry originally
asked for. **Promoted**: both relevant `DECISION_LEDGER.md` entries
updated with the real evidence (kept `Open`, not closed unilaterally —
that determination, and the actual `optical.cell.fanin` choice, are
for the PI). `gcb-wiki/appendices/orange-team-collaborator.md`'s
status row updated to match. **Priority downgraded from P1 (active
research) to awaiting-PI-review** — this thread's research work is
done; what remains is a decision, not more measurement.

**Drafted:** `gcb-lumen/FINDINGS-2026-09-13-fdtd-v5.md` (the
completing finding, with the full six-pass arc summarized for future
readers); `sax_combiner_model.py` updated with real values;
`ai-agents/ORANGE_TEAM.md` (V7), `README.md`, `EXTERNAL_AI_BRIEFING.md`
all updated to state the core question as substantially answered.

**Discipline note, for the whole arc across Passes 4–8**: three
genuinely different hypotheses (same-run monitor contamination, a
separate normalization run, run-duration variation) were tried and
rigorously ruled out — each checked directly against real log output
*before* being acted on or discarded — before the actual cause
(taper under-resolution) was found. The final number is explicitly
caveated as a 2D approximation, not bench-equivalent, everywhere it
appears, and the two real figures (measured vs. extrapolated) are kept
as separate, distinctly-tagged constants rather than merged into one
number. This is the harvest/triage/promotion workflow working exactly
as designed, end to end, on its own first deep research thread.

---

## Pass 9 — 2026-09-13 — `gcb-lambda`

**Harvested:** `gcb-lambda/ai-agents/ORANGE_TEAM.md`'s RECONCILIATION
STATE V2 — Deliverable 1 (Phase-I laser-count reconciliation) already
done and filed as `GCB-043`; Deliverable 2 (Phase-II laser/modulator
scoping) not yet started. Picked as the next tick's work after
`gcb-lumen`'s research thread concluded (Pass 8), to diversify across
the three problem repos rather than over-indexing on one.

**What happened:** re-read `gcb-spec/docs/optical_geometry_spec.md` in
full (the real locked Phase-II digital envelope) plus
`gcb-spec/task3_physical_bom.md` (Phase-I's real modulator choice and
its stated rationale) and `TKT-033` (the no-WDM finding) directly,
rather than reasoning from memory. Produced `gcb-lambda/PHASE2_SCOPING.md`
— four real findings, each tagged and none decided unilaterally: (1)
Phase-I's VOA modulator choice cannot carry forward, since its own
stated rationale is contradicted by Phase-II's locked 2.0 GHz `T_fire`;
(2) modulator/driver count jumps ~130× (1040 operand channels/fire);
(3) reusing `gcb-lumen`'s real FDTD per-junction loss figure against a
1024-way distribution tree gives a ≈19.6 dB splitting-loss floor — a
genuine cross-repo reuse of Pass 4–8's own result, computed, not
assumed; (4) the 1310 nm wavelength carries forward only as an
assumption.

**Classification:** Deliverable 2 (P2 — exploratory scoping, per this
repo's own mandate) — **done to the scoping standard the mandate
itself asks for** ("a scoped question list and candidate directions,
not a finished laser-bank design"). Not promoted to a `DECISION_LEDGER`
entry — none of the four findings are decisions, they're open questions
for the Architect / `gcb-pic-core`'s future work, same posture as
`GCB-043`. `gcb-lambda`'s own mandate (both deliverables) is now
substantially complete.

**Drafted:** `gcb-lambda/PHASE2_SCOPING.md` (new); `ai-agents/
ORANGE_TEAM.md` (RECONCILIATION STATE V3) and `README.md` updated to
reflect completion. Committed `gcb-lambda@bc41f52`, pushed, `HEAD ==
origin/main` verified.

**Note on cross-repo reuse**: finding (3) above is a real example of
one problem repo's harvested result (`gcb-lumen`'s FDTD loss figure)
being reused as an input to a *different* repo's open question, without
re-deriving or re-measuring it — exactly the kind of compounding value
the three-repo isolation was designed to allow once a real number
exists in one of them.

---

## Pass 10 — 2026-09-13 — `gcb-kelvin`

**Harvested:** `gcb-kelvin/ai-agents/ORANGE_TEAM.md`'s MEASUREMENT
STATE V2 and `FINDINGS-2026-09-13.md`'s recommended-but-unstarted next
step: build a manual multi-transistor noise-injection model using the
real device-extracted `gm`/`gds`, since Spectre access is confirmed
unavailable and ngspice's `.noise` is confirmed broken on the real
BSIM-CMG device.

**What happened:** rather than attempting the full 2-stage+chopper+
latch model in one step (explicitly flagged in the prior findings as
"a real, substantial circuit-design task"), took the smallest real
first increment: an analytical (no new EDA run — respects the host's
tight memory ceiling) single-transistor thermal-noise estimate using
the real extracted gm, checked two competing closed-form bandwidth
models (pole-limited vs. gate-window-limited) against the 53 µV BSIM4-
surrogate target. The pole-limited model landed within +11% at a
physically ordinary γ (2/3); the gate-limited model needed an
implausible γ≈5.3 — a real, checked signal about which physical
mechanism is likely dominant for this device/load, obtained by direct
computation (verified via a standalone script), not asserted.

**Classification:** genuine research progress on an already-open,
previously-unattempted path (P2 — exploratory, same tier as the
Phase-II laser scoping in Pass 9) — **not a closure**. Explicitly does
not touch `readout.comparator.noise.spectre-histogram`'s `Open` status
in `DECISION_LEDGER.md`; no GO implied or claimed, consistent with this
repo's own Hard Rule 3.

**Drafted:** `gcb-kelvin/FINDINGS-2026-09-13-manual-noise-v1.md` (new);
`ai-agents/ORANGE_TEAM.md` (MEASUREMENT STATE V3) updated with a
refined, smaller next-increment recommendation (a real `.ac` sweep for
just the first preamp stage, to settle the pole-vs-gate ambiguity this
pass surfaced but did not resolve). Committed `gcb-kelvin@55eb3b1`,
pushed, `HEAD == origin/main` verified.

---

## Pass 11 — 2026-09-14 — `gcb-kelvin` / `gcb-wiki`

**Harvested:** the Architect's own direct correction of Pass 10's
output — the rewritten `gcb-kelvin` orange-team-collaborator prompt
asked an external frontier AI to diagnose a ≈2× `g_m` discrepancy that
this session had itself partly found while drafting the prompt,
proving the outsourcing threshold was too low. Filed as `GCB-045`
(low priority, explicitly deferred per the Architect's instruction).

**What happened, continuing at medium effort per instruction:** rather
than stopping at the ticket, re-ran the real `.op` extraction deck
(`~/gcb_spice/tb/_gm.cir` and six fresh independent single-point decks)
at all six of `comparator_noise.py`'s own `MEAS` bias points. Found a
real, reproducible toolchain quirk: roughly half of all attempts
deterministically converge to a non-physical operating point (`v(op)`
in the millions of volts) — confirmed not solver-state noise by
re-running the same failing point three times, byte-identical garbage
each time. Every physically-plausible result landed in
`comparator_noise.py`'s own real 167–395 µS range, not near the
previously-reported 779 µS. **The `g_m` "discrepancy" most likely never
existed as a real device/bias finding** — it was an unchecked
non-converged solve, exactly the kind of thing a `0 < v(op) < V_dd`
sanity check (now added as a standing rule) would have caught.

**Classification:** a second, live, same-day confirming instance of
`GCB-045`'s own finding — internal medium-effort checking (re-run a
deck, add one plausibility check) resolved what the wiki had just
asked a frontier AI to diagnose. Not promoted to `DECISION_LEDGER.md`
— doesn't touch `readout.comparator.noise.spectre-histogram`'s `Open`
status; the real remaining gap narrowed to `γ=1.0` (assumed) vs.
BSIM4's `γ_eff≈1.4`, not a data discrepancy.

**Drafted:** `gcb-kelvin/FINDINGS-2026-09-13-manual-noise-v1.md`
Correction 2 (new); `ai-agents/ORANGE_TEAM.md` updated to match;
`gcb-wiki/appendices/orange-team-collaborator.md`'s `gcb-kelvin`
section and prompt rewritten around the real, narrower remaining gap
rather than left pointing at a resolved non-issue; `GCB-045` updated
with this as a second confirming instance, not a scope change.
Committed `gcb-kelvin@a27f1f0`, `gcb-wiki@845c0b5`, both pushed,
`HEAD == origin/main` verified.
