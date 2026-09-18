---
title: "Resume Specification & Traceability Matrix"
tags:
  - resume
  - requirements
  - traceability
  - systemverilog
date: 2026-09-18
status: active
---

# Resume Specification & Traceability Matrix

This document maps each bullet point from your resume directly to hardware design requirements, module implementations, verification tests, and interview defense topics.

---

## Bullet 1: Synthesizable AXI4-Lite UART Slave & Memory Map

> **Resume Statement:**
> *"Developed a synthesizable UART peripheral using SystemVerilog having an AMBA AXI4-Lite slave interface where the baud divisors and status registers were memory mapped for software-based serial communication."*

### Hardware Requirements
1. **Synthesizability**: All SystemVerilog code must be fully synthesizable (clean clocked `always_ff`, combinational `always_comb`, no non-synthesizable delays or latches).
2. **AXI4-Lite Standard Compliance**:
   - Must implement all 5 AXI4-Lite channels: AW, W, B, AR, R.
   - Decoupled `AWVALID`/`AWREADY` and `WVALID`/`WREADY` handshaking.
   - Robust write response (`BRESP`) returning `2'b00` (OKAY) or `2'b10` (SLVERR) on unmapped addresses.
   - Decoupled read address (`AR`) and read data (`R`) handshaking with `RRESP`.
3. **Memory Mapped Registers**:
   - `0x00` (`UART_DATA`): Transmit (write) and Receive (read) data register.
   - `0x04` (`UART_STATUS`): Read-only status flags (TX_EMPTY, TX_FULL, RX_EMPTY, RX_FULL, RX_DATA_READY, OVERRUN_ERR, FRAMING_ERR).
   - `0x08` (`UART_CTRL`): Configuration register (TX_EN, RX_EN, LOOPBACK_EN, INTR_EN).
   - `0x0C` (`UART_BAUD_DIV`): 16-bit programmable baud rate divisor.
   - `0x10` (`UART_FIFO_CNT`): Live FIFO occupancy levels.
   - `0x14` (`UART_INTR_STAT`): Interrupt status register with W1C behavior.
   - `0x18` (`UART_INTR_EN`): Interrupt mask register.

### Verification Coverage
- AXI write transactions to all registers with varying wait states.
- AXI read transactions verifying reset values and modified values.
- Unmapped address access returning `SLVERR`.

### Relevant Vault Notes
- [[01_AXI4_Lite_Protocol_Fundamentals]]
- [[02_AXI4_Lite_Slave_Interface_Architecture]]
- [[03_Register_Map_Specification]]

---

## Bullet 2: Asynchronous TX/RX, 8-N-1 & 16X Center Sampling

> **Resume Statement:**
> *"Created asynchronous TX/RX with 8-N-1 configuration using 16X baud clock oversampling divider with the use of center sampling technique to reduce transition noise and recover bits reliably."*

### Hardware Requirements
1. **8-N-1 Protocol**:
   - 1 Start Bit (Logic 0)
   - 8 Data Bits (LSB first)
   - No Parity Bit (optional parity support discussed in notes)
   - 1 Stop Bit (Logic 1)
   - Idle line state: Logic 1 (Mark)
2. **16X Oversampling Baud Generator**:
   - Produces a single-cycle pulse every $T_{\text{baud}} / 16$.
   - Divisor equation: $\text{DIVISOR} = \frac{f_{\text{clk}}}{16 \times \text{Baud Rate}} - 1$.
3. **Center Sampling Receiver**:
   - Asynchronous input CDC synchronization via a 2-stage D-FF synchronizer.
   - Start bit edge detection (1-to-0 transition).
   - Glitch rejection: At tick 7 (center of start bit), line must still be 0; otherwise, false start is discarded.
   - Subsequent data bits sampled at tick 7 (center of each 16-tick window).
   - Stop bit sampled at tick 7 to verify valid frame.

### Verification Coverage
- Serial data transmission verified against standard bit times.
- Center sampling immunity against edge jitter and phase offsets up to $\pm 3.5\%$.
- Rejection of short noise glitches ($< 4$ oversampling ticks).

