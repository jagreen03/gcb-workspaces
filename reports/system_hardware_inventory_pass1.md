# GCB/ODIN_Bridge System Hardware Inventory — Pass 1

**Date:** 2026-09-12. **Status:** first pass, not exhaustive — see depth
note below. Produced per the Architect's supplied reconstruction prompt
(`GCB System Hardware Inventory — Gemini + Orange-Team Prompt.md`),
executed as `TKT-035`.

**Source-evidence doctrine applied throughout** (the session's own
standing correction, `TKT-033`): `gcb-wiki` is a human-readable view *of*
`gcb-spec`, not a parallel source of truth. This reconstruction is built
from direct repo evidence (code, RTL, build artifacts, `gcb-spec`'s own
text) first; `gcb-wiki` content is cited only where it matches that
evidence, and flagged where it diverges. The source prompt itself is
AI-facing ("Gemini + Orange-Team," "may be passed to another LLM") and is
treated as a task specification, not as evidence.

**Depth note (updated same day - all items below now deepened)**: deep,
re-verified evidence for every repo: `gcb-rtl`, `gcb-host`,
`gcb-wdm-transceiver`, `gcb-photonic-qam-v2` (RTL level), `gcb-analog-rx`,
`gcb-pic-core`, `gcb-spec`, `gcb-python-orchestrator` (confirmed via
`packer.py`'s explicit `gcb_dwdm_pkg` bit-convention match), `gcb-dashboard`
(`make doctor` run for real, passes clean; React dashboard's build gap
found directly), `vortex` (System Boundary conclusively confirmed via
`git remote`/`git log`/exhaustive grep, not inferred from file absence).
See `TKT-035`'s own ticket file for the full deepening narrative and the
"two named programs" structural correction (supersedes the original
"Track A/Track B" framing below).

---

## 0. Headline finding: two largely separate architectural tracks

**`gcb-spec/architecture.md`** — "source of truth" per its own repo
README — states explicitly:

> *"GCB/ODIN_Bridge is a hybrid photonic–electronic inference fabric: a
> RISC-V Vortex 3.0 tensor core streams partial products into a cascaded
> **optical** carry-save reduction fabric, the analog optical result is
> digitised once by a single-slope CIS readout, and an FPGA pilot exposes
> the whole thing over MMIO."*

and names exactly **five** repositories it considers canonical:
`gcb-spec`, `gcb-rtl`, `gcb-host`, `gcb-dashboard`, `gcb-papers`. Its own
data path: `Vortex 3.0 TCU → Q17.14 carry-save stream → optical cascade
(8-input reduction cells, single wavelength, power-summing) → single-
slope readout → MMIO → host`.

**This list does not include** `gcb-wdm-transceiver`,
`gcb-photonic-qam-v2`, `gcb-pic-core`, `gcb-analog-rx`, or
`gcb-python-orchestrator` — five repos with real, substantial work
(RTL, cocotb/Icarus regressions, Python models, `gdsfactory` layouts)
that describe a **different** optical architecture: wavelength-division-
multiplexed, 16-to-64-channel, complex-QAM or balanced-homodyne.

**Call it Track A (canonical, `gcb-spec`-grounded) and Track B (the
broader multi-repo "photonic inference fabric" vision, `gcb-wiki`-
narrated, no dedicated `gcb-spec` of its own):**

| | Track A | Track B |
|---|---|---|
| Repos | `gcb-spec`, `gcb-rtl`, `gcb-host`, `gcb-dashboard`, `gcb-papers` | `gcb-wdm-transceiver`, `gcb-photonic-qam-v2`, `gcb-pic-core`, `gcb-analog-rx`, `gcb-python-orchestrator` |
| Optical mechanism | Single O-band wavelength, power-summing MMI | Wavelength-division multiplexing (colors/lambdas), up to ~60-64 channels |
| Spec authority | `gcb-spec` (explicit, direct) | `gcb-wiki` narrative only — no `gcb-spec` repo of its own (`TKT-033` finding) |
| Physical-implementation evidence | **Real Vivado P&R** (`greencoyote_top`, Alveo U55C, timing closed) | Digital simulation / Python models / `gdsfactory` layout feasibility only — no FPGA/ASIC evidence found |
| Host software | Real, substantial C++ driver (`gcb-host`, Alveo/XRT) | None found |

**This is not presented as a contradiction needing a silent pick** — per
the source prompt's own explicit rule. It is recorded in the
Contradiction Register (§7) as genuinely open: are these two phases of
the same program (A = current/near-term, B = a longer-horizon vision),
two independent explorations, or does one supersede the other? No
document checked this pass states which.

---

## 1-2. Master Hardware Inventory + Completion/Status Matrix

Evidence categories per the source prompt: **EXPLICIT** (named in repo
evidence) / **ARCH-REQ** (architecturally required, not confirmed
implemented) / **IMPL** (RTL/code/layout exists) / **TESTED** (exercised
by a real test) / **PHYS-VAL** (physical hardware/measured data) /
**INFERRED** / **UNKNOWN**.

### Track A (canonical, `gcb-spec`-grounded)

| Part | Category | Status label | Evidence |
|---|---|---|---|
| `greencoyote_top` (FPGA pilot top) | EXPLICIT, IMPL, TESTED, **PHYS-VAL-adjacent** | SYNTHESIZED + PLACED/ROUTED (FPGA, not ASIC) | Real Vivado 2024.2 `post_route.dcp`, part `xcu55c-fsvh2892-2L-e` (Alveo U55C), OOC mode, timing closed (WNS +0.261 ns, 0/1290 failing), utilization 602 LUT/0.05%, 8 DSP48E2/0.09%, power estimate 3.293 W (flagged "vectorless, confidence Medium" in its own source — not overclaimed here either) |
| `greencoyote_pilot_regs.sv` / register map v0.6.0 | EXPLICIT, IMPL, TESTED | RTL IMPLEMENTED, DIGITALLY SIMULATED | `gcb-rtl/sim/run_pilot_tb.sh` → `tb_cs_fifo_path`, ALL CHECKS PASS (re-run this session); register offsets confirmed byte-identical against `gcb-host`'s generated header |
| `VX_tcu_tilefinal_tag.sv` / `VX_tcu_shim_q1714.sv` (Vortex-side shim) | EXPLICIT, IMPL | RTL IMPLEMENTED — TESTED status not re-verified this pass | `gcb-rtl/integration/*.sv`, governed by `carry_save_streaming_contract.md` |
| Optical 8-input reduction cell (cascade) | EXPLICIT (model), ARCH-REQ (physical) | CONCEPT/MODEL (numerical), no physical layout found for THIS specific cell | `gcb-rtl/sim/mmi_tree_model.py` (Task 1 numerical model only — Monte-Carlo SNR/noise, not a layout); `gcb-spec/task3_physical_bom.md` (Phase I bench BOM, parts `[CANDIDATE]`/`[TBD]`, not procured) |
| Single-slope CIS readout (TDC, comparator) | EXPLICIT, IMPL (digital side) | RTL IMPLEMENTED, DIGITALLY SIMULATED (digital); analog/SPICE side UNKNOWN this pass | `SS_TDC_CTRL`/`SS_CAL_*` registers match on both `gcb-host` and `gcb-rtl` sides; `gcb-rtl/sim/run_ss_tb.sh` → `tb_ss_calib` 10000/10000 PASS + `tb_ss_tdc` ALL PASS (re-run this session) |
| C++ pilot driver (`greencoyote_pilot.hpp`) | EXPLICIT, IMPL | IMPLEMENTED (header-only, real), no project build system (`src/`/`tests/` empty) | `gcb-host/include/greencoyote_pilot.hpp` (~800 lines), confirmed via direct read + a real smoke test added this session (`tests/test_hf_manifest_gen.py`, a different tool in the same repo) |
| Alveo U55C FPGA card (physical) | EXPLICIT (named, both RTL constraints and driver) | **UNKNOWN whether physically present** — no evidence of an actual card/bitstream deployment found, only design-time artifacts (constraints targeting that part, a driver that would open it via XRT) | `constraints/greencoyote_ooc.xdc`, `xrt::device` calls in the driver, the post-route part name |
| FastAPI MMIO proxy | EXPLICIT (named in README) | **README claim REFUTED** — `gcb_proxy.py` contains zero FastAPI code; it is a self-checking pure-Python MMIO register simulator | Direct grep + execution this session (`TKT-032`), exit 0, "OK — v0.6.0 MMIO map exercised" |
| Vortex 3.0 TCU (RISC-V GPGPU tensor core) | EXPLICIT, IMPL | Vendored upstream RTL (real, substantial: `VX_tcu_*.sv` files exist), GCB-side modification status not confirmed this pass | `vortex/hw/rtl/tcu/**` (bhf/dpi/dsp/fpnew subdirectories, real files); `gcb-spec/vortex_integration_notes.md` describes GCB's integration contract against it |

### Track B ("photonic inference fabric" vision, `gcb-wiki`-narrated)

| Part | Category | Status label | Evidence |
|---|---|---|---|
| `gcb_wavelength_router.sv` (DWDM lane router) | EXPLICIT, IMPL, TESTED | RTL IMPLEMENTED, DIGITALLY SIMULATED | Exists in TWO diverged forms: `gcb-wdm-transceiver` (124 lines, `N_LAMBDA` parameterized, TKT-019.1) vs. `gcb-photonic-qam-v2` (99 lines, fixed 2-color original) — real fork-divergence, see Contradiction Register |
| `gcb_dwdm_payload_mux`/`demux`, `gcb_dwdm_deskew_cdc` | EXPLICIT, IMPL, TESTED | RTL IMPLEMENTED, DIGITALLY SIMULATED | `gcb-wdm-transceiver/sim/` cocotb suites, confirmed passing in earlier session work (per `gcb-wiki/15`'s own citations, independently plausible given this repo's general regression health, NOT re-run this specific pass) |
| `balanced_homodyne_cell()` (2x2 MMI + 2 photodiodes) | EXPLICIT, IMPL | LAYOUT COMPLETE (feasibility-level `gdsfactory` GDS, not foundry-taped) | `gcb-pic-core/layout_homodyne.py`, builds to valid GDS (117.75x53.75 um), re-verified this session |
| `wdm_combiner_tree.py`/`k16_tile.py` (WDM K=16 combiner) | EXPLICIT, IMPL | LAYOUT COMPLETE (feasibility-level), **ARCH-REQ status now REVOKED** — `TKT-033` found zero `gcb-spec` grounding for this specific construction | `gcb-pic-core@391d6bd`/`a3e1525`, both checks clean, reproduced twice; kept in repo, flagged not-currently-targeted |
| `mmi_power_tree.py` (spec-grounded 8-input power combiner) | EXPLICIT, IMPL | LAYOUT COMPLETE (feasibility-level) | `gcb-pic-core@5063bb2`, matches Track A's `mmi_tree_model.py` mechanism exactly — **this is arguably the one Track-B-repo component that actually matches Track A's real spec** |
| Switched-charge integrator (Rx quantizer) | EXPLICIT, IMPL | MODEL ONLY (Python, no SPICE/RTL/layout) | `gcb-analog-rx/switched_charge_model.py`, extended + Architect-dispositioned this session (`TKT-031`) — kT/C noise, ADC quantization; no silicon or SPICE evidence |
| Switched-charge integrator (silicon) | ARCH-REQ | CONCEPT only | No RTL, no SPICE testbench, no layout found this pass |
| PyTorch compiler/scheduler (`HybridPartitioner`, `PhotonicTiler`) | EXPLICIT, IMPL | IMPLEMENTED (Python), TESTED status UNKNOWN this pass | `gcb-python-orchestrator/compiler/*.py` — shallow pass only, not re-read in depth |
| React fabric-monitoring dashboard | EXPLICIT, IMPL | IMPLEMENTED, TESTED status UNKNOWN this pass | `gcb-dashboard/src/GreenCoyoteDashboard.jsx` — shallow pass only |
| DWDM laser/modulator bank → 8×8 unitary mesh ("Phase II integrated cell") | ARCH-REQ only | **CONCEPT ONLY**, explicitly | `gcb-wiki/16` Part 9 — "no repository contains a model, a component list, or a part number for this block" (the document's own words, confirmed accurate this pass) |

### Shared/ambiguous

| Part | Category | Status label | Evidence |
|---|---|---|---|
| CXL fabric / memory capacity | ARCH-REQ, INFERRED | Referenced only as a software-tooling parameter | `gcb-host/tools/hf_manifest_gen.py`'s `cxl_capacity_gb` field — no RTL/PHY block found for an actual CXL controller anywhere this pass |
| DMA engine | EXPLICIT, IMPL, TESTED | RTL IMPLEMENTED, DIGITALLY SIMULATED | `gcb-rtl/sim/run_dma_tb.sh` → `tb_dma_integration`, ALL CHECKS PASS (`saw_armed=1 fire_seen=1018 opv_seen=1018 underrun=0 errors=0`, re-run this session) |

---

## 3. Systems Data Specification (selected, evidence-labeled values)

| Value | Figure | Label | Source |
|---|---|---|---|
| FPGA part (Track A) | `xcu55c-fsvh2892-2L-e` | **MEASURED** (design-time, real constraint target) | `gcb-rtl/results/post_route_baseline/README.md` |
| OOC clock | 300 MHz / 3.333 ns | **MEASURED** (constraint, timing closed) | same |
| Setup WNS | +0.261 ns | **MEASURED** (post-route STA) | same |
| Power | 3.293 W | **SIMULATED** (vectorless estimate, "confidence Medium" per its own source) | same |
| Track A wavelength | single O-band, ~1310 nm | **TARGET** (Phase I BOM) | `gcb-spec/task3_physical_bom.md` |
| Track A combiner loss | ~0.1 dB/stage (optimistic) | **ASSUMED** (cited from literature, Smolanski & Malka 2025, not measured in-repo) | `gcb-rtl/sim/mmi_tree_model.py` header |
| Track B wavelength count | ~60λ | **ASSUMED** (`ESTIMATE/ASSUMPTION`, link-budget derived) | `gcb-wiki/15` — now attributed to `gcb-wdm-transceiver`'s real `N_LAMBDA` parameterization, not `gcb-pic-core` |
| Track B channel spacing | 50 GHz grid | **ASSUMED**, flagged this session as lacking direct `gcb-spec` corroboration | `gcb-wiki/15`, flagged `gcb-wiki@3f8a319` |
| `gcb-pic-core` K=16 | 16 (real, re-grounded - see `TKT-034`) | **ASSUMED/MEASURED** (SNR-budget derived, `intent.md`) | NOT `gcb-spec` - `gcb-photonic-qam-v2/intent.md`'s `K<=16` + `gcb-wdm-transceiver/rtl/gcb_dwdm_pkg.sv`'s `K_MAX=16` ("hard cross-architecture invariant") |
| React dashboard build | no build/dev script, no `react` dependency declared | **UNKNOWN/MISSING** | `gcb-dashboard/package.json` - checked directly this pass |
| `gcb-dashboard` render toolchain | fully functional | **TESTED** (`make doctor` run for real, passes clean) | `sv2v v0.0.12`, `Yosys 0.68`, `node v22.22.1`, 17 fresh SVGs |
| Track A register map version | 0.6.0 | **MEASURED** (byte-exact match, two independent generated files) | `gcb-host/include/generated/greencoyote_regmap.hpp` vs. `gcb-rtl/rtl/generated/greencoyote_regmap_pkg.sv` |

---

## 7. Contradiction Register

```
CONFLICT 1
Source A: gcb-spec/architecture.md ("Five repositories": gcb-spec,
          gcb-rtl, gcb-host, gcb-dashboard, gcb-papers)
Source B: gcb-wdm-transceiver, gcb-photonic-qam-v2, gcb-pic-core,
          gcb-analog-rx, gcb-python-orchestrator READMEs (all describe
          themselves as part of "the GreenCoyote-Bay photonic inference
          fabric (ODIN_Bridge)")
Difference: gcb-spec's own canonical architecture list does not include
  five repos that all self-identify as part of the same program, and
  describes a materially different optical mechanism (single-wavelength
  power-summing vs. wavelength-division multiplexing).
Likely explanation: two architectural tracks/generations - Track A
  (gcb-spec-grounded, has real FPGA P&R evidence) appears more physically
  mature; Track B (gcb-wiki-narrated, no dedicated spec repo) appears to
  be a broader, longer-horizon, or earlier-exploratory vision. Genuinely
  unclear which from evidence alone.
Current safest interpretation: treat both as real, both as active, and
  do not assume either supersedes the other without direct confirmation.
What evidence would resolve it: an explicit Architect statement, or a
  gcb-spec document that names Track B's repos and relates them to
  Track A (none found this pass).

CONFLICT 2
Source A: gcb-wdm-transceiver/rtl/gcb_wavelength_router.sv (124 lines,
          N_LAMBDA parameterized, TKT-019.1, up to ~60 lambda)
Source B: gcb-photonic-qam-v2/rtl/gcb_wavelength_router.sv (99 lines,
          fixed 2-color original)
Difference: the same-named file has diverged into two different
  implementations across two repos - confirmed by direct diff this pass,
  not assumed from filenames alone.
Likely explanation: gcb-wdm-transceiver forked this file and extended it
  (its own README states this explicitly: "gcb_wavelength_router.sv...
  were forked" from the QAM-v2 lineage) without the extension being
  merged back.
Current safest interpretation: gcb-wdm-transceiver's copy is the more
  current/capable one for anything involving N_LAMBDA > 2; any work
  against gcb-photonic-qam-v2's copy should not assume N_LAMBDA support.
What evidence would resolve it: a maintainer decision on which copy is
  canonical, or a reconciling merge.

CONFLICT 3 (already resolved this session, recorded for completeness)
Source A: gcb-wiki/15, gcb-wiki/16 Part 9 (DWDM/60lambda/50GHz-grid
          framing applied, by gcb-pic-core's own README citation, to the
          K=16 homodyne tile)
Source B: gcb-spec (task3_physical_bom.md, bench_emulation_parameters.md,
          gcb-rtl/sim/mmi_tree_model.py) - single wavelength,
          power-summing, n_inputs=8
Difference: gcb-pic-core's README cited gcb-wiki instead of gcb-spec for
  its "K=16" framing; no gcb-spec grounding exists for it.
Likely explanation (now confirmed, not merely hypothesized): gcb-wiki's
  60lambda/50GHz figures most plausibly describe gcb-wdm-transceiver's
  real N_LAMBDA-parameterized router (Track B's own genuinely-implemented
  DWDM component) - conflated with gcb-pic-core's unrelated tile by
  gcb-wiki's own cross-references, not a fabricated figure in itself.
Current safest interpretation: RESOLVED per TKT-033 - gcb-pic-core's K=16
  tile has no WDM requirement; a real, separate WDM component
  (gcb-wdm-transceiver) legitimately carries the 60lambda/spacing figures.
What evidence would resolve it further: direct Architect confirmation
  that this re-attribution is correct.

CONFLICT 4
Source A: gcb-pic-core/README.md "Role" - A+B/A-B balanced-homodyne
          differential multiply, citing gcb-wiki "Invariant #6"
Source B: gcb-rtl/sim/mmi_tree_model.py - an 8-input POWER-SUMMING
          (addition) reduction cell, no differential/multiply operation
          described
Difference: Track A's real, gcb-spec-grounded optical cell performs
  summation; Track B's gcb-pic-core component performs (or claims to
  perform) multiplication via coherent interference - these are different
  operations, not the same mechanism under different names.
Likely explanation: UNKNOWN - could be two genuinely different stages
  (a separate multiply-then-sum architecture), or gcb-pic-core's multiply
  framing could itself be gcb-wiki-only and ungrounded the same way K=16
  was (TKT-034, not yet investigated).
Current safest interpretation: do not assume gcb-pic-core's multiply
  cell is the same component as, or feeds into, Track A's reduction cell,
  without further evidence.
What evidence would resolve it: TKT-034's own investigation.
```

---

## 8. System Boundary Check

**Inside the GCB/ODIN_Bridge system** (per `gcb-spec/architecture.md`'s
own "Five repositories," Track A): `gcb-spec`'s register map/ADRs,
`gcb-rtl`'s pilot RTL + Vortex-side integration shim, `gcb-host`'s C++
driver + tooling, `gcb-dashboard`'s monitoring UI, `gcb-papers`'s
evidence archive.

**Required external infrastructure** (per the source prompt's own
categories, not automatically counted as GCB hardware):
- **Vortex 3.0 itself** — a real, substantial, independently-maintained
  open-source RISC-V GPGPU project (confirmed: no GCB-specific files
  found anywhere inside the vendored `vortex/` tree itself this pass;
  GCB's own integration code lives in `gcb-rtl/integration/*.sv`,
  described by `gcb-spec/architecture.md` as code that "belongs in the
  Vortex tree" but currently staged outside it). Vortex's TCU RTL
  (`VX_tcu_*.sv`) is real and load-bearing for GCB's data path, but
  Vortex is not a GCB-authored component.
- The physical Alveo U55C card, host computer, power, cooling —
  referenced by design-time artifacts (constraints, driver code) but no
  evidence of an actual deployed unit found this pass.

**Ambiguous / unresolved boundary**: Track B's five repos
(`gcb-wdm-transceiver`, `gcb-photonic-qam-v2`, `gcb-pic-core`,
`gcb-analog-rx`, `gcb-python-orchestrator`) all self-identify as part of
"the GreenCoyote-Bay photonic inference fabric," but sit outside
`gcb-spec`'s own canonical list. Not classified as "external
infrastructure" (they are genuinely GCB-authored, with real RTL/code),
but also not confirmed as "inside" the canonical architecture. Left
unresolved per Conflict 1 above — this is exactly the kind of boundary
ambiguity the source prompt's §8 asks to surface, not silently resolve.

---

## 9. Functional Completeness Check (selected gaps)

- **PHYSICAL GAP**: Track A's optical 8-input reduction cell itself
  (the actual photonic hardware performing the power-summing) has no
  `gdsfactory`/layout evidence found this pass — only a numerical model
  (`mmi_tree_model.py`) and a parametric BOM with `[CANDIDATE]`/`[TBD]`
  parts, none procured. `gcb-pic-core/mmi_power_tree.py` (built this
  session, Track B repo) is architecturally the right mechanism but has
  not been confirmed as "the" Track A cell — see Conflict 1/4.
- **SPECIFICATION GAP**: Track B's DWDM laser/modulator bank (`gcb-wiki/16`
  Part 9) remains CONCEPT ONLY - no part, no model, channel
  spacing/wavelength count genuinely undetermined (separate from, and
  NOT resolved by, `TKT-033`'s finding that gcb-pic-core specifically
  doesn't need one).
- **TESTABILITY GAP**: no evidence found this pass of any physical
  optical loopback, monitor tap, JTAG, BIST, or scan chain anywhere in
  either track - `gcb-wiki/15`'s own "Silicon / chip testing: MISSING"
  finding re-confirmed, not contradicted, by this pass.
- **INTERFACE GAP**: how (or whether) Track A's single-wavelength
  reduction cascade and Track B's WDM/multi-channel components are meant
  to physically interconnect, if at all, is not specified anywhere found
  this pass - consistent with Conflict 1 remaining open.

---

## 10. Final System Map (Track A, the canonical/evidenced path)

```
Vortex 3.0 TCU (VX_tcu_core, real RTL, vendored)           [IMPLEMENTED, external IP]
      |
      v  M_AXIS_CS AXI4-Stream (Q17.14 carry-save)
Vortex-side shim (VX_tcu_tilefinal_tag.sv, VX_tcu_shim_q1714.sv)
      |                                                     [IMPLEMENTED, gcb-rtl/integration]
      v
Optical 8-input reduction cascade                          [MODEL ONLY - mmi_tree_model.py;
 (greencoyote_photonic_sequencer.sv,                         physical layout NOT CONFIRMED
  greencoyote_cs_lane_fifo.sv drive it)                      to exist for this exact cell]
      |
      v
Single-slope CIS readout (SS_TDC_CTRL, 6 GHz Gray TDC)      [IMPLEMENTED, DIGITALLY SIMULATED -
      |                                                      tb_ss_calib/tb_ss_tdc ALL PASS]
      v
greencoyote_top (FPGA pilot)                                [SYNTHESIZED + PLACED/ROUTED,
      |                                                      real Vivado post_route.dcp,
      |  MMIO over XRT                                       Alveo U55C - PHYSICAL DEPLOYMENT
      v                                                      STATUS UNKNOWN]
gcb-host C++ driver (greencoyote_pilot.hpp)                 [IMPLEMENTED, no project build
      |                                                      system - src/tests/ empty]
      v
Host / operator (gcb-dashboard, gcb_proxy.py simulator)     [IMPLEMENTED]
```

Track B's own map (WDM/homodyne path) is structurally plausible but has
no confirmed connection point into the above - left as an open question
per Conflict 1.

---

## 11. Deliverable checklist (this pass)

1. Master hardware inventory — §1-2 (done, Pass 1 depth)
2. Completion/status matrix — §1-2 tables (done)
3. Systems data specification — §3 (selected values only, not exhaustive)
4. Dependency graph — §10 (Track A only; Track B not mapped, boundary unresolved)
5. Stand-alone test matrix — not built this pass (re-verify `gcb-wiki/15`'s existing matrix against real evidence rather than rebuild from scratch — deferred, `TKT-035` Required Work)
6. Required equipment matrix — deferred, same reason
7. DFT/test-structure matrix — deferred, same reason
8. Contradiction register — §7 (4 entries, done)
9. Functional/interface/testability gap register — §9 (selected, done)
10. Current system-boundary statement — §8 (done)

**What the project currently is** (Track A, best-evidenced): a
Vortex-TCU-fed, single-wavelength, power-summing optical reduction
fabric with a real FPGA pilot (synthesized, placed, routed, timing
closed) and a real C++ host driver — deployment-unit status unknown.

**What the project would need to become a complete physical system**:
the optical cell itself physically built (currently model-only); Track
B's relationship to Track A resolved (Conflict 1); Track B's own laser/
modulator bank specified (currently concept-only); any physical test
infrastructure (Track A and B both - currently missing per `gcb-wiki/15`,
re-confirmed this pass).
