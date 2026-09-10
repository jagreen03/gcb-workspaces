# GCB-027 - Measurement Epoch (EPIC TKT-018), per TKT-000.
# Deliberately UNOPTIMIZED first physical pass of gcb_max_reduce (TKT-016).
# Verilog source is the RTL-Baseline sv2v output, handed over at the file
# boundary - no EDA intermediates under gcb-wdm-transceiver.
export PLATFORM              = asap7
export DESIGN_NAME           = gcb_max_reduce
export VERILOG_FILES         = $(DESIGN_HOME)/src/gcb_max_reduce/gcb_max_reduce.v
export SDC_FILE              = $(DESIGN_HOME)/asap7/gcb_max_reduce/constraint.sdc

# stock-ish floorplan knobs; NOT tuned for this block
export CORE_UTILIZATION      = 40
export CORE_ASPECT_RATIO     = 1
export CORE_MARGIN           = 2
export PLACE_DENSITY         = 0.55
export SKIP_LAST_GASP        = 1