### Relevant Vault Notes
- [[01_Baud_Rate_Generator_&_16X_Oversampling_Math]]
- [[02_Clock_Domain_&_Metastability_CDC]]
- [[01_UART_TX_Architecture_&_FSM]]
- [[01_UART_RX_Architecture_&_FSM]]
- [[02_Center_Sampling_&_Majority_Voting]]

---

## Bullet 3: Dual 16-Element Circular FIFOs (Pointer Rollover)

> **Resume Statement:**
> *"Developed 16-element circular FIFOs for TX/RX independently through pointer rollover method, ensuring that CPU processing is not dependent on speed of serial link."*

### Hardware Requirements
1. **Independent Dual FIFOs**: One dedicated TX FIFO and one dedicated RX FIFO.
2. **Capacity & Depth**: Depth = 16 words, Width = 8 bits.
3. **Pointer Rollover Architecture**:
   - 5-bit pointers: `wptr[4:0]`, `rptr[4:0]`.
   - 4-bit memory addresses: `waddr = wptr[3:0]`, `raddr = rptr[3:0]`.
   - **Empty Condition**: `wptr[4:0] == rptr[4:0]`.
   - **Full Condition**: `(wptr[4] != rptr[4]) && (wptr[3:0] == rptr[3:0])`.
   - **Occupancy Count**: `count[4:0] = wptr[4:0] - rptr[4:0]`.
4. **CPU Decoupling**: CPU bursts 16 bytes into TX FIFO in single-digit clock cycles; UART transmits serially over milliseconds.

### Verification Coverage
- Write until FULL; verify `full` flag asserts and further writes are blocked.
- Read until EMPTY; verify `empty` flag asserts and underflow reads return safe data.
- Simultaneous read and write when partially full, full, and empty.
- Multi-cycle rollover verification (pointers wrapping through multiples of 16).

### Relevant Vault Notes
- [[01_Circular_FIFO_Pointer_Rollover_Theory]]
- [[02_FIFO_Hardware_Implementation_&_Flags]]

---

## Bullet 4: Loopback Testbench, AXI Handshakes & Framing Error Recovery

> **Resume Statement:**
> *"Built loopback testbench with random delays for transfer of data in ModelSim and validated AXI handshake mechanism along with error recovery from framing errors."*

### Hardware Requirements & Testbench Architecture
1. **Loopback Mechanism**:
   - Software-selectable loopback mode in `UART_CTRL[2]`: routes `uart_tx_out` directly to `uart_rx_in` internally.
   - External loopback test: testbench connects external pin `txd` to `rxd`.
2. **Randomized AXI Delays**:
   - Testbench master introduces pseudo-random delays (0 to 10 cycles) between `AWVALID` and `WVALID`.
   - Random wait states on `BREADY` and `RREADY` to stress slave backpressure handling.
3. **Framing Error Injection & Recovery**:
   - Testbench corrupts the stop bit by forcing line low (`0`) during the stop bit window.
   - Peripheral asserts `STAT[5]` (`FRAMING_ERR`) and triggers interrupt.
   - Verification confirms the RX FSM does not lock up, discards/flags bad frame, and successfully recovers synchronization on the next valid frame.
4. **ModelSim Automation**: Complete `run_sim.do` script for automated compilation, execution, and regression reporting.

### Verification Coverage
- 1000+ random-packet loopback test with zero data corruption.
- Framing error flag assertion and W1C clearance.
- Recovery sequence verification: valid packet sent immediately after framing error is correctly received.

### Relevant Vault Notes
- [[03_Error_Detection_&_Recovery]]
- [[01_Verification_Plan_&_Coverage_Goals]]
- [[02_AXI4_Lite_Master_BFM_&_Test_Scenarios]]
- [[03_Loopback_Testing_&_Framing_Error_Injection]]
- [[04_ModelSim_Simulation_&_DO_Scripts]]
- [[01_Resume_Deep_Dive_&_Interview_Questions]]
