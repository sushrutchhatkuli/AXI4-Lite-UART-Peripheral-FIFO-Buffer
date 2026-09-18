---
title: "Design Tradeoffs & Alternative Architectures"
tags:
  - tradeoffs
  - architecture
  - digital-design
  - engineering-decisions
date: 2026-09-18
status: active
---

# Design Tradeoffs & Alternative Architectures

Every engineering decision involves tradeoffs between logic area, clock frequency ($F_{\text{max}}$), latency, power, and protocol flexibility. This note documents the key architectural tradeoffs made in this project.

---

## 1. Oversampling Ratio: 16X vs 8X vs 4X

| Oversampling Factor | Sample Midpoint | Timing Margin | Max Clock Freq Required | Area / Power | Recommendation |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **16X** *(Chosen)* | **Tick 7** | **$\pm 43.75\%$** | $16 \times \text{Baud}$ ($1.84\text{MHz}$ for 115.2k) | Low | **Standard for robust serial** |
| **8X** | Tick 3 | $\pm 37.50\%$ | $8 \times \text{Baud}$ ($921.6\text{kHz}$) | Ultra-low | High-speed links ($> 3\text{Mbps}$) |
| **4X** | Tick 1 | $\pm 25.00\%$ | $4 \times \text{Baud}$ | Minimal | Fragile; high jitter sensitivity |

> **Rationale for 16X**: With a 100MHz system clock, 16X oversampling requires an integer divisor of 53, consuming minimal switching power while providing the widest possible phase jitter margin.

---

## 2. FIFO Full/Empty Architecture: Pointer Rollover vs Up/Down Counter

| Architecture | Critical Path Logic | Flip-Flop Count | Synthesis Complexity | Maximum Clock Frequency |
| :--- | :--- | :---: | :---: | :---: |
| **Pointer Rollover ($N+1$ bits)** *(Chosen)* | Single XNOR + AND gate | $2 \times 5 = 10\text{ FFs}$ | **O(1) logic depth** | **$> 350\text{ MHz}$** |
| **Up/Down Occupancy Counter** | 5-bit Adder/Subtractor + Mux | $8 + 5 = 13\text{ FFs}$ | Higher logic depth | $\sim 220\text{ MHz}$ |

> **Rationale**: Pointer rollover keeps flag generation strictly off the critical path, enabling high-frequency synthesis on low-cost FPGA speed grades.

---

## 3. Bus Protocol: AXI4-Lite vs APB4

| Feature | AXI4-Lite *(Chosen)* | APB4 |
| :--- | :--- | :--- |
| **Channel Decoupling** | **Independent Read & Write channels** | Unified multiplexed address/data phase |
| **Concurrency** | Simultaneous Read and Write possible | Strictly half-duplex (read OR write) |
| **Handshake** | 2-wire `VALID` / `READY` | 2-phase: `PSEL` + `PENABLE` with `PREADY` |
| **SoC Interconnect** | Native direct connection to AXI crossbars | Requires AXI-to-APB bridge adapter |

> **Rationale**: Direct AXI4-Lite integration eliminates interconnect bridge latency and aligns with modern ARM Cortex-A and RISC-V SoC memory subsystems.

---

## 4. Single Center Sample vs 3-Sample Majority Voting

| Technique | Hardware Cost | Single-Event Transient (SET) Immunity | Phase Offset Tolerance |
| :--- | :---: | :---: | :---: |
| **Center Sample (Tick 7)** *(Chosen)* | Minimal | Moderate | **Maximum ($\pm 43.75\%$)** |
| **3-Sample Majority (Ticks 6, 7, 8)** | +2 Registers + LUT3 | **Complete immunity to single-tick noise** | $\pm 37.5\%$ |

> **Rationale**: Start-bit glitch qualification at Tick 7 combined with 2-FF CDC provides robust protection in lab and board-level environments. Majority voting is available as a configurable parameter for high-EMI industrial environments.
