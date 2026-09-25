---
title: "FPGA Synthesis & Timing Implementation Results"
tags:
  - fpga
  - synthesis
  - timing
  - vivado
  - artix-7
  - hardware-metrics
date: 2026-09-25
status: complete
---

# FPGA Synthesis & Timing Implementation Results

This document provides complete static timing analysis (STA) metrics and hardware resource utilization data for the **AXI4-Lite UART Peripheral & FIFO Buffer**, synthesized using **AMD Vivado 2025.1** targeting an **AMD Artix-7** FPGA (`xc7a35tcsg324-1`).

---

## 1. Synthesis Methodology

- **Tool**: AMD Vivado v2025.1 (Build 6140274)
- **Target Part**: `xc7a35tcsg324-1` (Speed grade: -1)
- **Flow**: Non-project batch mode (`vivado -mode batch -source synth.tcl`)
- **Synthesis Mode**: Out-of-context (`-mode out_of_context`)
- **Clock Constraint**: Single synchronous clock domain `s_axi_aclk` constrained to $10.000\text{ ns}$ ($100.000\text{ MHz}$).

---

## 2. Static Timing Analysis (STA) Summary

Static timing analysis was conducted under full multi-corner min/max conditions with pessimism removal.

| Timing Metric | User Constraint | Measured Value | Timing Slack Margin | Status |
| :--- | :---: | :---: | :---: | :---: |
| **Worst Negative Slack (WNS)** | $\ge 0.000\text{ ns}$ | **+5.542 ns** | $+55.42\%$ clock cycle margin | **PASSED** |
| **Worst Hold Slack (WHS)** | $\ge 0.000\text{ ns}$ | **+0.164 ns** | Positive hold margin | **PASSED** |
| **Worst Pulse Width Slack (WPWS)** | $\ge 0.000\text{ ns}$ | **+4.500 ns** | Minimum high/low pulse met | **PASSED** |
| **Total Negative Slack (TNS)** | $0.000\text{ ns}$ | **0.000 ns** | 0 failing endpoints of 901 | **PASSED** |
| **Total Hold Slack (THS)** | $0.000\text{ ns}$ | **0.000 ns** | 0 failing endpoints of 901 | **PASSED** |
| **Total Pulse Width Slack (TPWS)** | $0.000\text{ ns}$ | **0.000 ns** | 0 failing endpoints of 501 | **PASSED** |

### Maximum Frequency ($F_{\text{max}}$) Calculation

The critical path data delay through combinational logic and interconnect is:
$$T_{\text{data, critical}} = T_{\text{clk}} - \text{WNS} = 10.000\text{ ns} - 5.542\text{ ns} = 4.458\text{ ns}$$

The theoretical maximum operating frequency on Artix-7 (-1 speed grade) is:
$$F_{\text{max}} = \frac{1}{T_{\text{data, critical}}} = \frac{1}{4.458\text{ ns}} \approx 224.31\text{ MHz}$$

This demonstrates that the peripheral easily fulfills the $100\text{ MHz}$ system clock target with over $2.2\times$ timing margin.

---

## 3. Resource Utilization Breakdown

### Logic & Storage Elements

| Site Type | Used | Fixed | Available | Utilization % |
| :--- | :---: | :---: | :---: | :---: |
| **Slice LUTs** | **314** | 0 | 20,800 | **1.51%** |
| - LUT as Logic | 314 | 0 | 20,800 | 1.51% |
| - LUT as Distributed Memory | 0 | 0 | 9,600 | 0.00% |
| **Slice Registers** | **501** | 0 | 41,600 | **1.20%** |
| - Register as Flip-Flop | 501 | 0 | 41,600 | 1.20% |
| - Register as Latch | **0** | 0 | 41,600 | **0.00%** |
| **F7 Muxes** | 28 | 0 | 16,300 | 0.17% |
| **F8 Muxes** | 6 | 0 | 8,150 | 0.07% |
| **Block RAM (BRAM)** | 0 | 0 | 50 | 0.00% |
| **DSP48 Slices** | 0 | 0 | 90 | 0.00% |

### Module Hierarchical Area Distribution

| Instance | Module Name | Primitive Cells | Key Functions |
| :--- | :--- | :---: | :--- |
| `top` | `uart_axi_top` | 916 | Top-level muxes, interrupt generation, loopback gating |
| `axi_slave_inst` | `axi4_lite_slave` | 286 | Decoupled AW/W channels, address decode, status registers |
| `rx_fifo_inst` | `fifo_circular` | 239 | 16x8 RAM array, 5-bit pointer rollover full/empty flags |
| `tx_fifo_inst` | `fifo_circular` | 231 | 16x8 RAM array, 5-bit pointer rollover full/empty flags |
| `rx_inst` | `uart_rx` | 60 | 2-FF synchronizer, Tick 7 center sampler, framing error detector |
| `baud_gen_inst` | `uart_baud_gen` | 48 | 16-bit programmable pulse down-counter |
| `tx_inst` | `uart_tx` | 48 | 8-N-1 parallel-to-serial shift register FSM |

---

## 4. Design Rule & Quality Checks

1. **Zero Latches Inferred**: The register summary reports `Register as Latch = 0`. All combinational blocks (`always_comb`) provide full signal coverage, guaranteeing purely synchronous flip-flop inference without timing hazards.
2. **Zero Combinational Loops**: STA confirms 0 combinational loops in the netlist.
3. **No Unconstrained Endpoints**: All 901 timing endpoints are fully constrained under the primary clock `s_axi_aclk`.
4. **Clean Reset Strategy**: All registers utilize synchronous resets (`FDRE` / `FDCE`), ensuring predictable initialization and eliminating reset recovery/removal violations.
