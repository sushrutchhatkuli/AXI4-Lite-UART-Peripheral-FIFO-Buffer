@echo off
REM ============================================================================
REM Vivado xsim Automated Simulation Script
REM Project: AXI4-Lite UART Peripheral & FIFO Buffer
REM
REM Usage (from the repository root, with Vivado's bin directory on PATH):
REM     tb\run_xsim.bat
REM ============================================================================

setlocal
cd /d "%~dp0.."

echo --- Compiling RTL and Testbench Sources ---
call xvlog --sv ^
    rtl/uart_pkg.sv ^
    rtl/fifo_circular.sv ^
    rtl/uart_baud_gen.sv ^
    rtl/uart_tx.sv ^
    rtl/uart_rx.sv ^
    rtl/axi4_lite_slave.sv ^
    rtl/uart_axi_top.sv ^
    tb/axi4_lite_if.sv ^
    tb/axi_master_bfm.sv ^
    tb/tb_uart_axi_top.sv
if errorlevel 1 exit /b 1

echo --- Elaborating ---
call xelab -debug typical -timescale 1ns/1ps tb_uart_axi_top -s tb_uart_axi_top_snap
if errorlevel 1 exit /b 1

echo --- Executing Simulation ---
call xsim tb_uart_axi_top_snap -R
if errorlevel 1 exit /b 1

endlocal
