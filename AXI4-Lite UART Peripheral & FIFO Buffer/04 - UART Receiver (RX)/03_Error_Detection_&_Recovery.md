---
title: "Error Detection & Recovery"
tags:
  - uart
  - errors
  - framing-error
  - overrun-error
  - recovery
  - fault-tolerance
date: 2026-09-18
status: active
---

# Error Detection & Recovery Mechanisms

Serial links operate in noisy environments where cables can be disconnected, noise can corrupt bits, or software can fail to read data fast enough. This note documents the detection, reporting, and recovery mechanisms for **Framing Errors** and **Overrun Errors**.

---

## 1. Framing Error (`FRAMING_ERR`)

### What is a Framing Error?
A framing error occurs when the receiver deserializes a byte and samples the **Stop Bit** as logic `0` instead of the expected logic `1` (Mark).

```
                      Start   D0    D1    D2    D3    D4    D5    D6    D7   Stop (CORRUPT)
       Line:  ---1---+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
                     |  0  |  .  |  .  |  .  |  .  |  .  |  .  |  .  |  .  |  0  | <--- Expected 1!
                     +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
                                                                           ^ Sampled 0: FRAMING ERROR!
```

### Root Causes
1. **Baud Rate Mismatch**: If the TX and RX baud generators differ by $> 4\%$, the accumulated phase error shifts the stop bit sample point into an adjacent bit.
2. **Break Condition**: A prolonged low on the serial line (e.g. cable disconnected, or transmitter asserting a serial BREAK).
3. **Severe Line Glitch**: Electrical noise forcing the line low during the stop bit window.

### Hardware Detection & Status Flag
- At Tick 7 of `ST_STOP`:
  ```systemverilog
  if (rx_sync1 == 1'b0) begin
      framing_err_reg <= 1'b1;
      intr_stat_reg[2] <= 1'b1; // Trigger interrupt
  end
  ```
- **FIFO Protection**: The corrupted byte is discarded and NOT pushed into the RX FIFO, ensuring software never processes corrupted data.

### Safe Recovery Sequence: Avoiding Cascading False Starts
If the receiver simply jumped back to `RX_IDLE` while the line was still low (`0`), the edge detector would immediately interpret the ongoing low level as another falling edge or start bit, triggering a cascade of false framing errors!

Our receiver implements a dedicated recovery state: **`ST_ERR_WAIT`**:
```systemverilog
ST_ERR_WAIT: begin
    // Hold receiver until line returns to idle Mark (logic 1)
    if (rx_sync1 == 1'b1) begin
        state_reg <= ST_IDLE; // Safely re-armed for the next genuine start bit
    end
end
```

---

## 2. Overrun Error (`OVERRUN_ERR`)

### What is an Overrun Error?
An overrun error occurs when a newly received byte arrives, but the **RX FIFO is already full** (`rx_count == 16`).

```
       Incoming Valid Byte  ---> [ UART RX SIPO ]
                                       |
                                       v (Attempt Push)
       +--------------------------------------------------------+
       | RX FIFO [ FULL: 16 / 16 Bytes Occupied ]               |
       +--------------------------------------------------------+
                                       |
                                 BLOCKED! Byte Dropped!
                                 Assert STAT[6] (OVERRUN_ERR)
```

### Hardware Policy: Drop New Byte (Protect Existing Data)
- We adopt the standard networking policy: **Preserve existing FIFO contents; drop incoming byte**.
- The `OVERRUN_ERR` flag in `UART_STATUS[6]` and `UART_INTR_STAT[3]` is asserted.
- The flag is **sticky**: it remains set until software explicitly writes `1` to `UART_INTR_STAT[3]` (W1C), alerting the CPU driver that data loss occurred.

---

## 3. Summary of Error Actions

| Error Type | Trigger Condition | Status Bit | Interrupt Bit | Data Policy | Recovery Action |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Glitch on Start** | `sync_rx == 1` at Tick 7 of Start | None | None | Dropped immediately | Returns to `IDLE`; no error reported |
| **Framing Error** | `sync_rx == 0` at Tick 7 of Stop | `STAT[5]` | `INTR_STAT[2]`| Corrupted byte discarded | Enters `ERR_WAIT`; waits for line HIGH |
| **Overrun Error** | Byte received when RX FIFO full | `STAT[6]` | `INTR_STAT[3]`| New byte discarded; FIFO intact | Cleared by software W1C write |

[[01_Circular_FIFO_Pointer_Rollover_Theory|Next: Circular FIFO Pointer Rollover Theory ->]]
