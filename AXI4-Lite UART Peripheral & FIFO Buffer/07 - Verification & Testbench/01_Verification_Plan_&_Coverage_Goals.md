---
title: "Verification Plan & Coverage Goals"
tags:
  - verification
  - testplan
  - coverage
  - systemverilog
  - modelsim
date: 2026-09-18
status: active
---

# Verification Plan & Coverage Goals

A comprehensive verification strategy is essential to guarantee that the synthesizable AXI4-Lite UART Peripheral adheres strictly to the AMBA protocol specification, operates reliably under noisy serial conditions, and never locks up.

---

## 1. Verification Strategy & Objectives

1. **Protocol Compliance**: Verify that all 5 AXI4-Lite channels satisfy handshake rules, including skewed `AW`/`W` arrivals and random backpressure on `BREADY` / `RREADY`.
2. **Data Path Integrity**: Guarantee that all transmitted bytes match received bytes in order without drops, bitflips, or duplication under high-throughput loopback.
3. **Buffer Boundary Safety**: Verify that FIFOs correctly report `full`, `empty`, and `count`, and that illegal operations (overflow/underflow) trigger appropriate error flags without corrupting valid data.
4. **Fault Tolerance & Recovery**: Inject framing errors, start-bit noise glitches, and overrun scenarios, verifying that the peripheral reports them via status/interrupts and recovers seamlessly.

---

## 2. Test Matrix & Feature Scenarios

| Test ID | Test Category | Description | Success Criteria |
| :---: | :--- | :--- | :--- |
| **TC_01** | Reg Access | Read/write all registers at default reset; check defaults | Reset values match register map exactly |
| **TC_02** | Unmapped Addr | Write/read to unmapped address `0x20` | Slave returns `2'b10` (`SLVERR`) |
| **TC_03** | Single Byte TX | Transmit 1 byte via AXI, monitor serial pin with TB monitor | Bit timing, start, 8-data, and stop bits match baud rate |
| **TC_04** | Burst TX (16B) | Burst 16 bytes into TX FIFO at 100MHz bus speed | TX FIFO becomes FULL; all 16 bytes stream back-to-back |
| **TC_05** | FIFO Overflow | Write 17th byte to full TX FIFO | Write ignored; existing 16 bytes preserved; `STAT[6]` set |
| **TC_06** | FIFO Underflow | Read from empty RX FIFO | Returns `0x00`; pointers do not advance; no crash |
| **TC_07** | Int. Loopback | Enable `CTRL[2]`; write random stream; read from RX FIFO | Scoreboard reports 0 mismatches across 1000+ packets |
| **TC_08** | Random AXI Skew | Randomize delays (0-10 cycles) between `AWVALID` and `WVALID` | Zero deadlocks; all writes complete with `OKAY` |
| **TC_09** | Random Backpressure| Master randomly de-asserts `BREADY` and `RREADY` | Slave holds `BVALID` / `RVALID` until accepted |
| **TC_10** | Glitch Reject | Inject 3-tick low pulse during RX idle line | Glitch discarded at tick 7; receiver returns to IDLE |
| **TC_11** | Framing Error | Force RX line to 0 during stop bit window | `STAT[5]` asserted, interrupt triggered, bad byte dropped |
| **TC_12** | Frame Recovery | Send valid byte immediately following TC_11 | Valid byte correctly captured; framing error cleared via W1C |
| **TC_13** | Multi-Baud | Reprogram `BAUD_DIV` to 9600, 38400, 115200, 921600 | Serial timing matches expected bit rates within < 1% |

---

## 3. Functional Coverage Model

```systemverilog
covergroup cg_uart @(posedge clk);
    // Cover all register access addresses
    cp_addr: coverpoint s_axi_awaddr[7:0] {
        bins data_reg     = {8'h00};
        bins stat_reg     = {8'h04};
        bins ctrl_reg     = {8'h08};
        bins baud_div_reg = {8'h0C};
        bins fifo_cnt_reg = {8'h10};
        bins intr_stat    = {8'h14};
        bins intr_en      = {8'h18};
        bins unmapped     = {[8'h1C:8'hFF]};
    }

    // Cover FIFO occupancy extremes
    cp_tx_cnt: coverpoint tx_fifo_cnt {
        bins empty = {0};
        bins partial = {[1:15]};
        bins full = {16};
    }
    cp_rx_cnt: coverpoint rx_fifo_cnt {
        bins empty = {0};
        bins partial = {[1:15]};
        bins full = {16};
    }

    // Cover Error Flags
    cp_framing_err: coverpoint framing_err_flag {
        bins asserted = {1'b1};
        bins cleared  = {1'b0};
    }
    cp_overrun_err: coverpoint overrun_err_flag {
        bins asserted = {1'b1};
        bins cleared  = {1'b0};
    }
endgroup
```

[[02_AXI4_Lite_Master_BFM_&_Test_Scenarios|Next: AXI4-Lite Master BFM & Test Scenarios ->]]
