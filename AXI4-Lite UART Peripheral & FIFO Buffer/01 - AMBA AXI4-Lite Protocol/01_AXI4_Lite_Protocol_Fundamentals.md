---
title: "AXI4-Lite Protocol Fundamentals"
tags:
  - axi4-lite
  - amba
  - protocol
  - hardware-architecture
date: 2026-09-18
status: active
---

# AXI4-Lite Protocol Fundamentals

The **Advanced Microcontroller Bus Architecture (AMBA) AXI4-Lite** specification is a subset of the full AXI4 protocol designed specifically for memory-mapped, register-based peripheral communication. It strips out complex high-bandwidth features (burst transfers, out-of-order execution, cache signals, atomic locks, simultaneous multi-beat streaming) while retaining high-frequency, decoupled, point-to-point handshaking across 5 independent channels.

---

## 1. The 5 Independent Channels

An AXI4-Lite interface consists of five distinct, unidirectional channels. Every transaction is governed by the two-wire `VALID` / `READY` handshake mechanism.

```
       +-----------------------------------------------------------+
       |                       AXI4-Lite Master                    |
       +-----------------------------------------------------------+
          |  AWADDR, AWPROT, AWVALID           ^  AWREADY
          v                                    |
       +-----------------------------------------------------------+  (1) Write Address Channel
       |                                                           |
          |  WDATA, WSTRB, WVALID              ^  WREADY
          v                                    |
       +-----------------------------------------------------------+  (2) Write Data Channel
       |                                                           |
          ^  BRESP, BVALID                     |  BREADY
          |                                    v
       +-----------------------------------------------------------+  (3) Write Response Channel
       |                                                           |
          |  ARADDR, ARPROT, ARVALID           ^  ARREADY
          v                                    |
       +-----------------------------------------------------------+  (4) Read Address Channel
       |                                                           |
          ^  RDATA, RRESP, RVALID              |  RREADY
          |                                    v
       +-----------------------------------------------------------+  (5) Read Data Channel
       |                       AXI4-Lite Slave                     |
       +-----------------------------------------------------------+
```

### Channel Summary Table

| Channel | Abbr | Driven By | Key Signals | Description |
| :--- | :---: | :---: | :--- | :--- |
| **Write Address** | **AW** | Master | `AWADDR[31:0]`, `AWPROT[2:0]`, `AWVALID` (M $\to$ S), `AWREADY` (S $\to$ M) | Delivers target write register address |
| **Write Data** | **W** | Master | `WDATA[31:0]`, `WSTRB[3:0]`, `WVALID` (M $\to$ S), `WREADY` (S $\to$ M) | Delivers payload data and active byte lanes |
| **Write Response** | **B** | Slave | `BRESP[1:0]`, `BVALID` (S $\to$ M), `BREADY` (M $\to$ S) | Returns write completion status (OKAY/SLVERR) |
| **Read Address** | **AR** | Master | `ARADDR[31:0]`, `ARPROT[2:0]`, `ARVALID` (M $\to$ S), `ARREADY` (S $\to$ M) | Delivers target read register address |
| **Read Data** | **R** | Slave | `RDATA[31:0]`, `RRESP[1:0]`, `RVALID` (S $\to$ M), `RREADY` (M $\to$ S) | Delivers read payload data & status to master |

---

## 2. Handshake Semantics & The "Golden Rules"

The two-wire handshake is the heartbeat of AMBA interfaces:
- **`VALID`**: Asserted by the source to indicate that control information or data is stable and valid.
- **`READY`**: Asserted by the destination to indicate that it can accept data on this cycle.
- **Transfer Occurs**: An information transfer takes place strictly on the rising edge of `ACLK` when **both `VALID` AND `READY` are HIGH** (`VALID && READY == 1'b1`).

### Rule 1: No Glitching or Premature De-assertion
> **AMBA Spec Requirement:** Once a source asserts `VALID`, it **MUST** remain asserted until the handshake occurs (`READY` is HIGH on a rising edge). The source cannot pull `VALID` LOW if `READY` is LOW.

