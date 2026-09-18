---
title: "Interrupt Architecture & Status Reporting"
tags:
  - interrupts
  - status
  - w1c
  - software-interface
date: 2026-09-18
status: active
---

# Interrupt Architecture & Status Reporting

Interrupts provide real-time notification to the host processor, eliminating the need for CPU polling loops and freeing host compute cycles.

---

## 1. Interrupt Generation Matrix

Our UART peripheral aggregates four hardware interrupt sources:

| Source | Mask Bit (`INTR_EN`) | Status Bit (`INTR_STAT`) | Trigger Condition | Rationale |
| :--- | :---: | :---: | :--- | :--- |
| **`TX_EMPTY`** | `Bit 0` | `Bit 0` | TX FIFO transitions from non-empty to empty | Alerts CPU driver to load the next block of bytes |
| **`RX_READY`** | `Bit 1` | `Bit 1` | RX FIFO transitions from empty to non-empty (`count > 0`)| Alerts CPU driver to read incoming bytes |
| **`FRAMING_ERR`**| `Bit 2` | `Bit 2` | Stop bit sampled as 0 during reception | Alerts CPU to link noise or baud mismatch |
| **`OVERRUN_ERR`**| `Bit 3` | `Bit 3` | Received byte dropped due to full RX FIFO | Alerts CPU of packet loss due to software latency |

---

## 2. Global Interrupt Gating

The top-level `uart_irq` line is an active-high level interrupt computed as:

$$\text{uart\_irq} = \text{CTRL}[3] \land \left( \bigvee_{i=0}^{3} (\text{INTR\_STAT}[i] \land \text{INTR\_EN}[i]) \right)$$

```
     INTR_STAT[0] (TX_EMPTY)   ---[ AND ]----+
     INTR_EN[0]               ---/           |
                                             |
     INTR_STAT[1] (RX_READY)   ---[ AND ]----+
     INTR_EN[1]               ---/           |
                                             +---[ OR ]---[ AND ]---> uart_irq
     INTR_STAT[2] (FRAME_ERR)  ---[ AND ]----+              |
     INTR_EN[2]               ---/           |              |
                                             |     CTRL[3] -+
     INTR_STAT[3] (OVERRUN)    ---[ AND ]----+   (Global En)
     INTR_EN[3]               ---/
```

---

## 3. The Write-1-to-Clear (W1C) Architecture

### Why NOT Read-to-Clear (RTC)?
In legacy peripheral designs, reading a status register automatically cleared its contents. This introduces a fatal **hardware-software race condition**:
1. An interrupt occurs for `RX_READY`.
2. The CPU enters the Interrupt Service Routine (ISR) and reads `STATUS`.
3. Exactly while the read is being decoded, a `FRAMING_ERR` occurs.
4. The automatic clear wipes out both `RX_READY` AND `FRAMING_ERR`!
5. The framing error event is completely lost by software.

### W1C Mechanism
In Write-1-to-Clear:
- Writing a `0` to a bit leaves it unchanged.
- Writing a `1` to a bit clears that specific bit to `0`.
- New events occurring simultaneously are captured with atomic priority:

```systemverilog
// Synthesizable W1C logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        intr_stat_reg <= 4'b0000;
    end else begin
        // Set new hardware event flags, while clearing bits written as 1 by AXI
        for (int i = 0; i < 4; i++) begin
            if (hw_event_trigger[i]) begin
                intr_stat_reg[i] <= 1'b1; // Hardware set takes priority
            end else if (axi_write_intr_stat && wstrb[0] && wdata[i]) begin
                intr_stat_reg[i] <= 1'b0; // Software W1C clear
            end
        end
    end
end
```

[[01_Verification_Plan_&_Coverage_Goals|Next: Verification Plan & Coverage Goals ->]]
