# GCB-030 - Measurement Epoch (EPIC TKT-018) Story 3, per TKT-000.
# = GCB-029 config + register retiming enabled. ONLY diff vs GCB-029:
#   export SYNTH_RETIME_MODULES = gcb_max_reduce
# (ORFS synth.tcl: select $SYNTH_RETIME_MODULES; opt; memory_map; opt; techmap;
#  abc -dff -script abc_retime.script  ->  retime -M 5 passes then map)
export PLATFORM              = asap7
export DESIGN_NAME           = gcb_max_reduce
export VERILOG_FILES         = $(DESIGN_HOME)/src/gcb_max_reduce/gcb_max_reduce.v
export SDC_FILE              = $(DESIGN_HOME)/asap7/gcb_max_reduce/constraint.sdc
export VERILOG_TOP_PARAMS    = REG_STAGES 2
export SYNTH_RETIME_MODULES  = gcb_max_reduce

export CORE_UTILIZATION      = 40
export CORE_ASPECT_RATIO     = 1
export CORE_MARGIN           = 2
export PLACE_DENSITY         = 0.55
export SKIP_LAST_GASP        = 1