### Rule 2: Valid Must Not Wait for Ready (Deadlock Avoidance)
> **AMBA Spec Requirement:** A source **MUST NOT** wait for `READY` to be asserted before asserting `VALID`. Doing so creates circular wait dependencies that lock the bus.
> Conversely, a destination is permitted to wait for `VALID` before asserting `READY`, or it may assert `READY` default-high.

### Rule 3: Payload Stability
> When `VALID` is HIGH, all associated payload signals (`ADDR`, `DATA`, `STRB`, `PROT`, `RESP`) must remain completely stable until the handshake cycle completes.

```
       ACLK      __    __    __    __    __    __    __
              __|  \__/  \__/  \__/  \__/  \__/  \__/  \__
       VALID  ________/===========================\_______
       READY  _______________________/============\_______
       DATA   XXXXXXXX<   VALID DATA              >XXXXXXX
                                     ^ Transfer Cycle
```

---

## 3. AXI4-Lite Constraints vs Full AXI4

AXI4-Lite simplifies full AXI4 by imposing strict architectural limits:
1. **Burst Length = 1**: Every transaction is strictly a single 32-bit beat (`AWLEN = 0`, `ARLEN = 0`). No wrapping, incremental, or fixed bursts.
2. **Fixed Data Bus Width**: Data buses are strictly 32-bit or 64-bit (our design uses standard 32-bit).
3. **No Burst Size Manipulation**: `AWSIZE` / `ARSIZE` are locked to `3'b010` (4 bytes = 32 bits).
4. **No Out-of-Order Execution**: No transaction IDs (`AWID`, `BID`, `ARID`, `RID`). All transactions are strictly in-order.
5. **No Atomic or Exclusive Access**: No `AWLOCK` / `ARLOCK`.
6. **No Cache Attributes**: No `AWCACHE` / `ARCACHE`.

---

## 4. Response Codes (`BRESP` and `RRESP`)

Both read and write channels return a 2-bit response code indicating transaction outcome:

| Code `[1:0]` | Name | Meaning | Behavior in our UART Core |
| :---: | :--- | :--- | :--- |
| `2'b00` | **OKAY** | Normal access successful | Returned for all valid reads/writes to mapped registers (`0x00` - `0x18`) |
| `2'b01` | **EXOKAY** | Exclusive access OK | Not supported in AXI4-Lite (illegal) |
| `2'b10` | **SLVERR** | Slave Error | Returned when accessing unmapped addresses (e.g. `0x1C`+) or unaligned access |
| `2'b11` | **DECERR** | Decode Error | Typically generated by system interconnect when no slave exists at that address |

---

## 5. Decoupled Write Phase Relationships

A critical feature of AXI is that the **Write Address (`AW`)** and **Write Data (`W`)** channels are independent. Three valid temporal relationships can occur:

1. **Simultaneous Arrival**: Both `AWVALID` and `WVALID` assert on the exact same clock cycle.
2. **Address First**: `AWVALID` asserts 1 or more cycles before `WVALID`.
3. **Data First**: `WVALID` asserts 1 or more cycles before `AWVALID`.

A robust slave must buffer whichever arrives first, wait for the second partner, execute the internal register write, and subsequently assert `BVALID` to complete the transaction.

```
Scenario A (Simultaneous):
AWVALID: ___|‾‾‾|___
WVALID:  ___|‾‾‾|___
Handshake on cycle 1!

Scenario B (Address First):
AWVALID: ___|‾‾‾|_________________
WVALID:  ___________|‾‾‾|_________
Slave latches address, waits for data.

Scenario C (Data First):
WVALID:  ___|‾‾‾|_________________
AWVALID: ___________|‾‾‾|_________
Slave latches data & wstrb, waits for address.
```

[[02_AXI4_Lite_Slave_Interface_Architecture|Next: Explore the AXI4-Lite Slave Interface Architecture & FSM Design ->]]
