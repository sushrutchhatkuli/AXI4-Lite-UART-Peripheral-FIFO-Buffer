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

echo --- Compiling fifo_circular and Unit Testbench ---
call xvlog --sv rtl/fifo_circular.sv tb/tb_fifo_circular.sv
if errorlevel 1 exit /b 1

echo --- Elaborating ---
call xelab -debug typical -timescale 1ns/1ps tb_fifo_circular -s tb_fifo_circular_snap
if errorlevel 1 exit /b 1

echo --- Executing Simulation ---
call xsim tb_fifo_circular_snap -R
if errorlevel 1 exit /b 1

endlocal
