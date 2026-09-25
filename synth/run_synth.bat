@echo off
setlocal EnableDelayedExpansion
REM Resolve 8.3 short path to avoid Vivado rdiArgs batch script ampersand failure
for %%I in ("%~dp0..") do set "ROOT_SHORT=%%~sI"
for %%I in ("%~dp0") do set "SYNTH_SHORT=%%~sI"

cd /d "!SYNTH_SHORT!"

where vivado >nul 2>nul
if errorlevel 1 (
    if exist "C:\Xilinx\2025.1\Vivado\bin" (
        set "PATH=C:\Xilinx\2025.1\Vivado\bin;!PATH!"
    )
)

echo --- Running Vivado Out-of-Context Synthesis ---
call vivado -mode batch -source synth.tcl -nojournal -nolog
