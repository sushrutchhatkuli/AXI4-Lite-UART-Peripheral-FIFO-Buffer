---
title: "ModelSim Simulation & DO Scripts"
tags:
  - modelsim
  - questasim
  - automation
  - simulation
  - scripts
date: 2026-09-18
status: active
---

# ModelSim Simulation & DO Scripts

This document outlines the simulation setup, automated TCL/DO scripts, and waveform configuration for executing tests in **Mentor Graphics ModelSim / QuestaSim**.

---

## 1. Batch Execution Flow

Simulation can be triggered with a single command:
```bash
vsim -c -do "do run_sim.do; quit -f"
```
Or for interactive GUI debugging:
```bash
vsim -do run_sim.do
```

---

## 2. Complete ModelSim DO Script (`run_sim.do`)

```tcl
# ==============================================================================
# ModelSim / QuestaSim Automated Simulation Script
# Project: AXI4-Lite UART Peripheral & FIFO Buffer
# ==============================================================================

# 1. Create and clean working library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Compile SystemVerilog RTL source files
puts "--- Compiling RTL Source Files ---"
vlog -sv -work work +acc \
    ../rtl/uart_pkg.sv \
    ../rtl/fifo_circular.sv \
    ../rtl/uart_baud_gen.sv \
    ../rtl/uart_tx.sv \
    ../rtl/uart_rx.sv \
    ../rtl/axi4_lite_slave.sv \
    ../rtl/uart_axi_top.sv

# 3. Compile SystemVerilog Testbench files
puts "--- Compiling Testbench Files ---"
vlog -sv -work work +acc \
    ../tb/axi4_lite_if.sv \
    ../tb/tb_uart_axi_top.sv

# 4. Load Simulation with 1ps precision
puts "--- Loading Simulation Instance ---"
vsim -t 1ps -voptargs="+acc" work.tb_uart_axi_top

# 5. Configure Waveform Window
if {[batch_mode] == 0} {
    puts "--- Configuring Waveforms ---"
    do wave.do
}

# 6. Execute Simulation
puts "--- Running Simulation ---"
run -all

# 7. Summary
puts "--- Simulation Finished ---"
```

---

## 3. Waveform Macro Script (`wave.do`)

```tcl
# Add Clock & Reset
add wave -noupdate -divider "Clock & Reset"
add wave -noupdate -hex /tb_uart_axi_top/clk
add wave -noupdate -hex /tb_uart_axi_top/rst_n

# Add AXI4-Lite Bus Channels
add wave -noupdate -divider "AXI4-Lite Write Channels"
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_awaddr
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_awvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_awready
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_wdata
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_wstrb
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_wvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_wready
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_bresp
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_bvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_bready

add wave -noupdate -divider "AXI4-Lite Read Channels"
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_araddr
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_arvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_arready
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_rdata
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_rresp
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_rvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_rready

# Add FIFOs
add wave -noupdate -divider "FIFOs"
add wave -noupdate -unsigned /tb_uart_axi_top/dut/tx_fifo_inst/count
add wave -noupdate -bin      /tb_uart_axi_top/dut/tx_fifo_inst/full
add wave -noupdate -bin      /tb_uart_axi_top/dut/tx_fifo_inst/empty
add wave -noupdate -unsigned /tb_uart_axi_top/dut/rx_fifo_inst/count
add wave -noupdate -bin      /tb_uart_axi_top/dut/rx_fifo_inst/full
add wave -noupdate -bin      /tb_uart_axi_top/dut/rx_fifo_inst/empty

# Add UART Serial Lines & Engine FSMs
add wave -noupdate -divider "UART Serial & FSM"
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_txd
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_rxd
add wave -noupdate -bin /tb_uart_axi_top/dut/baud_16x_tick
add wave -noupdate -ascii /tb_uart_axi_top/dut/tx_inst/state_reg
add wave -noupdate -ascii /tb_uart_axi_top/dut/rx_inst/state_reg
add wave -noupdate -bin /tb_uart_axi_top/dut/rx_inst/framing_err
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_irq

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
```

[[01_Resume_Deep_Dive_&_Interview_Questions|Next: 25+ Resume Deep-Dive Technical Interview Questions ->]]
