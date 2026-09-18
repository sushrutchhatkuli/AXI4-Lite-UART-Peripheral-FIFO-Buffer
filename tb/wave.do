# Waveform configuration for ModelSim / QuestaSim
add wave -noupdate -divider "Clock & Reset"
add wave -noupdate -hex /tb_uart_axi_top/clk
add wave -noupdate -hex /tb_uart_axi_top/rst_n

add wave -noupdate -divider "AXI4-Lite Write Channels"
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_awaddr
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_awvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_awready
add wave -noupdate -hex /tb_uart_axi_top/dut/s_axi_wdata
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
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_rvalid
add wave -noupdate -bin /tb_uart_axi_top/dut/s_axi_rready

add wave -noupdate -divider "FIFOs"
add wave -noupdate -unsigned /tb_uart_axi_top/dut/tx_fifo_inst/count
add wave -noupdate -bin      /tb_uart_axi_top/dut/tx_fifo_inst/full
add wave -noupdate -bin      /tb_uart_axi_top/dut/tx_fifo_inst/empty
add wave -noupdate -unsigned /tb_uart_axi_top/dut/rx_fifo_inst/count
add wave -noupdate -bin      /tb_uart_axi_top/dut/rx_fifo_inst/full
add wave -noupdate -bin      /tb_uart_axi_top/dut/rx_fifo_inst/empty

add wave -noupdate -divider "Serial Lines & States"
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_txd
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_rxd
add wave -noupdate -bin /tb_uart_axi_top/dut/baud_16x_tick
add wave -noupdate -ascii /tb_uart_axi_top/dut/tx_inst/state_reg
add wave -noupdate -ascii /tb_uart_axi_top/dut/rx_inst/state_reg
add wave -noupdate -bin /tb_uart_axi_top/dut/rx_inst/framing_err
add wave -noupdate -bin /tb_uart_axi_top/dut/uart_irq

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
