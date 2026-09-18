---
title: "Resume Deep-Dive & 25+ Interview Questions"
tags:
  - interview-prep
  - resume-defense
  - hardware-interview
  - asic
  - fpga
date: 2026-09-18
status: active
---

# Resume Deep-Dive & 25+ Interview Questions

This document prepares you to defend every single word on your resume with total confidence, zero hesitation, and deep architectural mastery during hardware engineering interviews (Apple, Nvidia, Qualcomm, AMD, Intel, Google Silicon).

---

## Category 1: AXI4-Lite Protocol & Bus Architecture

### Q1: Why did you choose AXI4-Lite instead of APB for this UART peripheral?
> **Model Answer:**
> *"While APB (Advanced Peripheral Bus) is simpler and has lower gate count, AMBA AXI4-Lite provides several architectural advantages in modern SoC architectures. AXI4-Lite offers decoupled, independent read and write channels, allowing concurrent read and write operations. It also uses standardized 2-wire `VALID`/`READY` handshaking with native support for variable wait states without extra wait-state signaling logic. Connecting directly to an AXI crossbar or SmartConnect avoids having to insert an AXI-to-APB bridge, minimizing interconnect latency and simplifying the system memory map."*

### Q2: Can `AWVALID` wait for `AWREADY` to assert before asserting?
> **Model Answer:**
> *"No! The AMBA specification explicitly states that a source (master or slave outputting `VALID`) **must never wait** for `READY` before asserting `VALID`. Doing so creates a circular dependency hazard: if the destination is waiting for `VALID` to assert before driving `READY`, neither will ever assert, causing a catastrophic deadlock on the bus. However, the destination is permitted to wait for `VALID` before asserting `READY`, or it may assert `READY` default-high."*

### Q3: What happens if `WVALID` arrives 10 clock cycles before `AWVALID`? How does your slave handle it?
> **Model Answer:**
> *"AXI4-Lite allows `AW` and `W` phases to arrive in any temporal order. In my slave controller, I decoupled the address and data capture into two independent registers with tracking flags: `aw_captured` and `w_captured`. When `WVALID && WREADY` asserts first, the slave latches `WDATA` and `WSTRB` into internal registers and sets `w_captured = 1`. The slave then keeps `WREADY` low to prevent further data until `AWVALID && AWREADY` arrives. Once both flags are satisfied, the write operation is committed to the internal register file, and `BVALID` is asserted to complete the transaction."*

### Q4: What response code does your slave return when software accesses an invalid address (e.g. `0x24`), and why?
> **Model Answer:**
> *"My slave asserts `2'b10` (`SLVERR` - Slave Error) on `BRESP` or `RRESP`. In AMBA, `OKAY` (`2'b00`) confirms a valid access. Returning `SLVERR` informs the host CPU exception handler or bus interconnect that an invalid offset was addressed, allowing software debugging and preventing silent data corruption. In contrast, `DECERR` (`2'b11`) is reserved for interconnect-level decode failures when no target peripheral exists."*

### Q5: How do you support partial 32-bit register writes using `WSTRB`?
> **Model Answer:**
> *"AXI4-Lite provides four byte enable strobes (`WSTRB[3:0]`), each corresponding to an 8-bit lane of `WDATA[31:0]`. In my register write decoder, I implemented byte-granular updates using generate loops or byte slices. If `WSTRB[0]` is high, byte 0 is updated; if `WSTRB[1]` is high, byte 1 is updated, and so on. For the UART data register at `0x00`, only byte lane 0 is evaluated since the FIFO is 8 bits wide."*

---

## Category 2: Baud Rate Generation, 16X Oversampling & CDC

### Q6: Why do we use 16X oversampling instead of just sampling at the baud frequency (1X)?
> **Model Answer:**
> *"In asynchronous serial communication, there is no shared clock. A 1X receiver would have no way to reliably align its clock edge to the center of incoming bits. Due to phase offset, sampling at 1X would inevitably occur near the transition edges, leading to severe setup/hold violations and bit corruption. By running a local clock at 16X the baud frequency, we achieve a fine time resolution of $1/16\text{th}$ of a bit period. This allows us to detect the falling edge of the start bit within $\pm 1$ oversampling tick and position our sample strobe exactly at Tick 7 (the $50\%$ center of the eye diagram)."*

