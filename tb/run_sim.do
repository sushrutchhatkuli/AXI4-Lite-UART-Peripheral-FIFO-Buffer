# ==============================================================================
# ModelSim / QuestaSim Automated Simulation Script
# Project: AXI4-Lite UART Peripheral & FIFO Buffer
# Author:  Sushrut Chhatkuli
# ==============================================================================

# Create work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL Source Files
puts "--- Compiling RTL SystemVerilog Sources ---"
vlog -sv -work work +acc     ../rtl/uart_pkg.sv     ../rtl/fifo_circular.sv     ../rtl/uart_baud_gen.sv     ../rtl/uart_tx.sv     ../rtl/uart_rx.sv     ../rtl/axi4_lite_slave.sv     ../rtl/uart_axi_top.sv

# Compile Testbench
puts "--- Compiling Testbench Sources ---"
vlog -sv -work work +acc     ../tb/axi4_lite_if.sv     ../tb/axi_master_bfm.sv     ../tb/tb_uart_axi_top.sv

# Load simulation instance
puts "--- Loading Simulation Instance ---"
vsim -t 1ps -voptargs="+acc" work.tb_uart_axi_top

# Add Waves if in GUI mode
if {[batch_mode] == 0} {
    do wave.do
}

# Run entire testbench
puts "--- Executing Simulation ---"
run -all
