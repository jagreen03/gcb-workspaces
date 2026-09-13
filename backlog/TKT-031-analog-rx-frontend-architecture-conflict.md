---
id: TKT-031
title: "gcb-analog-rx Component 5: TIA (TKT-026) vs switched-charge integrator (switched_charge_model.py) - RESOLVED, switched-charge integrator adopted as Phase I baseline"
date_created: 2026-09-12
status: done
telemetry_color: blue
telemetry:
  spec: 0.9
  quality: 0.9
  emergence: 0.3
tags:
  - backlog
  - silicon
  - analog
  - architecture-conflict
  - needs-architect-disposition
---

# Objective

`gcb-analog-rx` ("Component 5 — Rx Quantizer / Switched-Charge
Integrator") had **never had a ticket of any kind** in this backlog
before now - discovered, like `gcb-pic-core` (see `TKT-030`), only by a
fresh repo survey during this session's autonomous spike loop. Verifying
its existing `switched_charge_model.py` against this program's own
already-established photocurrent figures (`TKT-026`) surfaced a real,
previously-invisible architectural inconsistency. **This ticket reports
that finding and holds it for Architect disposition - it does not pick a
winner.**

## Verified this session (not assumed)

1. `switched_charge_model.py` runs correctly (via the same
   `~/.venvs/gdsfactory` venv `TKT-030` set up - it only needs `numpy`,
   already a transitive dependency there) and its own physics checks out:
   exact SI-2019 Boltzmann constant, correct kT/C noise formula, a
   straightforward flash-ADC quantization model. Its own demo sweep
   (1-50 uA) and its own stated conclusion ("the 8-bit ADC, not kT/C, is
   the tighter limit") are both self-consistent and reproduce exactly when
   re-run.
2. **Cross-checking this model against `TKT-026`'s own already-computed
   nominal operating photocurrent (112.5 uA, from `task3_physical_bom.md`
   §1's `-9 dBm -> 125 uW -> 112.5 uA` derivation) was never done before -
   doing it now surfaces a real inconsistency, not a confirmation:**
   - At `I_in = 112.5 uA`, `switched_charge_model.py`'s own
     `integrated_voltage()` (with its current default `C_INT=20 fF`,
     `T_INT=200 ps`) computes `V_signal = 1125 mV` - **nearly 2x past the
     model's own `V_FS = 0.60 V` ADC full-scale**. `adc_code()` returns
     `255/255` - full-scale saturation, not a usable reading.
   - **The deeper issue is not a tunable-constant mismatch - it is two
     mutually exclusive front-end architectures, asserted independently
     in two different tickets, neither aware of the other:** `TKT-026`
     derived `R_f ~= 13.33 kOhm` for a **transimpedance amplifier** (a
     continuous-time, resistive-feedback current-to-voltage converter:
     `V = I * R_f`, `112.5 uA * 13.33 kOhm ~= 1.5 V`). `gcb-analog-rx`'s
     own README and `switched_charge_model.py` assume a **switched-
     capacitor integrator** (a sampled, clocked charge-accumulation
     front-end: `V = I * T_int / C_int`, with a fundamentally different
     noise mechanism - kT/C sampled thermal noise rather than a TIA's own
     resistor/op-amp noise - and a fundamentally different dynamic
     range/bandwidth trade). These are not two parameterizations of the
     same circuit; they are two different circuit topologies for the same
     physical node (the balanced-photodiode differential current), and
     nothing in either ticket's own record indicates which one the real
     system actually commits to.

## Required work - an Architect decision, not an RTL/model fix

**This ticket does not resolve the conflict itself** - picking a winner
by editing one document to match the other would be exactly the kind of
silent, unverified architectural commitment this program's own standing
discipline exists to prevent. What is needed:

1. **Architect disposition**: which front-end architecture is the real
   Component 5 - a TIA (as `TKT-026` assumed) or a switched-charge
   integrator (as `gcb-analog-rx`'s own README and model assume)? Or are
   both live candidates, with neither yet selected? This ticket cannot
   determine that from the evidence alone - both have a real government
   document and a real, runnable model behind them.
2. **Once decided**: the NOT-selected architecture's assumptions should be
   explicitly marked superseded (not silently deleted - this program's own
   "append a correction, don't erase history" convention applies here
   too) in whichever ticket/file asserted it, and the selected one's
   parameters (whichever they are) should be re-validated against the
   REAL operating photocurrent (112.5 uA, unless `TKT-026` itself is
   revisited) - the specific `C_INT`/`T_INT`/`V_FS` values in
   `switched_charge_model.py` are its own author's demonstration defaults,
   not yet shown to be the real intended design point either way.
3. Near-term goal #3 from `gcb-analog-rx`'s own README (export the
   extracted noise figure/input capacitance back into the DPI-C optical
   model) is blocked on (1) and (2) - there is nothing real to export
   until the front-end architecture itself is settled.

## What this does NOT claim

- That either architecture is wrong in isolation - a TIA and a switched-
  charge integrator are both legitimate, real circuit topologies for this
  kind of photocurrent-to-digital conversion; this finding is about the
  two tickets' assumptions never having been reconciled, not about either
  one being a design error.
- Any silicon/physical measurement - both models are behavioral
  (Python/numpy and a hand-derived responsivity figure respectively); this
  is a digital-model-level finding only.

---
## Architect Disposition (2026-09-12)

**Decision, recorded verbatim (lightly reformatted for this file, content
unchanged): adopt the switched-charge integrator topology as the primary
architecture for Phase I, while keeping the TIA specification as a
fallback for continuous-stream debugging.**

1. **Cadence alignment** - the system relies on a discrete fire-strobe
   cadence rather than a continuous >=10 Gbps bitstream. A switched-charge
   integrator naturally acts as a matched filter over the optical
   integration window, maximizing SNR by summing the photo-generated
   charge precisely when the pulse is active.
2. **Thermal and power efficiency** - continuous TIAs draw constant DC
   bias current across all 60 channels. At scale, the static power
   dissipation of 60 parallel high-gain TIAs complicates thermal
   management on the analog evaluation board. A switched-integrator
   front-end consumes dynamic power tied directly to the execution rate.
3. **Dynamic range scaling** - instead of being locked to a fixed
   13.3 kOhm transimpedance resistor that risks clipping if optical
   insertion loss is lower than modeled, a switched-integrator allows
   variable integration intervals (Delta t) or switchable feedback
   capacitors (C_int) to absorb margin variations electronically without
   hardware board modifications.

**Directive:** update the analog front-end specification to designate
the switched-charge integrator as the baseline for the multi-channel
receive path, while preserving `TKT-026`'s TIA math for benchtop
calibration and continuous-wave optical link testing.

## Execution Log

**Claim 1 (cadence alignment) and claim 2 (thermal/power efficiency) are
architectural/systems arguments, not independently checkable by this
program's own digital-simulation tooling** - accepted as the Architect's
own engineering judgment, not re-derived or disputed here.

**Claim 3 (dynamic range scaling) IS a checkable, quantitative claim, and
was checked - not merely restated** (`gcb-analog-rx@5290e72`):

1. Added a real switchable feedback-capacitor bank to
   `switched_charge_model.py` (`C_INT_BANK`, 10-50 fF - the file's own
   already-documented "typical on-die" range, not a newly-invented one)
   and `select_c_int()`, which picks the smallest bank entry keeping
   `V_signal` within a documented [10%, 80%] window of `V_FS` (clear of
   both ADC clipping and the quantization-noise floor).
2. **First check found claim 3 only PARTIALLY true as stated, reported
   honestly rather than silently narrowed:** at `TKT-026`'s nominal
   112.5 uA, `C_int=47 fF` covers it (`V_signal=478.7 mV`, `SNR(kT/C)
   =64.2 dB`, `+34.2 dB` margin vs. the 30 dB budget) and a -50%
   insertion-loss variation (56.2 uA) is covered by `C_int=25 fF`
   (`+30.9 dB` margin) - but a +50% variation (168.8 uA, the Architect's
   own named worst case - "clipping if insertion loss is lower than
   modeled," i.e. MORE received power) needs `C_int~=70 fF`, which
   exceeds this file's own documented 10-50 fF realistic on-die range.
   `C_int` alone does not fully deliver claim 3 across the stated
   variation band.
3. **The Architect's own disposition named a SECOND knob
   ("variable integration intervals (Delta t)") - it was not yet
   implemented, so it was added rather than stopping at the partial
   result:** `T_INT_BANK` (three clock-divider-style integration windows:
   200/142.9/100 ps) and `select_c_int_t_int()`, a joint search over both
   banks. Re-verified: the +50% case (168.8 uA) now closes using
   `C_int=40 fF` **and** `T_int=100 ps` together - within both banks'
   documented ranges, with `+32.4 dB` margin vs. the 30 dB budget.
4. `phase1_baseline_check()` (new, part of the script's own `__main__`,
   exits nonzero on any uncovered point) re-run, full output:

   | Test point | `I_in` | Knob(s) used | `C_int` | `T_int` | `V_signal` | SNR margin vs 30 dB |
   |---|---:|---|---:|---:|---:|---:|
   | `I_NOMINAL` (TKT-026 nominal) | 112.5 uA | C_int only | 47.0 fF | 200.0 ps | 478.7 mV | +34.2 dB |
   | `I_VARIATION_LOW` (-50%) | 56.2 uA | C_int only | 25.0 fF | 200.0 ps | 450.0 mV | +30.9 dB |
   | `I_VARIATION_HIGH` (+50%) | 168.8 uA | C_int + T_int (C_int alone insufficient) | 40.0 fF | 100.0 ps | 421.9 mV | +32.4 dB |

   **`PHASE I BASELINE VERIFIED`** - every test point covered, script exits 0.

**PROVEN — DIGITAL SIMULATION (Python/numpy behavioral model), TESTED
CONDITIONS**: claim 3, as actually implemented (both knobs together, not
`C_int` alone), covers TKT-026's nominal operating point and a ±50%
insertion-loss variation band around it. **Not claimed**: that ±50% is
the REAL insertion-loss uncertainty of the physical link (no measured
figure exists yet - that is `TKT-030`/`gcb-pic-core`'s own still-open FDTD-
extraction question); that the specific `T_INT_BANK` divider ratios
(200/142.9/100 ps) are a committed clock-tree decision, not a
stand-in for "a few clock-divider taps"; or any physical/silicon
measurement of any kind - this is a behavioral model result only.

**`TKT-026` updated** (its own file, this commit) to record its new role
per the Architect's directive: TIA math retained as the benchtop-
calibration / continuous-wave fallback specification, not retired.

## Telemetry & Evaluation

Spec 0.9 - the Architect's directive is implemented essentially as
stated (designate the switched-charge integrator as baseline, preserve
TKT-026 as fallback), with claim 3 actually verified rather than taken on
faith; not 1.0 because the ±50% variation band itself is a round,
unmeasured stand-in (flagged as such), not a real link-budget figure.
Quality 0.9 - the verification is real (an actual script run, not hand
arithmetic), found and reported a genuine partial failure (C_int alone)
before finding the fix (C_int+T_int together) rather than adjusting the
test to pass; not higher because `T_INT_BANK`'s specific divider values
are a design stand-in, not yet a real clock-tree commitment. Emergence
0.3 - the joint C_int+T_int search is a new verification capability this
ticket's own investigation required building, not something either
source document specified in advance.

**Final State:** `done | blue` - Architect disposition implemented and
verified; `gcb-analog-rx@5290e72`, this commit.

---
## Flag (2026-09-12, same day, `TKT-035`): this disposition was made
without checking `gcb-spec/docs/adr/ADR-005-Single-Slope-Readout.md`,
which already LOCKED a different, already-synthesized Rx for the same
role

**Checked directly, not assumed**: `ADR-005` (Accepted, 2026-09-07 -
BEFORE this ticket's own disposition) picked **Single-Slope CIS**
(discharge-mode integration onto `C_int`, then ONE comparison against a
shared ramp, time-stamped by a shared 6 GHz Gray counter) over a
**Charge-Balancing ΔΣ** branch, now retired. This is Track A's real,
already-synthesized receiver (`greencoyote_ss_tdc.sv`/`_calib.sv`, real
Vivado evidence per `TKT-035`).

**`gcb-analog-rx`'s switched-charge integrator is neither of ADR-005's
two candidates**:
- NOT the retired ΔΣ - no feedback-nulling loop, no 1-bit quantizer, no
  decimated bitstream (`switched_charge_model.py`'s own docstring:
  "a switched-capacitor integrator followed by an ADC comparator bank" -
  structurally different).
- NOT an implementation of the winning Single-Slope CIS either - it
  shares the same front-end physics (passive integration onto `C_int`,
  discharge-mode), but its back-end is a **flash/comparator-bank ADC**
  (voltage-domain, multi-bit in one step), not Single-Slope's **ramp +
  shared Gray-counter TDC** (time-domain). The modeled integration
  window (`T_int` = 200 ps, `F_CLK` = 5 GHz) also does not match
  `ADR-005`'s own locked window (`T_obs` = 256 ns) - over 1000x
  different, indicating this model was built independently of `ADR-005`'s
  real numbers, not calibrated against them.

**This ticket's own "Phase I BASELINE for the multi-channel receive
path" disposition is therefore real and verified on its own terms (the
dynamic-range math checks out), but describes a THIRD, separate Rx
circuit from the one `ADR-005` already locked and synthesized for the
same role** - not confirmed as complementary, a superseded earlier
exploration, or a genuine architecture conflict with `ADR-005` itself.
Flagged for the Architect, not resolved here - this ticket's own prior
disposition is not silently overridden, per this program's standing
discipline against unilaterally re-deciding an Architect call.

---
## Simplification (2026-09-12, same day, `TKT-035`): the flag above was
real but overstated - there is no reconciliation needed

**`gcb-analog-rx` self-describes, in its own README header, as part of
"the GCB Photonic QAM Accelerator"** - a real, separate, named second
program from "GCB/ODIN_Bridge" (`ADR-005`'s own program, `gcb-spec`'s
5-repo list). `ADR-005` never had jurisdiction over `gcb-analog-rx`'s
design question in the first place - it was deciding the Rx for a
DIFFERENT program's receiver role, not this one's. The two "candidates"
never competed; they are each the Rx question for a different,
separately-evidenced accelerator.

**This does not retract the flag's own factual content** (the mechanism
comparison, the 1000x timing mismatch, all still accurate and worth
keeping on file) - it retracts the implication that anything needs
reconciling. No Architect decision is actually pending here;
`gcb-analog-rx`'s own `TKT-031` disposition stands on its own terms, for
its own program, same as before this flag was raised.
