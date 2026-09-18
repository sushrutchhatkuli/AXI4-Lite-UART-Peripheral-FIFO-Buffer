---
title: "TX Timing & Handshaking"
tags:
  - uart
  - tx
  - timing
  - waveforms
  - throughput
date: 2026-09-18
status: active
---

# TX Timing & Handshaking

This note details the timing interactions between the AXI-accessible TX FIFO and the UART TX serializing engine, including back-to-back throughput math and handshake waveform analysis.

---

## 1. FIFO Pop Handshake Timing

The TX Engine pops data from the FIFO synchronously with the system clock `clk`:
1. `tx_empty` is sampled.
2. If `!tx_empty && tx_en`: `tx_pop` is pulsed HIGH for exactly 1 clock cycle.
3. Simultaneously, `tx_data[7:0]` on the FIFO output bus is registered into `shift_reg`.
4. The FIFO updates its internal read pointer on the rising edge of `clk`, presenting the next byte (if available) on the following cycle.

```
       CLK         __    __    __    __    __    __    __    __
                __|  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__
       TX_EMPTY ‾‾‾‾‾‾\________________________________________
       TX_POP   ____________/‾‾‾‾‾\____________________________
       TX_DATA  XXXXXXXXXXXX< 0xA5 >XXXXXXXXXXXXXXXXXXXXXXXXXXX
       STATE    [ IDLE      ][ START (16 ticks)                ]
       TX_OUT   ‾‾‾‾‾‾‾‾‾‾‾‾\__________________________________
```

---

## 2. Baud Tick Accumulation & Zero Phase Error

Because `baud_16x_tick` pulses once every $\text{DIVISOR} + 1$ clock cycles:
- Each bit consists of exactly 16 `baud_16x_tick` pulses ($0 \dots 15$).
- Because the TX state machine transitions strictly on the coincident edge of `baud_16x_tick && tick_cnt == 15`, bit durations are locked directly to the baud generator divisor.
- There is **zero accumulated phase drift** between bits within a frame: every bit duration is mathematically identical ($16 \times (\text{DIVISOR} + 1)$ clock periods).

---

## 3. Back-to-Back Transmission & Line Efficiency

In maximum-throughput burst streaming (e.g. DMA transfers or software loading a burst into the TX FIFO):
- When the TX FSM reaches tick 15 of `ST_STOP`, it evaluates `!tx_empty`.
- If another byte is available, the FSM transitions directly to `ST_START` without entering `ST_IDLE`.
- As a result, the stop bit is exactly 1 bit long, and the start bit of the subsequent frame begins immediately on the very next clock cycle.

### Throughput Calculations

At 115,200 baud, 8-N-1:
- Bits per frame: $1 \text{ (start)} + 8 \text{ (data)} + 1 \text{ (stop)} = 10 \text{ bits}$.
- Byte transmission duration:
  $$T_{\text{frame}} = \frac{10}{115,200} \approx 86.805\ \mu\text{s}$$
- Maximum sustained byte throughput:
  $$\text{Throughput} = \frac{115,200}{10} = 11,520\ \text{Bytes/second} \approx 11.25\ \text{KB/s}$$
- Wire protocol efficiency:
  $$\text{Efficiency} = \frac{8\ \text{data bits}}{10\ \text{total bits}} = 80.0\%$$

[[01_UART_RX_Architecture_&_FSM|Next: UART Receiver (RX) Architecture & FSM ->]]
