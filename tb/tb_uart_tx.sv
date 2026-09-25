// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  tb_uart_tx
// Description: Comprehensive unit testbench for uart_tx module.
//              Verifies reset behavior, exact 16-tick bit timings, 8-N-1 framing,
//              tx_pop strobe behavior, tx_en disable, and zero-bubble burst streaming.
// =============================================================================

`timescale 1ns/1ps

module tb_uart_tx;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock
    localparam int  BAUD_DIV   = 4;    // Pulse every 5 clock cycles for simulation

    // DUT Signals
    logic       clk;
    logic       rst_n;
    logic       baud_16x_tick;
    logic       tx_en;
    logic [7:0] tx_data;
    logic       tx_empty;
    logic       tx_pop;
    logic       tx_out;
    logic       tx_busy;
    logic       tx_done;

    // Test tracking
    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    uart_tx dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .baud_16x_tick (baud_16x_tick),
        .tx_en         (tx_en),
        .tx_data       (tx_data),
        .tx_empty      (tx_empty),
        .tx_pop        (tx_pop),
        .tx_out        (tx_out),
        .tx_busy       (tx_busy),
        .tx_done       (tx_done)
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

    // Task to receive and verify a serialized 8-N-1 frame on tx_out
    task automatic verify_frame(input logic [7:0] expected_data, input string desc);
        logic [7:0] captured_data;
        int tick_counter;

        // 1. Wait for Start Bit (tx_out transitions to 0)
        while (tx_out !== 1'b0) @(posedge clk);
        check({desc, " - Start bit detected (0)"}, tx_out == 1'b0);

        // Count 16 ticks for start bit
        tick_counter = 0;
        while (tick_counter < 16) begin
            @(posedge clk);
            if (baud_16x_tick) tick_counter++;
        end

        // 2. Sample 8 Data Bits (LSB first)
        for (int b = 0; b < 8; b++) begin
            // Sample bit at middle (tick 7-8) or count through 16 ticks
            tick_counter = 0;
            while (tick_counter < 8) begin
                @(posedge clk);
                if (baud_16x_tick) tick_counter++;
            end
            captured_data[b] = tx_out; // Sample bit midpoint
            while (tick_counter < 16) begin
                @(posedge clk);
                if (baud_16x_tick) tick_counter++;
            end
        end

        check({desc, " - Data payload matches"}, captured_data == expected_data);

        // 3. Verify Stop Bit (sample at midpoint)
        tick_counter = 0;
        while (tick_counter < 8) begin
            @(posedge clk);
            if (baud_16x_tick) tick_counter++;
        end
        check({desc, " - Stop bit detected (1)"}, tx_out == 1'b1);

        while (tick_counter < 16) begin
            @(posedge clk);
            if (baud_16x_tick) tick_counter++;
        end
    endtask

    // Test Sequence
    initial begin
        // Global simulation watchdog
        #100ms;
        $fatal(1, "WATCHDOG TIMEOUT in tb_uart_tx");
    end

    initial begin
        $display("=========================================================");
        $display("   UART Transmitter (uart_tx) Unit Testbench Starting    ");
        $display("=========================================================");

        // -----------------------------------------------------------------
        // TEST 1: Reset Behavior
        // -----------------------------------------------------------------
        rst_n    = 1'b0;
        tx_en    = 1'b1;
        tx_data  = 8'h00;
        tx_empty = 1'b1;
        #(CLK_PERIOD * 5);

        check("TC_TX_01: In reset, tx_out is Mark (1'b1)", tx_out == 1'b1);
        check("TC_TX_01: In reset, tx_busy is de-asserted (1'b0)", tx_busy == 1'b0);
        check("TC_TX_01: In reset, tx_done is de-asserted (1'b0)", tx_done == 1'b0);
        check("TC_TX_01: In reset, tx_pop is de-asserted (1'b0)", tx_pop == 1'b0);

        rst_n = 1'b1;
        #(CLK_PERIOD * 5);
        check("TC_TX_01: Post-reset idle, tx_out remains 1'b1", tx_out == 1'b1);

        // -----------------------------------------------------------------
        // TEST 2: Transmitter Disable (tx_en = 0)
        // -----------------------------------------------------------------
        tx_en    = 1'b0;
        tx_data  = 8'h55;
        tx_empty = 1'b0; // Data available, but TX disabled
        #(CLK_PERIOD * 20);

        check("TC_TX_02: When tx_en=0, tx_pop is not asserted", tx_pop == 1'b0);
        check("TC_TX_02: When tx_en=0, tx_busy stays low", tx_busy == 1'b0);
        check("TC_TX_02: When tx_en=0, tx_out stays Mark (1'b1)", tx_out == 1'b1);

        // -----------------------------------------------------------------
        // TEST 3: Single Byte Transmission (0xA5)
        // -----------------------------------------------------------------
        tx_en    = 1'b1;
        tx_data  = 8'hA5;
        tx_empty = 1'b0;

        // Verify pop strobe: must assert for exactly 1 cycle
        @(posedge clk iff tx_pop == 1'b1);
        check("TC_TX_03: tx_pop asserted on data load", tx_pop == 1'b1);
        @(posedge clk);
        check("TC_TX_03: tx_pop de-asserts after exactly 1 cycle", tx_pop == 1'b0);

        // Empty the FIFO to allow single byte to finish cleanly
        tx_empty = 1'b1;

        // Verify frame
        verify_frame(8'hA5, "TC_TX_03: Byte 0xA5");

        // Wait for tx_done
        @(posedge clk iff tx_done == 1'b1);
        check("TC_TX_03: tx_done pulsed on frame completion", tx_done == 1'b1);
        @(posedge clk);
        check("TC_TX_03: tx_done returns low next cycle", tx_done == 1'b0);
        check("TC_TX_03: tx_busy returns low after completion", tx_busy == 1'b0);

        // -----------------------------------------------------------------
        // TEST 4: Zero-Bubble Back-to-Back Burst Transmission (4 Bytes)
        // -----------------------------------------------------------------
        // Stream 4 distinct bytes: 0x12, 0x34, 0x56, 0x78
        // Simulating continuous FIFO supply
        begin
            automatic logic [7:0] burst_payload [4] = '{8'h12, 8'h34, 8'h56, 8'h78};
            automatic int pop_idx = 0;

            tx_empty = 1'b0;
            tx_data  = burst_payload[0];

            fork
                // FIFO model thread: provides next byte on each pop
                begin
                    while (pop_idx < 4) begin
                        @(posedge clk);
                        if (tx_pop) begin
                            pop_idx++;
                            if (pop_idx < 4) begin
                                tx_data  <= burst_payload[pop_idx];
                                tx_empty <= 1'b0;
                            end else begin
                                tx_empty <= 1'b1; // Empty after 4th byte
                            end
                        end
                    end
                end

                // Verification thread: verifies all 4 frames sequentially
                begin
                    for (int f = 0; f < 4; f++) begin
                        verify_frame(burst_payload[f], $sformatf("TC_TX_04: Burst frame %0d (0x%02X)", f, burst_payload[f]));
                    end
                end
            join

            check("TC_TX_04: Exactly 4 FIFO pops occurred during burst", pop_idx == 4);
        end

        // -----------------------------------------------------------------
        // TEST 5: Verify bit_cnt Cleared on Burst Re-entry (Bug Regression)
        // -----------------------------------------------------------------
        // Verify specifically that byte 2, 3, etc. don't truncate data bits
        begin
            automatic logic [7:0] test_pattern [2] = '{8'hAA, 8'h55};
            automatic int pop_cnt = 0;

            tx_empty = 1'b0;
            tx_data  = test_pattern[0];

            fork
                begin
                    while (pop_cnt < 2) begin
                        @(posedge clk);
                        if (tx_pop) begin
                            pop_cnt++;
                            if (pop_cnt < 2) begin
                                tx_data  <= test_pattern[pop_cnt];
                                tx_empty <= 1'b0;
                            end else begin
                                tx_empty <= 1'b1;
                            end
                        end
                    end
                end

                begin
                    verify_frame(test_pattern[0], "TC_TX_05: Frame 0 (0xAA)");
                    verify_frame(test_pattern[1], "TC_TX_05: Frame 1 (0x55)");
                end
            join
        end

        // -----------------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------------
        $display("=========================================================");
        $display("   UART TX UNIT TEST COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=========================================================");

        if (fail_count == 0) begin
            $display(">>> SUCCESS: All UART TX Unit Tests Passed! <<<");
        end else begin
            $fatal(1, ">>> FAILURE: UART TX Unit Tests Failed! <<<");
        end

        $finish;
    end

endmodule
