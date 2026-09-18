---
title: "Register Map Specification"
tags:
  - registers
  - memory-map
  - axi4-lite
  - software-interface
date: 2026-09-18
status: active
---

# Complete Register Map Specification

All registers are memory-mapped to 32-bit aligned offsets. Any access to offsets outside `0x00` through `0x18` triggers an `SLVERR` response.

---

## 1. Register Address Map

| Offset | Register Name | Access | Reset Value | Description |
| :---: | :--- | :---: | :---: | :--- |
| **`0x00`** | **`UART_DATA`** | R/W | `0x00000000` | Transmit Write Data (W) / Receive Read Data (R) |
| **`0x04`** | **`UART_STATUS`** | RO | `0x0000000A` | Operational flags, FIFO status, and error indicators |
| **`0x08`** | **`UART_CTRL`** | RW | `0x00000003` | Enable controls (TX_EN, RX_EN, LOOPBACK, INTR_EN) |
| **`0x0C`** | **`UART_BAUD_DIV`**| RW | `0x00000035` | 16-bit divisor value for 16X oversampling clock |
| **`0x10`** | **`UART_FIFO_CNT`** | RO | `0x00000000` | Live occupancy count of TX and RX FIFOs |
| **`0x14`** | **`UART_INTR_STAT`**| W1C | `0x00000000` | Interrupt status flags (Write 1 to clear) |
| **`0x18`** | **`UART_INTR_EN`** | RW | `0x00000000` | Interrupt enable mask register |

---

## 2. Register Bitfield Definitions

### Offset `0x00`: `UART_DATA` (Data Register)
- **Write Access**: Pushes `WDATA[7:0]` into the **TX FIFO**.
  - If TX FIFO is FULL, the write is ignored and `STAT[6]` (`OVERRUN_ERR`) is asserted.
- **Read Access**: Pops the oldest available byte from the **RX FIFO** and returns it on `RDATA[7:0]`.
  - If RX FIFO is EMPTY, read returns `0x00` with no FIFO state change.

```
 31                                                  8 7        0
+-----------------------------------------------------+----------+
|                     RESERVED (0)                    |   DATA   |
+-----------------------------------------------------+----------+
```

| Bits | Field | Access | Reset | Description |
| :---: | :--- | :---: | :---: | :--- |
| `[7:0]` | `DATA` | R/W | `0x00` | Transmit data (write) / Receive data (read). |
| `[31:8]`| `RESERVED` | RO | `0x000000` | Reads return 0; writes ignored. |

---

### Offset `0x04`: `UART_STATUS` (Status Register)
Read-only register exposing real-time peripheral state.

```
 31                                       8  7   6   5   4   3   2   1   0
+------------------------------------------+---+---+---+---+---+---+---+---+
|               RESERVED                   |RB |TB |OF |FE |RF |RE |TF |TE |
+------------------------------------------+---+---+---+---+---+---+---+---+
```

| Bit | Name | Access | Reset | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0` | **`TX_EMPTY`** | RO | `1'b1` | 1 = TX FIFO is completely empty (ready for data). |
| `1` | **`TX_FULL`** | RO | `1'b0` | 1 = TX FIFO is completely full (16 bytes held). |
| `2` | **`RX_EMPTY`** | RO | `1'b1` | 1 = RX FIFO is completely empty (no data to read). |
| `3` | **`RX_FULL`** | RO | `1'b0` | 1 = RX FIFO is completely full (16 bytes held). |
| `4` | **`RX_DATA_READY`**| RO | `1'b0` | 1 = At least one valid byte is waiting in RX FIFO (`!RX_EMPTY`). |
| `5` | **`FRAMING_ERR`** | RO | `1'b0` | 1 = Stop bit sampled as 0 (framing violation). Sticky until cleared via `INTR_STAT`. |
| `6` | **`OVERRUN_ERR`** | RO | `1'b0` | 1 = New byte received or written when FIFO was full. |
| `7` | **`TX_BUSY`** | RO | `1'b0` | 1 = UART TX serializer is actively transmitting a frame. |
| `8` | **`RX_BUSY`** | RO | `1'b0` | 1 = UART RX deserializer is actively receiving a frame. |
| `[31:9]`| `RESERVED` | RO | `0x000000` | Reserved. |

---

### Offset `0x08`: `UART_CTRL` (Control Register)
Software control and peripheral configuration.

```
 31                                                    4   3   2   1   0
+-------------------------------------------------------+---+---+---+---+
|                      RESERVED                         |IE |LP |RE |TE |
+-------------------------------------------------------+---+---+---+---+
```

