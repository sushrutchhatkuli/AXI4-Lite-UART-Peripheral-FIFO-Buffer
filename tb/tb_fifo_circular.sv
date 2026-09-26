// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  tb_fifo_circular
// Description: Comprehensive unit testbench for fifo_circular module.
//              Verifies (N+1)-bit pointer rollover math, full/empty generation,
//              overflow drop protection, underflow protection, simultaneous
//              push/pop at partial and full states, and continuous pointer wrap.
// =============================================================================

`timescale 1ns/1ps

module tb_fifo_circular;

    localparam time CLK_PERIOD = 10ns;
    localparam int  DATA_WIDTH = 8;
    localparam int  DEPTH      = 16;
    localparam int  PTR_WIDTH  = 5;

    // DUT Signals
    logic                  clk;
    logic                  rst_n;
    logic                  push;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  full;
    logic                  pop;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  empty;
    logic [PTR_WIDTH-1:0]  count;

    // Test tracking
    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    fifo_circular #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .push  (push),
        .wdata (wdata),
        .full  (full),
        .pop   (pop),
        .rdata (rdata),
        .empty (empty),
        .count (count)
    );

    // Clock Generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
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

    // Helper task to push a byte on negedge clk
    task automatic do_push(input logic [7:0] data_byte);
        @(negedge clk);
        push  = 1'b1;
        wdata = data_byte;
        @(negedge clk);
        push  = 1'b0;
        wdata = '0;
    endtask

    // Helper task to pop a byte on negedge clk
    task automatic do_pop(output logic [7:0] data_byte);
        @(negedge clk);
        data_byte = rdata; // Sample continuous read from RAM head
        pop   = 1'b1;
        @(negedge clk);
        pop   = 1'b0;
    endtask

    // Global simulation watchdog
    initial begin
        #100ms;
        $fatal(1, "WATCHDOG TIMEOUT in tb_fifo_circular");
    end

    // Test Sequence
    initial begin
        automatic logic [7:0] temp_byte;

        $display("=========================================================");
        $display("   Circular FIFO (fifo_circular) Unit Testbench Starting ");
        $display("=========================================================");

        // -----------------------------------------------------------------
        // TEST 1: Reset State
        // -----------------------------------------------------------------
        rst_n = 1'b0;
        push  = 1'b0;
        wdata = '0;
        pop   = 1'b0;
        #(CLK_PERIOD * 5);

        check("TC_FIFO_01: In reset, empty is 1'b1", empty == 1'b1);
        check("TC_FIFO_01: In reset, full is 1'b0", full == 1'b0);
        check("TC_FIFO_01: In reset, count is 0", count == 5'd0);

        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        check("TC_FIFO_01: Post-reset idle, empty is 1'b1", empty == 1'b1);
        check("TC_FIFO_01: Post-reset idle, count is 0", count == 5'd0);

        // -----------------------------------------------------------------
        // TEST 2: Single Push and Pop
        // -----------------------------------------------------------------
        do_push(8'h5A);
        check("TC_FIFO_02: After 1 push, count is 1", count == 5'd1);
        check("TC_FIFO_02: After 1 push, empty is 1'b0", empty == 1'b0);
        check("TC_FIFO_02: After 1 push, full is 1'b0", full == 1'b0);
        check("TC_FIFO_02: Read data shows pushed value 0x5A", rdata == 8'h5A);

        do_pop(temp_byte);
        check("TC_FIFO_02: Popped data matches 0x5A", temp_byte == 8'h5A);
        check("TC_FIFO_02: After pop, count returns to 0", count == 5'd0);
        check("TC_FIFO_02: After pop, empty is 1'b1", empty == 1'b1);

        // -----------------------------------------------------------------
        // TEST 3: Fill to Full Capacity (16 Entries)
        // -----------------------------------------------------------------
        for (int i = 0; i < 16; i++) begin
            do_push(8'(i + 8'h10));
        end

        check("TC_FIFO_03: After 16 pushes, count is 16", count == 5'd16);
        check("TC_FIFO_03: After 16 pushes, full is 1'b1", full == 1'b1);
        check("TC_FIFO_03: After 16 pushes, empty is 1'b0", empty == 1'b0);

        // -----------------------------------------------------------------
        // TEST 4: Overflow Drop Protection (Write While Full)
        // -----------------------------------------------------------------
        do_push(8'hEE); // Should be rejected
        check("TC_FIFO_04: After overflow attempt, count remains 16", count == 5'd16);
        check("TC_FIFO_04: After overflow attempt, full remains 1'b1", full == 1'b1);

        // -----------------------------------------------------------------
        // TEST 5: Drain FIFO Completely & Verify Data Ordering
        // -----------------------------------------------------------------
        for (int i = 0; i < 16; i++) begin
            automatic logic [7:0] expected_val = 8'(i + 8'h10);
            do_pop(temp_byte);
            check($sformatf("TC_FIFO_05: Pop %0d matches expected 0x%02X", i, expected_val), temp_byte == expected_val);
        end

        check("TC_FIFO_05: After draining 16 words, count is 0", count == 5'd0);
        check("TC_FIFO_05: After draining 16 words, empty is 1'b1", empty == 1'b1);
        check("TC_FIFO_05: After draining 16 words, full is 1'b0", full == 1'b0);

        // -----------------------------------------------------------------
        // TEST 6: Underflow Protection (Read While Empty)
        // -----------------------------------------------------------------
        @(negedge clk);
        pop = 1'b1;
        @(negedge clk);
        pop = 1'b0;

        check("TC_FIFO_06: Pop while empty does not decrement count below 0", count == 5'd0);
        check("TC_FIFO_06: Empty flag remains 1'b1", empty == 1'b1);

        // -----------------------------------------------------------------
        // TEST 7: Simultaneous Push and Pop (Partially Full)
        // -----------------------------------------------------------------
        // Fill 4 entries: 0xA1, 0xA2, 0xA3, 0xA4
        for (int i = 1; i <= 4; i++) begin
            do_push(8'(8'hA0 + i));
        end
        check("TC_FIFO_07: Filled 4 items, count is 4", count == 5'd4);

        // Simultaneous push(0xB1) and pop()
        @(negedge clk);
        push  = 1'b1;
        wdata = 8'hB1;
        pop   = 1'b1;
        temp_byte = rdata; // Should read oldest (0xA1)
        @(negedge clk);
        push  = 1'b0;
        pop   = 1'b0;

        check("TC_FIFO_07: Simultaneous push/pop keeps count at 4", count == 5'd4);
        check("TC_FIFO_07: Popped item was oldest (0xA1)", temp_byte == 8'hA1);

        // Drain remaining 4 items: should be 0xA2, 0xA3, 0xA4, 0xB1
        do_pop(temp_byte); check("TC_FIFO_07: Next item is 0xA2", temp_byte == 8'hA2);
        do_pop(temp_byte); check("TC_FIFO_07: Next item is 0xA3", temp_byte == 8'hA3);
        do_pop(temp_byte); check("TC_FIFO_07: Next item is 0xA4", temp_byte == 8'hA4);
        do_pop(temp_byte); check("TC_FIFO_07: Last item is newly pushed 0xB1", temp_byte == 8'hB1);
        check("TC_FIFO_07: FIFO empty after drain", empty == 1'b1);

        // -----------------------------------------------------------------
        // TEST 8: Simultaneous Push and Pop When FULL (Handshake Throughput)
        // -----------------------------------------------------------------
        // Fill 16 items
        for (int i = 0; i < 16; i++) begin
            do_push(8'(i + 1));
        end
        check("TC_FIFO_08: FIFO full with 16 items", full == 1'b1);

        // Simultaneous push(0xFF) and pop() while full: allowed because an entry leaves
        @(negedge clk);
        push  = 1'b1;
        wdata = 8'hFF;
        pop   = 1'b1;
        temp_byte = rdata; // Should read oldest item (0x01)
        @(negedge clk);
        push  = 1'b0;
        pop   = 1'b0;

        check("TC_FIFO_08: Simultaneous push/pop while full succeeded", count == 5'd16);
        check("TC_FIFO_08: FIFO remains full", full == 1'b1);
        check("TC_FIFO_08: Read item was oldest (0x01)", temp_byte == 8'h01);

        // Drain 16 items: 2..16, followed by 0xFF
        for (int i = 2; i <= 16; i++) begin
            do_pop(temp_byte);
            check($sformatf("TC_FIFO_08: Drained item %0d matches", i), temp_byte == 8'(i));
        end
        do_pop(temp_byte);
        check("TC_FIFO_08: Final drained item is newly pushed 0xFF", temp_byte == 8'hFF);
        check("TC_FIFO_08: FIFO empty", empty == 1'b1);

        // -----------------------------------------------------------------
        // TEST 9: Pointer Rollover Stress (Multiple Wraparounds)
        // -----------------------------------------------------------------
        // Push and pop 64 bytes continuously (4 complete 16-word wraparounds)
        begin
            automatic int wrap_pass = 1;
            for (int w = 0; w < 64; w++) begin
                do_push(8'(w));
                do_pop(temp_byte);
                if (temp_byte != 8'(w)) begin
                    wrap_pass = 0;
                    $display("[FAIL] Rollover mismatch at w=%0d: expected 0x%02X, got 0x%02X", w, w, temp_byte);
                end
            end
            check("TC_FIFO_09: 64 continuous push/pop rollover cycles passed with zero corruption", wrap_pass == 1);
            check("TC_FIFO_09: FIFO ends empty after 64 wraps", empty == 1'b1 && count == 5'd0);
        end

        // -----------------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------------
        $display("=========================================================");
        $display("   CIRCULAR FIFO UNIT TEST COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=========================================================");

        if (fail_count == 0) begin
            $display(">>> SUCCESS: All Circular FIFO Unit Tests Passed! <<<");
        end else begin
            $fatal(1, ">>> FAILURE: Circular FIFO Unit Tests Failed! <<<");
        end

        $finish;
    end

endmodule
