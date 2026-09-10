# GCB-032 - Measurement Epoch (EPIC TKT-018) Story 4, per TKT-000.
# Physical validation of the GCB-031 mid-tree pipelined gcb_max_reduce.
# = GCB-029 config EXACTLY (REG_STAGES=2 via VERILOG_TOP_PARAMS, 1000 ps SDC,
#   default deliberately-ugly recipe) with NO SYNTH_RETIME_MODULES line -
#   relying strictly on the RTL mid-tree pipeline to close 1 ns.
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
