---
title: "Baud Rate Generator & 16X Oversampling Math"
tags:
  - baud-rate
  - clocking
  - math
  - oversampling
  - timing
date: 2026-09-18
status: active
---

# Baud Rate Generator & 16X Oversampling Math

In asynchronous serial communication, there is no shared clock line transmitted alongside the data wire. The receiver must locally reconstruct the bit timing using an oversampling clock. This note details the mathematical foundation, error budget analysis, and hardware architecture of our **16X Oversampling Baud Rate Generator**.

---

## 1. Fundamental Timing Relationships

Let:
- $f_{\text{clk}}$ = System master clock frequency (e.g., $100\text{ MHz} = 100 \times 10^6\text{ Hz}$).
- $B$ = Target baud rate in symbols per second (bps).
- $T_{\text{bit}}$ = Duration of a single serial bit:
  $$T_{\text{bit}} = \frac{1}{B}$$
- $T_{\text{sample}}$ = Duration of a single 16X oversampling period:
  $$T_{\text{sample}} = \frac{T_{\text{bit}}}{16} = \frac{1}{16 \times B}$$

To generate a pulse every $T_{\text{sample}}$ cycles from a clock running at $f_{\text{clk}}$, the master clock counter must count from $0$ up to a programmable integer divisor $\text{DIVISOR}$:

$$\text{DIVISOR} = \left\lfloor \frac{f_{\text{clk}}}{16 \times B} + 0.5 \right\rfloor - 1 = \text{round}\left(\frac{f_{\text{clk}}}{16 \times B}\right) - 1$$

The $+1$ term accounts for the $0$-indexed nature of hardware down-counters ($0$ to $N$ has $N+1$ clock cycles).

---

## 2. Actual Baud Rate & Percentage Error Formula

Because the divisor in digital hardware is strictly an integer, the actual synthesized baud rate deviates slightly from the theoretical nominal baud rate:

$$\text{Actual Baud Rate } (B_{\text{actual}}) = \frac{f_{\text{clk}}}{16 \times (\text{DIVISOR} + 1)}$$

The percentage error is defined as:

$$\text{Error } (\%) = \left( \frac{B_{\text{actual}} - B_{\text{nominal}}}{B_{\text{nominal}}} \right) \times 100\%$$

---

## 3. Baud Rate Precision Table ($f_{\text{clk}} = 100\text{ MHz}$)

Here is the exact calculation for a $100\text{ MHz}$ system clock across industry-standard baud rates:

| Nominal Baud | Exact Ratio $\frac{100\text{M}}{16 \times B}$ | Rounded Divisor | Hex Value | Actual Baud ($B_{\text{actual}}$) | Frequency Error (%) | Status |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **9,600** | 651.0417 | **650** | `0x028A` | 9,600.61 | **+0.0064%** | Excellent |
| **19,200** | 325.5208 | **325** | `0x0145` | 19,201.23 | **+0.0064%** | Excellent |
| **38,400** | 162.7604 | **162** | `0x00A2` | 38,402.46 | **+0.0064%** | Excellent |
| **57,600** | 108.5069 | **108** | `0x006C` | 57,339.45 | **-0.4523%** | Passed (< 2%) |
| **115,200** | 54.2535 | **53** | `0x0035` | 115,740.74 | **+0.4694%** | Passed (< 2%) |
| **230,400** | 27.1267 | **26** | `0x001A` | 231,481.48 | **+0.4694%** | Passed (< 2%) |
| **460,800** | 13.5634 | **13** | `0x000D` | 446,428.57 | **-3.1188%** | Marginal |
| **921,600** | 6.7817 | **6** | `0x0006` | 892,857.14 | **-3.1188%** | Marginal |

> [!NOTE]
> For standard UART communication (115,200 baud), the error is only **+0.47%**, which easily satisfies the asynchronous UART tolerance threshold!

---

## 4. Baud Rate Precision Table ($f_{\text{clk}} = 50\text{ MHz}$)

| Nominal Baud | Exact Ratio $\frac{50\text{M}}{16 \times B}$ | Rounded Divisor | Hex Value | Actual Baud ($B_{\text{actual}}$) | Frequency Error (%) | Status |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **9,600** | 325.5208 | **325** | `0x0145` | 9,600.61 | **+0.0064%** | Excellent |
| **19,200** | 162.7604 | **162** | `0x00A2` | 19,201.23 | **+0.0064%** | Excellent |
| **38,400** | 81.3802 | **80** | `0x0050` | 38,580.25 | **+0.4694%** | Excellent |
| **57,600** | 54.2535 | **53** | `0x0035` | 57,870.37 | **+0.4694%** | Excellent |
| **115,200** | 27.1267 | **26** | `0x001A` | 115,740.74 | **+0.4694%** | Excellent |

---

## 5. Maximum Allowable Baud Rate Error Budget

Why is $\pm 3.75\%$ the theoretical hard limit for UART?

In an 8-N-1 frame:
- Total bits = 1 Start + 8 Data + 1 Stop = **10 bits**.
- Center sampling occurs halfway through each bit window (at bit offset $0.5$).
- The furthest bit sampled is the **Stop Bit**, which occurs at:
  $$t_{\text{sample\_stop}} = (9 + 0.5) \times T_{\text{bit}} = 9.5 \times T_{\text{bit}}$$
- For the receiver to correctly sample the stop bit, the cumulative clock drift over $9.5$ bit periods must not exceed half a bit period ($\pm 0.5 \times T_{\text{bit}}$). Otherwise, the sample point drifts into the adjacent bit!

$$\text{Drift}_{\text{max}} = \frac{\pm 0.5 \times T_{\text{bit}}}{9.5 \times T_{\text{bit}}} \approx \pm 5.26\%$$

Subtracting margins for signal rise/fall time slew rates, duty cycle distortion, and cable capacitance yields an industry standard maximum allowable mismatch of **$\pm 2.0\%$ to $\pm 3.75\%$**.
Our design achieves **$0.47\%$** at 115,200 baud, leaving ample safety margin!

---

## 6. Synthesizable Baud Rate Generator Module (RTL)

```systemverilog
module uart_baud_gen #(
    parameter int DEFAULT_DIVISOR = 53 // 100MHz / (16 * 115200) - 1
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] baud_div_val,
    output logic        baud_16x_tick   // Single-cycle strobe every 1/16th bit
);
    logic [15:0] count_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg     <= '0;
            baud_16x_tick <= 1'b0;
        end else begin
            if (count_reg >= baud_div_val) begin
                count_reg     <= '0;
                baud_16x_tick <= 1'b1;  // Single-cycle tick
            end else begin
                count_reg     <= count_reg + 1'b1;
                baud_16x_tick <= 1'b0;
            end
        end
    end
endmodule
```

[[02_Clock_Domain_&_Metastability_CDC|Next: Clock Domain Crossing & Metastability Resolution ->]]
