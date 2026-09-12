---
id: TKT-031
title: "gcb-analog-rx Component 5: TIA (TKT-026) vs switched-charge integrator (switched_charge_model.py) - two mutually-exclusive front-end architectures, unreconciled"
date_created: 2026-09-12
status: open
telemetry_color: pending
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

## Telemetry & Evaluation

No PBG grade - this is a findings-and-disposition ticket, not executed
work, consistent with this program's convention for architecture
conflicts (e.g. `TKT-019.6`/`.7`'s own precedent: report, don't silently
patch).

**Final State:** `open | pending` - held for Architect disposition.
