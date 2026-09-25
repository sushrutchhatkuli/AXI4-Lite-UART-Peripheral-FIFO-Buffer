@echo off
setlocal EnableDelayedExpansion
for %%I in ("%~dp0..") do set "ROOT_SHORT=%%~sI"
cd /d "!ROOT_SHORT!"

where xvlog >nul 2>nul
if errorlevel 1 (
    if exist "C:\Xilinx\2025.1\Vivado\bin" (
        set "PATH=C:\Xilinx\2025.1\Vivado\bin;!PATH!"
    )
)

echo --- Compiling uart_rx and Unit Testbench ---
call xvlog --sv rtl/uart_pkg.sv rtl/uart_rx.sv tb/tb_uart_rx.sv
if errorlevel 1 exit /b 1

echo --- Elaborating ---
call xelab -debug typical -timescale 1ns/1ps tb_uart_rx -s tb_uart_rx_snap
if errorlevel 1 exit /b 1

echo --- Executing Simulation ---
call xsim tb_uart_rx_snap -R
if errorlevel 1 exit /b 1

endlocal