### Q7: What is your formula for calculating the baud divisor? Walk me through a 100MHz clock and 115200 baud.
> **Model Answer:**
> *"The oversampling frequency is $16 \times \text{Baud Rate}$. The divisor formula for a 0-indexed down-counter is:
> $$\text{DIVISOR} = \text{round}\left(\frac{f_{\text{clk}}}{16 \times \text{Baud Rate}}\right) - 1$$
> For $f_{\text{clk}} = 100\text{ MHz}$ and $\text{Baud} = 115,200$:
> $$\frac{100,000,000}{16 \times 115,200} = \frac{100,000,000}{1,843,200} \approx 54.2535$$
> Rounding to the nearest integer gives 54. Subtracting 1 yields a divisor of **`53` (`0x0035`)**.
> The actual synthesized baud rate is:
> $$\frac{100,000,000}{16 \times 54} = 115,740.74\text{ bps}$$
> The percentage error is:
> $$\frac{115,740.74 - 115,200}{115,200} \times 100\% = +0.47\%$$
> Since UART tolerates up to $\pm 3.75\%$ error over a 10-bit frame, $+0.47\%$ provides exceptional margin."*

### Q8: What is the maximum clock drift allowed between two UART devices in an 8-N-1 frame?
> **Model Answer:**
> *"In an 8-N-1 frame, there are 10 total bits (1 start, 8 data, 1 stop). The receiver samples the center of each bit. The last sample occurs at the center of the stop bit, which is $9.5$ bit periods after the initial start bit edge. For the stop bit sample to remain within the bit window, the cumulative phase drift over $9.5$ bits must not exceed half a bit period ($\pm 0.5 \times T_{\text{bit}}$).
> Therefore:
> $$\text{Max Drift} = \frac{\pm 0.5}{9.5} \approx \pm 5.26\%$$
> In practice, after accounting for rise/fall slew rates, duty cycle distortion, and noise, the industry standard maximum allowable clock frequency mismatch is **$\pm 2.0\%$ to $\pm 3.75\%$**."*

### Q9: The `RX` pin is asynchronous. Explain your CDC synchronization strategy and MTBF.
> **Model Answer:**
> *"Because external RX transitions can occur at any arbitrary time relative to the internal 100MHz clock, connecting RX directly to internal flip-flops would cause setup/hold violations and metastability. I routed the raw `uart_rxd` pin through a 2-stage flip-flop synchronizer. In modern 28nm FPGA technology with a 10ns clock period ($100\text{MHz}$), the settling time ($t_{\text{resolve}} \approx 9.5\text{ns}$) divided by the technology resolving time constant ($\tau \approx 20\text{ps}$) yields an exponential settling factor of $e^{475}$. The resulting MTBF exceeds millions of years. Furthermore, I applied vendor synthesis attributes `(* ASYNC_REG = "TRUE" *)` to force synthesis tools to place both registers in the same physical slice, minimizing interconnect delay."*

---

## Category 3: Center Sampling, Glitch Filtering & Error Recovery

### Q10: How does your receiver reject short electrical glitches on an idle line?
> **Model Answer:**
> *"When the receiver is in `IDLE`, it monitors the synchronized line for a falling edge ($1 \to 0$). Instead of immediately assuming a valid frame has begun, the receiver transitions to a `START_CHECK` state and starts counting 16X oversampling ticks. Exactly halfway through the start bit at **Tick 7**, it re-evaluates the line. If the line has returned to `1`, the event was a transient noise spike ($< T_{\text{bit}}/2$ duration). The receiver aborts and returns to `IDLE` without asserting any error or pushing garbage into the FIFO."*

### Q11: What is a framing error, and what physical conditions cause it?
> **Model Answer:**
> *"A framing error occurs when the receiver deserializes 8 data bits and samples the **Stop Bit** as logic `0` instead of the required logic `1` (Mark). Physical causes include:
> 1. Significant baud rate mismatch (> 4%) causing sample drift into adjacent bits.
> 2. A serial BREAK condition (line held low by transmitter to force a reset).
> 3. Disconnected cable or severed wire pulled low.
> 4. Excessive capacitive loading causing severe signal slew."*

### Q12: How does your receiver recover from a framing error? Why not just jump back to IDLE?
> **Model Answer:**
> *"If the receiver detected a framing error (stop bit = 0) and jumped directly back to `IDLE`, the edge detector would immediately see the persistent low level as another falling edge, triggering a cascade of false start bit detections across the rest of the packet or break condition!
> To prevent this, my receiver transitions to an `ERR_WAIT` recovery state. In `ERR_WAIT`, the receiver remains quiescent and waits until the serial line returns high to the idle Mark state (`sync_rx == 1`). Only once the line is stable high does it transition back to `IDLE`, safely re-arming for the next genuine start bit."*

---

## Category 4: Circular FIFO Buffer & Pointer Rollover Theory

