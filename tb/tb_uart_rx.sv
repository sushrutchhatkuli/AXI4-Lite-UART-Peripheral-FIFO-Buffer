// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  tb_uart_rx
// Description: Comprehensive unit testbench for uart_rx module.
//              Verifies reset, glitch rejection, Tick 7 center-sampling,
//              framing error detection, ERR_WAIT recovery, FIFO overrun handling,
//              and zero-bubble back-to-back frame reception.
// =============================================================================

`timescale 1ns/1ps

module tb_uart_rx;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock
    localparam int  BAUD_DIV   = 4;    // Pulse every 5 clock cycles for simulation

    // DUT Signals
    logic       clk;
    logic       rst_n;
    logic       baud_16x_tick;
    logic       rx_en;
    logic       rx_async_in;
    logic [7:0] rx_data;
    logic       rx_push;
    logic       rx_fifo_full;
    logic       rx_busy;
    logic       framing_err;
    logic       overrun_err;

    // Test tracking
    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    uart_rx dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .baud_16x_tick (baud_16x_tick),
        .rx_en         (rx_en),
        .rx_async_in   (rx_async_in),
        .rx_data       (rx_data),
        .rx_push       (rx_push),
        .rx_fifo_full  (rx_fifo_full),
        .rx_busy       (rx_busy),
        .framing_err   (framing_err),
        .overrun_err   (overrun_err)
    );

    // Clock Generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Baud Tick Generator (emulating uart_baud_gen)
    int baud_div_cnt = 0;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_cnt  <= 0;
            baud_16x_tick <= 1'b0;
        end else begin
            if (baud_div_cnt >= BAUD_DIV) begin
                baud_div_cnt  <= 0;
                baud_16x_tick <= 1'b1;
            end else begin
                baud_div_cnt  <= baud_div_cnt + 1;
                baud_16x_tick <= 1'b0;
            end
        end
    end

    // Check helper task
    task automatic check(string test_name, bit condition);
        if (condition) begin
            $display("[PASS] @%0t: %s", $time, test_name);
            pass_count++;
        end else begin
            $display("[FAIL] @%0t: %s", $time, test_name);
            fail_count++;
        end
    endtask

    // Helper task to wait for N baud ticks
    task automatic wait_baud_ticks(int count);
        int t = 0;
        while (t < count) begin
            @(posedge clk);
            if (baud_16x_tick) t++;
        end
    endtask

    // Helper task to transmit a serial 8-N-1 frame into rx_async_in
    task automatic send_serial_frame(
        input logic [7:0] byte_val,
        input bit         corrupt_stop = 1'b0,
        input int         stop_duration_ticks = 16
    );
        // Start bit (0)
        rx_async_in = 1'b0;
        wait_baud_ticks(16);

        // 8 Data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            rx_async_in = byte_val[i];
            wait_baud_ticks(16);
        end

        // Stop bit (1 normally, or 0 if corrupted)
        rx_async_in = corrupt_stop ? 1'b0 : 1'b1;
        wait_baud_ticks(stop_duration_ticks);
    endtask

    // Global simulation watchdog
    initial begin
        #100ms;
        $fatal(1, "WATCHDOG TIMEOUT in tb_uart_rx");
    end

    // Test Sequence
    initial begin
        $display("=========================================================");
        $display("     UART Receiver (uart_rx) Unit Testbench Starting     ");
        $display("=========================================================");

        // -----------------------------------------------------------------
        // TEST 1: Reset Behavior
        // -----------------------------------------------------------------
        rst_n        = 1'b0;
        rx_en        = 1'b1;
        rx_async_in  = 1'b1; // Idle Mark
        rx_fifo_full = 1'b0;
        #(CLK_PERIOD * 5);

        check("TC_RX_01: In reset, rx_busy is 0", rx_busy == 1'b0);
        check("TC_RX_01: In reset, rx_push is 0", rx_push == 1'b0);
        check("TC_RX_01: In reset, framing_err is 0", framing_err == 1'b0);
        check("TC_RX_01: In reset, overrun_err is 0", overrun_err == 1'b0);

        rst_n = 1'b1;
        #(CLK_PERIOD * 5);
        check("TC_RX_01: Post-reset idle, rx_busy remains 0", rx_busy == 1'b0);

        // -----------------------------------------------------------------
        // TEST 2: Receiver Disable (rx_en = 0)
        // -----------------------------------------------------------------
        rx_en = 1'b0;
        // Inject falling edge while disabled
        rx_async_in = 1'b0;
        wait_baud_ticks(16);
        rx_async_in = 1'b1;
        wait_baud_ticks(16);

        check("TC_RX_02: When rx_en=0, receiver ignores falling edge", rx_busy == 1'b0);
        check("TC_RX_02: When rx_en=0, rx_push is not asserted", rx_push == 1'b0);

        rx_en = 1'b1;
        wait_baud_ticks(5);

        // -----------------------------------------------------------------
        // TEST 3: Start-Bit Noise Glitch Rejection
        // -----------------------------------------------------------------
        // Inject a 3-tick noise glitch low, returning to 1 before Tick 7
        rx_async_in = 1'b0;
        wait_baud_ticks(3); // Glitch duration: 3 oversampling ticks
        rx_async_in = 1'b1; // Reverts to Mark
        wait_baud_ticks(16);

        check("TC_RX_03: Glitch rejected, rx_push did not assert", rx_push == 1'b0);
        check("TC_RX_03: Glitch rejected, receiver returned to IDLE (rx_busy=0)", rx_busy == 1'b0);
        check("TC_RX_03: Glitch rejected, no framing error flagged", framing_err == 1'b0);

        // -----------------------------------------------------------------
        // TEST 4: Normal Single-Byte Reception (0xA5)
        // -----------------------------------------------------------------
        fork
            begin
                send_serial_frame(8'hA5);
            end
            begin
                @(posedge clk iff rx_push == 1'b1);
                check("TC_RX_04: rx_push asserted for valid frame", rx_push == 1'b1);
                check("TC_RX_04: Captured data matches 0xA5", rx_data == 8'hA5);
                check("TC_RX_04: No framing error during valid reception", framing_err == 1'b0);
                @(posedge clk);
                check("TC_RX_04: rx_push de-asserts after exactly 1 cycle", rx_push == 1'b0);
            end
        join

        wait_baud_ticks(10);

        // -----------------------------------------------------------------
        // TEST 5: Framing Error Detection (Corrupted Stop Bit)
        // -----------------------------------------------------------------
        fork
            begin
                // Transmit byte 0x5A with stop bit forced to 0
                send_serial_frame(8'h5A, .corrupt_stop(1'b1), .stop_duration_ticks(16));
            end
            begin
                @(posedge clk iff framing_err == 1'b1);
                check("TC_RX_05: framing_err asserted on invalid stop bit", framing_err == 1'b1);
                check("TC_RX_05: rx_push NOT asserted on framing error", rx_push == 1'b0);
                @(posedge clk);
                check("TC_RX_05: framing_err strobe pulses for 1 cycle", framing_err == 1'b0);
            end
        join

        // -----------------------------------------------------------------
        // TEST 6: Framing Error Recovery via ERR_WAIT
        // -----------------------------------------------------------------
        // The serial line was left low at the end of TC_5.
        // Confirm receiver stays in ERR_WAIT (rx_busy == 1) while line is low
        wait_baud_ticks(8);
        check("TC_RX_06: In ERR_WAIT, rx_busy stays high while line is low", rx_busy == 1'b1);

        // Release serial line back to Mark (1)
        rx_async_in = 1'b1;
        wait_baud_ticks(5); // Synchronizer latency + FSM transition
        check("TC_RX_06: Receiver returned to IDLE once line returned high", rx_busy == 1'b0);

        // Send valid byte 0x3C to prove complete resynchronization
        fork
            begin
                send_serial_frame(8'h3C);
            end
            begin
                @(posedge clk iff rx_push == 1'b1);
                check("TC_RX_06: Clean recovery - valid byte 0x3C received", rx_data == 8'h3C);
            end
        join

        wait_baud_ticks(10);

        // -----------------------------------------------------------------
        // TEST 7: RX FIFO Overrun Error Handling
        // -----------------------------------------------------------------
        // Set rx_fifo_full = 1, then send valid frame 0xF0
        rx_fifo_full = 1'b1;
        fork
            begin
                send_serial_frame(8'hF0);
            end
            begin
                @(posedge clk iff overrun_err == 1'b1);
                check("TC_RX_07: overrun_err asserted when FIFO is full", overrun_err == 1'b1);
                check("TC_RX_07: rx_push NOT asserted when FIFO is full", rx_push == 1'b0);
                @(posedge clk);
                check("TC_RX_07: overrun_err pulses for 1 cycle", overrun_err == 1'b0);
            end
        join

        rx_fifo_full = 1'b0;
        wait_baud_ticks(10);

        // -----------------------------------------------------------------
        // TEST 8: Zero-Bubble Back-to-Back Burst Reception (2 Frames)
        // -----------------------------------------------------------------
        // Tests the 8-tick guard band fix: frame 1 followed immediately by frame 2
        // with stop bit lasting only 16 ticks total before next start bit arrives.
        fork
            begin
                send_serial_frame(8'h11, .corrupt_stop(1'b0), .stop_duration_ticks(16));
                send_serial_frame(8'h22, .corrupt_stop(1'b0), .stop_duration_ticks(16));
            end
            begin
                // Receive frame 1
                @(posedge clk iff rx_push == 1'b1);
                check("TC_RX_08: Back-to-back Frame 1 received (0x11)", rx_data == 8'h11);
                // Receive frame 2
                @(posedge clk iff rx_push == 1'b1);
                check("TC_RX_08: Back-to-back Frame 2 received (0x22)", rx_data == 8'h22);
            end
        join

        wait_baud_ticks(10);

        // -----------------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------------
        $display("=========================================================");
        $display("   UART RX UNIT TEST COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=========================================================");

        if (fail_count == 0) begin
            $display(">>> SUCCESS: All UART RX Unit Tests Passed! <<<");
        end else begin
            $fatal(1, ">>> FAILURE: UART RX Unit Tests Failed! <<<");
        end

        $finish;
    end

endmodule