| Bit | Name | Access | Reset | Description |
| :---: | :--- | :---: | :---: | :--- |
| `0` | **`TX_EN`** | RW | `1'b1` | 1 = Enables UART transmitter engine; 0 = Disables TX. |
| `1` | **`RX_EN`** | RW | `1'b1` | 1 = Enables UART receiver engine; 0 = Disables RX. |
| `2` | **`LOOPBACK_EN`**| RW | `1'b0` | 1 = Internal digital loopback enabled (`tx_out` routed to `rx_in`). |
| `3` | **`INTR_GLOBAL_EN`**| RW | `1'b0` | Master interrupt enable bit. |
| `[31:4]`| `RESERVED` | RO | `0x0000000` | Reserved. |

---

### Offset `0x0C`: `UART_BAUD_DIV` (Baud Rate Divisor Register)
Configures the 16X oversampling clock divider.

```
 31                                 16 15                              0
+-------------------------------------+---------------------------------+
|              RESERVED               |            BAUD_DIV             |
+-------------------------------------+---------------------------------+
```

| Bits | Field | Access | Reset | Description |
| :---: | :--- | :---: | :---: | :--- |
| `[15:0]`| `BAUD_DIV` | RW | `16'd53` | 16-bit integer divider: $\text{DIV} = \frac{f_{\text{clk}}}{16 \times \text{Baud}} - 1$. Default `53` gives 115,200 baud @ 100MHz. |
| `[31:16]`| `RESERVED` | RO | `16'h0000` | Reserved. |

---

### Offset `0x10`: `UART_FIFO_CNT` (FIFO Occupancy Count Register)
Exposes the exact number of words (0 to 16) currently stored in both FIFOs.

```
 31                                    13 12       8 7        5 4        0
+----------------------------------------+----------+----------+----------+
|                RESERVED                | RX_COUNT | RESERVED | TX_COUNT |
+----------------------------------------+----------+----------+----------+
```

| Bits | Field | Access | Reset | Description |
| :---: | :--- | :---: | :---: | :--- |
| `[4:0]` | `TX_COUNT` | RO | `5'b00000` | Number of unread bytes in TX FIFO (range `0` to `16`). |
| `[7:5]` | `RESERVED` | RO | `3'b000` | Reserved. |
| `[12:8]`| `RX_COUNT` | RO | `5'b00000` | Number of available bytes in RX FIFO (range `0` to `16`). |
| `[31:13]`| `RESERVED`| RO | `19'b0` | Reserved. |

---

### Offset `0x14`: `UART_INTR_STAT` (Interrupt Status - Write-1-to-Clear)
Asserted when corresponding event occurs. Writing `1` clears the bit.

| Bit | Field | Access | Description |
| :---: | :--- | :---: | :--- |
| `0` | `TX_EMPTY_INT` | W1C | Set when TX FIFO transitions to empty. |
| `1` | `RX_READY_INT` | W1C | Set when RX FIFO receives data (`!RX_EMPTY`). |
| `2` | `FRAMING_ERR_INT` | W1C | Set when framing error is detected on RX line. |
| `3` | `OVERRUN_ERR_INT` | W1C | Set when FIFO overrun occurs. |

---

### Offset `0x18`: `UART_INTR_EN` (Interrupt Enable Mask)
Active-high interrupt enable bits matching `UART_INTR_STAT`.

---

## 3. C Header Driver Definition

```c
# ifndef UART_AXI_REGS_H
# define UART_AXI_REGS_H

# include <stdint.h>

typedef struct {
    volatile uint32_t DATA;       // 0x00: Data Register
    volatile const uint32_t STAT; // 0x04: Status Register (RO)
    volatile uint32_t CTRL;       // 0x08: Control Register
    volatile uint32_t BAUD_DIV;   // 0x0C: Baud Divisor Register
    volatile const uint32_t FIFO_CNT; // 0x10: FIFO Count Register (RO)
    volatile uint32_t INTR_STAT;  // 0x14: Interrupt Status Register (W1C)
    volatile uint32_t INTR_EN;    // 0x18: Interrupt Enable Mask
} UART_Axi_Regs;

# define UART_BASE_ADDR (0x40000000)
# define UART0 ((UART_Axi_Regs *)UART_BASE_ADDR)

// Status register masks
# define UART_STAT_TX_EMPTY   (1U << 0)
# define UART_STAT_TX_FULL    (1U << 1)
# define UART_STAT_RX_EMPTY   (1U << 2)
# define UART_STAT_RX_FULL    (1U << 3)
# define UART_STAT_RX_READY   (1U << 4)
# define UART_STAT_FRAME_ERR  (1U << 5)
# define UART_STAT_OVERRUN    (1U << 6)
# define UART_STAT_TX_BUSY    (1U << 7)

# endif // UART_AXI_REGS_H
```
