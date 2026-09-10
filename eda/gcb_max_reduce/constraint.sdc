# GCB-027 - a stated aggressive target to force the timing engine to work.
# gcb_max_reduce at default params (WIDTH=16 N_ELEMENTS=64 OUTPUT=BOTH
# REG_STAGES=0) is a COMBINATIONAL tournament tree: clk/rst_n are ports but
# drive nothing, so the timed paths are input -> output against a virtual
# clock. Period is NOT adjusted to whatever the result turns out to be.
current_design gcb_max_reduce

set clk_name       core_clock
set clk_port_name  clk
set clk_period     1000
set clk_io_pct     0.20

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period

set non_clock_inputs [all_inputs -no_clocks]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_io_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_io_name [all_outputs]