### Q13: Explain the Pointer Rollover Method for distinguishing FIFO full from empty.
> **Model Answer:**
> *"In a FIFO with depth $D = 16$, 4 address bits ($N = 4$) index the 16 memory locations (`0` to `15`). If we only used 4-bit pointers, `wptr == rptr` would occur both when the FIFO is completely empty and when 16 writes have wrapped around to fill the buffer.
> The Pointer Rollover Method extends the pointers by 1 additional bit to $N+1 = 5$ bits (`ptr[4:0]`).
> The lower 4 bits (`ptr[3:0]`) represent the physical memory address.
> The 5th bit (`ptr[4]`) acts as a rollover phase flag.
> - **EMPTY Condition**: All 5 bits match exactly:
>   $$\text{wptr}[4:0] == \text{rptr}[4:0]$$
> - **FULL Condition**: Lower 4 address bits match, but the rollover bits (MSBs) are inverted:
>   $$(\text{wptr}[4] \ne \text{rptr}[4]) \land (\text{wptr}[3:0] == \text{rptr}[3:0])$$
> This cleanly resolves the ambiguity without requiring a separate counter."*

### Q14: Why not just use an up/down occupancy counter to generate `full` and `empty`?
> **Model Answer:**
> *"An occupancy counter requires incrementing on write, decrementing on read, and holding on simultaneous read/write. This introduces multi-input adders and multiplexers onto the FIFO flag generation logic. In high-frequency designs ($> 300\text{ MHz}$), this counter quickly lands on the critical timing path. With pointer rollover, full and empty are simple bitwise comparisons ($XNOR$ gates and $AND$ trees), which have significantly lower logic depth and faster timing closure."*

### Q15: How do you compute the number of elements in the FIFO using rollover pointers?
> **Model Answer:**
> *"By taking advantage of two's complement modular arithmetic, the valid element count ($0$ to $16$) is computed with a single 5-bit unsigned subtraction:
> $$\text{count}[4:0] = \text{wptr}[4:0] - \text{rptr}[4:0]$$
> For example, if 16 elements are written, `wptr = 5'b10000` (16) and `rptr = 5'b00000` (0): $16 - 0 = 16$ (FULL). If 1 byte is read, `rptr = 5'b00001` (1): $16 - 1 = 15$ elements remaining. The math holds universally."*

### Q16: What happens during a simultaneous push and pop when the FIFO is FULL?
> **Model Answer:**
> *"In my implementation, simultaneous push and pop when full is safely supported. A pop reads the oldest byte and increments `rptr`, while a push overwrites the freed slot and increments `wptr`. Both pointers advance by 1, the net count remains 16, and the FIFO remains valid and full without data loss or pointer corruption."*

---

## Category 5: Verification & ModelSim Testbench

### Q17: How did your testbench inject random delays to validate AXI handshaking?
> **Model Answer:**
> *"My SystemVerilog Master BFM used non-blocking procedural tasks with parameterized cycle delays. In the write task, I used a `fork ... join` block to drive `AWVALID` and `WVALID` concurrently with independent `$urandom_range(0, 10)` delays. This forced the slave to handle address-before-data, data-before-address, and simultaneous arrival. Additionally, the master randomized wait states before asserting `BREADY` and `RREADY`, validating that the slave properly held responses stable without deadlock."*

### Q18: How did you test framing error recovery in your testbench?
> **Model Answer:**
> *"I created a testbench task that serialized an 8-bit pattern onto the RX line, but intentionally held the line LOW (`0`) during the 16 ticks of the stop bit window. I queried the `UART_STATUS` register via AXI read to verify that `FRAMING_ERR` (bit 5) asserted and an interrupt was raised. Then, the testbench released the line high, cleared the error via W1C in `INTR_STAT`, and immediately transmitted a valid frame (`0x5A`). The testbench verified that `0x5A` was received with zero framing error, proving the receiver FSM recovered cleanly."*

---

## Category 6: Interview Defense Summary Checklist

When the interviewer asks you to draw your project on the whiteboard:
1. **Step 1**: Draw the 5 AXI channels on the left and the external pins (`TXD`, `RXD`, `IRQ`) on the right.
2. **Step 2**: Draw the AXI slave controller and explain the decoupled `aw_captured` / `w_captured` registers.
3. **Step 3**: Draw the dual 16-element FIFOs and write the pointer rollover full/empty equations on the board.
4. **Step 4**: Draw the baud rate generator and write the divisor formula ($\frac{f_{\text{clk}}}{16 \times B} - 1$).
5. **Step 5**: Draw the RX state machine, showing the 2-FF CDC synchronizer, Tick 7 center sample, and the `ERR_WAIT` recovery branch.
6. **Step 6**: Explain how your ModelSim testbench used randomized AXI delays and stop-bit corruption to prove 100% robustness.

[[02_Design_Tradeoffs_&_Alternative_Architectures|Next: Design Tradeoffs & Alternative Architectures ->]]
