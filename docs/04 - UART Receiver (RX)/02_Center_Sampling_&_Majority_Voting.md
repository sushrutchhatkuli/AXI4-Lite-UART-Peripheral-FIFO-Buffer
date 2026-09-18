---
title: "Center Sampling & Majority Voting"
tags:
  - uart
  - center-sampling
  - signal-integrity
  - noise-rejection
  - oversampling
date: 2026-09-18
status: active
---

# Center Sampling & Majority Voting

Asynchronous serial communication takes place over transmission media subject to parasitic capacitance, line inductance, electromagnetic interference (EMI), and ground bounce. This note examines the theory and mathematical justification for **center sampling** and **majority voting**.

---

## 1. Why Center Sampling? The "Eye Diagram" Margin

In any real digital channel, signal edges are not instantaneous step functions; they exhibit finite rise and fall times ($\tau = RC$). Furthermore, clock jitter and frequency tolerance between transmitter and receiver cause the relative phase to drift.

```
       Bit Boundary               Center (Ideal)             Bit Boundary
       |                          |                          |
       |     /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\     |
       |    /                                           \    |
       |---<                 EYE OPENING                 >---|
       |    \                                           /    |
       |     \_________________________________________/     |
       |                                                     |
       +--------------------------+--------------------------+
       Tick 0                  Tick 7                     Tick 15
```

### Margin Calculation
With a 16X oversampling clock:
- A full bit window spans 16 ticks: $t \in [0, 15]$.
- Edge transitions occur near **Tick 0** and **Tick 15**.
- **Tick 7** represents the exact temporal midpoint ($t = 0.5 \times T_{\text{bit}}$).
- Sampling at Tick 7 provides a symmetrical **$\pm 7$ tick ($\pm 43.75\%$) timing margin** on both sides of the sample point, maximizing immunity against both early and late phase jitter!

---

## 2. 3-Sample Majority Voting Technique

While single-point center sampling at Tick 7 provides excellent phase margin, an ultra-fast high-frequency spike (such as an ESD impulse or switching transient) occurring precisely at Tick 7 could cause a bit flip.

To counter this, high-reliability receivers implement **3-sample majority voting** around the center:
- Sample the line at **Tick 6**, **Tick 7**, and **Tick 8**.
- Apply Boolean majority voting:

$$Y = (S_6 \land S_7) \lor (S_7 \land S_8) \lor (S_6 \land S_8)$$

### Truth Table for 3-Sample Majority Voting

| $S_6$ | $S_7$ | $S_8$ | Majority Output $Y$ | Condition |
| :---: | :---: | :---: | :---: | :--- |
| `0` | `0` | `0` | **`0`** | Clean zero |
| `0` | `0` | `1` | **`0`** | Filtered positive noise spike at tick 8 |
| `0` | `1` | `0` | **`0`** | Filtered positive noise spike at center tick 7 |
| `0` | `1` | `1` | **`1`** | Valid one (early transition filtered) |
| `1` | `0` | `0` | **`0`** | Valid zero (late transition filtered) |
| `1` | `0` | `1` | **`1`** | Filtered negative noise spike at center tick 7 |
| `1` | `1` | `0` | **`1`** | Valid one (late transition filtered) |
| `1` | `1` | `1` | **`1`** | Clean one |

### Synthesizable Majority Voting Logic
```systemverilog
logic sample_6, sample_7, sample_8;
logic voted_bit;

always_ff @(posedge clk) begin
    if (baud_16x_tick) begin
        if (tick_cnt == 4'd6) sample_6 <= rx_sync1;
        if (tick_cnt == 4'd7) sample_7 <= rx_sync1;
        if (tick_cnt == 4'd8) sample_8 <= rx_sync1;
    end
end

assign voted_bit = (sample_6 & sample_7) | (sample_7 & sample_8) | (sample_6 & sample_8);
```

---

## 3. Comparison: Single Center Sample vs 3-Sample Majority

| Attribute | Single Center Sample (Tick 7) | 3-Sample Majority Voting (Ticks 6, 7, 8) |
| :--- | :--- | :--- |
| **Logic Utilization** | Minimal (1 flip-flop per bit) | Slightly higher (+2 sampling registers + LUT3) |
| **Random Spike Rejection** | Moderate (single spike flips sample) | **Superior** (any isolated 1-tick spike is rejected) |
| **Baud Mismatch Tolerance** | Full $\pm 43.75\%$ window | $\pm 37.5\%$ window (since ticks 6 and 8 must also be stable) |
| **Implementation Complexity**| Very Low | Low |

Our peripheral adopts **Center Sampling at Tick 7** with start-bit glitch qualification as the primary architecture, with majority voting available as a parameterizable enhancement.

[[03_Error_Detection_&_Recovery|Next: Error Detection & Recovery ->]]
