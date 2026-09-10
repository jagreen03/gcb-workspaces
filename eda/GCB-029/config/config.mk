# GCB-029 - Measurement Epoch (EPIC TKT-018) Story 2, per TKT-000.
# EXACT same flow as GCB-027 (gcb_max_reduce, asap7, 1000 ps target, default
# recipe, no tuning) with ONE change: REG_STAGES=2 on the top module, applied
# through ORFS VERILOG_TOP_PARAMS (chparam -set REG_STAGES 2 before synth).
# Physically validates the GCB-028 architectural pipeline response.
export PLATFORM              = asap7
export DESIGN_NAME           = gcb_max_reduce
export VERILOG_FILES         = $(DESIGN_HOME)/src/gcb_max_reduce/gcb_max_reduce.v
export SDC_FILE              = $(DESIGN_HOME)/asap7/gcb_max_reduce/constraint.sdc
export VERILOG_TOP_PARAMS    = REG_STAGES 2

# identical floorplan knobs to GCB-027; NOT tuned for this block
export CORE_UTILIZATION      = 40
export CORE_ASPECT_RATIO     = 1
export CORE_MARGIN           = 2
export PLACE_DENSITY         = 0.55
export SKIP_LAST_GASP        = 1
