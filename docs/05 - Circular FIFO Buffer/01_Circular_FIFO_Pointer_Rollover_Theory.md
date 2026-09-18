---
title: "Circular FIFO Pointer Rollover Theory"
tags:
  - fifo
  - circular-buffer
  - pointer-rollover
  - digital-design
  - math
date: 2026-09-18
status: active
---

# Circular FIFO Pointer Rollover Theory

A First-In First-Out (FIFO) buffer is essential in serial peripheral architectures to decouple two asynchronous rates: the ultra-fast AXI system bus ($100\text{ MHz}$, delivering 32-bit words in nanoseconds) and the relatively slow serial link ($115,200\text{ baud}$, taking $\sim 86.8\ \mu\text{s}$ per byte).

This note examines the mathematical foundation of the **Pointer Rollover Method** ($N+1$ bit pointers) used in our 16-element circular FIFOs.

---

## 1. The Classical Full vs Empty Ambiguity Problem

Consider a circular buffer with depth $D = 16$.
To address 16 memory locations, we require $N = \log_2(16) = 4$ address bits:
$$\text{Address Range: } [0, 15] \implies 4\text{'b0000 to } 4\text{'b1111}$$

If we use simple 4-bit write and read pointers (`wptr[3:0]` and `rptr[3:0]`):
- At reset, `wptr = 0` and `rptr = 0`. Both point to index 0. Buffer is **EMPTY** (`wptr == rptr`).
- If 16 consecutive writes occur without any reads:
  - Write 0 writes to index 0, `wptr` becomes 1.
  - ...
  - Write 15 writes to index 15, `wptr` wraps around from 15 (`4'b1111`) to 0 (`4'b0000`).
  - Now `wptr == 0` and `rptr == 0`!
- **The Ambiguity**: Both `wptr == rptr` when the FIFO is completely EMPTY and when it is completely FULL!

---

## 2. The $(N+1)$-Bit Pointer Rollover Solution

Instead of maintaining a separate up/down occupancy counter (which adds combinational logic and creates timing bottlenecks on the critical path), we extend the pointer width by **one extra bit** ($N+1 = 5$ bits):

$$\text{Pointer Width} = \log_2(D) + 1 = 4 + 1 = 5\text{ bits}$$

### Bit Allocations
For any pointer `ptr[4:0]`:
- `ptr[3:0]`: The **4-bit memory address** used directly to index the 16-word RAM (`0` to `15`).
- `ptr[4]`: The **rollover phase bit (MSB)**, indicating how many times the pointer has wrapped around the buffer ($0$ or $1$).

```
       5-bit Pointer:
       +----+----+----+----+----+
       | B4 | B3 | B2 | B1 | B0 |
       +----+----+----+----+----+
         |   \_________________/
         |            |
       MSB       4-bit RAM Address
     (Rollover)     (0 to 15)
```

---

## 3. Empty, Full, and Occupancy Conditions

### Condition 1: EMPTY
The FIFO is empty if and only if the write pointer and read pointer are **completely identical across all 5 bits**:

$$\text{EMPTY} \iff \text{wptr}[4:0] == \text{rptr}[4:0]$$

*Physical meaning:* The write pointer has neither advanced past nor wrapped ahead of the read pointer.

### Condition 2: FULL
The FIFO is full if and only if the lower 4 address bits match, but the **MSBs (rollover bits) are inverted**:

$$\text{FULL} \iff (\text{wptr}[4] \ne \text{rptr}[4]) \land (\text{wptr}[3:0] == \text{rptr}[3:0])$$

*Physical meaning:* The write pointer has wrapped around the circular buffer exactly once more than the read pointer and is now pointing at the same address slot, meaning all 16 locations are occupied!

### Condition 3: Occupancy Count
The instantaneous number of valid elements (from $0$ to $16$) is given by natural 5-bit unsigned subtraction:

$$\text{COUNT}[4:0] = \text{wptr}[4:0] - \text{rptr}[4:0]$$

Because two's complement modulo arithmetic wraps at $2^5 = 32$, this single subtraction produces the correct count in all cases, even when `wptr` has rolled over ($wptr[4] = 1$) and `rptr` has not ($rptr[4] = 0$).

---

## 4. State Progression Walkthrough (16 Steps)

| Step | Action | `wptr[4:0]` | `rptr[4:0]` | `waddr` | `raddr` | `wptr == rptr` | `wptr[4] != rptr[4] && waddr == raddr` | Status | Count |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| 0 | Reset | `5'b00000` | `5'b00000` | `0` | `0` | **TRUE** | FALSE | **EMPTY** | 0 |
| 1 | Push 1 byte | `5'b00001` | `5'b00000` | `1` | `0` | FALSE | FALSE | Normal | 1 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 15 | Push byte 15| `5'b01111` | `5'b00000` | `15` | `0` | FALSE | FALSE | Normal | 15 |
| 16 | Push byte 16| `5'b10000` | `5'b00000` | `0` | `0` | FALSE | **TRUE** | **FULL** | 16 |
| 17 | Pop 1 byte | `5'b10000` | `5'b00001` | `0` | `1` | FALSE | FALSE | Normal | 15 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 31 | Pop 15 bytes| `5'b10000` | `5'b01111` | `0` | `15` | FALSE | FALSE | Normal | 1 |
| 32 | Pop byte 16 | `5'b10000` | `5'b10000` | `0` | `0` | **TRUE** | FALSE | **EMPTY** | 0 |

Notice that at Step 32, both MSBs are `1` and addresses are `0`, cleanly recognizing **EMPTY** again!

[[02_FIFO_Hardware_Implementation_&_Flags|Next: FIFO Hardware Implementation & Flags ->]]
