# STANDING ORFS / ASAP7 config for gcb_max_reduce  (GCB-033).
#
# This is the canonical, measurement-ticket-independent P&R config for the
# shared gcb_max_reduce primitive. Future Measurement-Epoch stories copy from
# here rather than from a numbered ticket's snapshot.
#
# Closure path:  the RTL mid-tree pipeline (GCB-031: REG_STAGES>0 places its
# registers BETWEEN tournament levels, genvar-elaborated segments).
#   * REG_STAGES=2 via VERILOG_TOP_PARAMS -> chparam -set REG_STAGES 2 -> the
#     for(genvar p=0;p<=K;p++):g_seg segments re-elaborate.
#   * NO SYNTH_RETIME_MODULES.  Synthesis register retiming for this block is
#     RETIRED - GCB-030 showed it closes 1 ns but by replicating 46 -> 818
#     flops; GCB-031/GCB-032 close it in the RTL at 372 flops.
#
# Validated by GCB-032 (exact GCB-029 flow, netlist = sv2v of the GCB-031
# rtl/gcb_max_reduce.sv, gcb-wdm-transceiver 642251c):
#   WNS 0.00 ps @ 1 ns, 0 setup violations, fmax 1.519 GHz, 0 detailed-route
#   DRC, 372 DFFASRHQN flops, 714.78 um2 synth / 810 um2 post-route, 9.37 mW.
#   Open item: 38 max-slew DRVs (the wide mid-tree bank-1 fan-out) - a
#   SKIP_LAST_GASP=0 slew-repair pass is a separate follow-on.
# Numbers: eda/GCB-032/report.json.  Deliberately-ugly recipe (no floorplan or
# knob tuning) per TKT-000 - a "bad number" is a positive Orange result.
export PLATFORM              = asap7
export DESIGN_NAME           = gcb_max_reduce
export VERILOG_FILES         = $(DESIGN_HOME)/src/gcb_max_reduce/gcb_max_reduce.v
export SDC_FILE              = $(DESIGN_HOME)/asap7/gcb_max_reduce/constraint.sdc
export VERILOG_TOP_PARAMS    = REG_STAGES 2

export CORE_UTILIZATION      = 40
export CORE_ASPECT_RATIO     = 1
export CORE_MARGIN           = 2
export PLACE_DENSITY         = 0.55
export SKIP_LAST_GASP        = 1
