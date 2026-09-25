# Non-project mode Vivado synthesis script
set_param general.maxThreads 8

# Resolve repository root relative to this script
set SCRIPT_DIR [file dirname [file normalize [info script]]]
cd [file join $SCRIPT_DIR ".."]

# Read SystemVerilog sources
read_verilog -sv [glob rtl/*.sv]

# Run synthesis with out-of-context mode for IP peripheral
synth_design -top uart_axi_top -part xc7a35tcsg324-1 -mode out_of_context

# 100 MHz clock constraint (10 ns)
create_clock -period 10.000 -name s_axi_aclk [get_ports s_axi_aclk]

# Generate reports in synth/ directory
report_utilization -file synth/utilization.rpt
report_timing_summary -file synth/timing.rpt

puts "=== SYNTHESIS AND TIMING REPORTS GENERATED ==="
exit
