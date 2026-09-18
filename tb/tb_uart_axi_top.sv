// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  tb_uart_axi_top
// Description: Comprehensive self-checking testbench validating register maps,
//              circular FIFO full/empty boundaries, loopback data integrity,
//              randomized AXI channel latencies, and framing error recovery.
// =============================================================================

`timescale 1ns / 1ps
import uart_pkg::*;

module tb_uart_axi_top;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock
    localparam int  FAST_DIVISOR = 4;  // Fast baud divisor for rapid simulation

    logic clk;
    logic rst_n;
    logic uart_txd;
    logic uart_rxd;
    logic uart_irq;

    // Instantiate AXI4-Lite Interface
    axi4_lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi_bus (
        .aclk(clk),
        .aresetn(rst_n)
    );

    // Instantiate DUT
    uart_axi_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .FIFO_DEPTH(16),
        .DEFAULT_DIV(FAST_DIVISOR)
    ) dut (
        .s_axi_aclk    (axi_bus.aclk),
        .s_axi_aresetn (axi_bus.aresetn),
        .s_axi_awaddr  (axi_bus.awaddr),
        .s_axi_awprot  (axi_bus.awprot),
        .s_axi_awvalid (axi_bus.awvalid),
        .s_axi_awready (axi_bus.awready),
        .s_axi_wdata   (axi_bus.wdata),
        .s_axi_wstrb   (axi_bus.wstrb),
        .s_axi_wvalid  (axi_bus.wvalid),
        .s_axi_wready  (axi_bus.wready),
        .s_axi_bresp   (axi_bus.bresp),
        .s_axi_bvalid  (axi_bus.bvalid),
        .s_axi_bready  (axi_bus.bready),
        .s_axi_araddr  (axi_bus.araddr),
        .s_axi_arprot  (axi_bus.arprot),
        .s_axi_arvalid (axi_bus.arvalid),
        .s_axi_arready (axi_bus.arready),
        .s_axi_rdata   (axi_bus.rdata),
        .s_axi_rresp   (axi_bus.rresp),
        .s_axi_rvalid  (axi_bus.rvalid),
        .s_axi_rready  (axi_bus.rready),
        .uart_txd      (uart_txd),
        .uart_rxd      (uart_rxd),
        .uart_irq      (uart_irq)
    );

    // Clock Generator (100 MHz)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test Variables & Scoreboard
    axi_master_bfm bfm;
    int test_pass_count = 0;
    int test_fail_count = 0;
    byte expected_queue[$];

    // Assert Helper Task
    task check(input string test_name, input bit condition);
        if (condition) begin
            $display("[PASS] %s", test_name);
            test_pass_count++;
        end else begin
            $error("[FAIL] %s", test_name);
            test_fail_count++;
        end
    endtask

    // Main Test Sequence
    initial begin
        bfm = new(axi_bus);
        uart_rxd = 1'b1; // Idle serial line

        // 1. Reset Phase
        rst_n = 1'b0;
        axi_bus.awvalid = 1'b0;
        axi_bus.wvalid  = 1'b0;
        axi_bus.bready  = 1'b0;
        axi_bus.arvalid = 1'b0;
        axi_bus.rready  = 1'b0;
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        $display("=========================================================");
        $display("   AXI4-Lite UART Peripheral Verification Suite Starting ");
        $display("=========================================================");

        // TEST 1: Register Reset Values
        begin
            logic [31:0] rdata;
            logic [1:0]  rresp;
            bfm.read_reg(32'h04, rdata, rresp); // UART_STATUS
            check("TC_01: Initial STATUS register has TX_EMPTY and RX_EMPTY", (rdata[0] == 1'b1) && (rdata[2] == 1'b1));
            bfm.read_reg(32'h08, rdata, rresp); // UART_CTRL
            check("TC_01: Initial CTRL register has TX_EN and RX_EN active", (rdata[1:0] == 2'b11));
        end

        // TEST 2: Unmapped Address Returns SLVERR
        begin
            logic [31:0] rdata;
            logic [1:0]  rresp;
            bfm.read_reg(32'h30, rdata, rresp);
            check("TC_02: Unmapped Read Address Returns SLVERR", rresp == AXI_RESP_SLVERR);
            bfm.write_reg(32'h30, 32'hA5A5_A5A5, 4'b1111, 0, 0, rresp);
            check("TC_02: Unmapped Write Address Returns SLVERR", rresp == AXI_RESP_SLVERR);
        end

        // TEST 3: Baud Rate Divisor Programming
        begin
            logic [31:0] rdata;
            logic [1:0]  resp;
            bfm.write_reg(32'h0C, 32'd26, 4'b0011, 0, 0, resp); // Write 26 (230400 baud)
            bfm.read_reg(32'h0C, rdata, resp);
            check("TC_03: BAUD_DIV register correctly updated to 26", rdata[15:0] == 16'd26);
            // Restore fast divisor for testbench speed
            bfm.write_reg(32'h0C, FAST_DIVISOR, 4'b0011, 0, 0, resp);
        end

        // TEST 4: Enable Internal Loopback Mode
        begin
            logic [1:0] resp;
            // CTRL[2]=1 (LOOPBACK_EN), CTRL[3]=1 (INTR_EN)
            bfm.write_reg(32'h08, 32'h0000_000F, 4'b0001, 0, 0, resp);
            // Enable all interrupt masks in INTR_EN
            bfm.write_reg(32'h18, 32'h0000_000F, 4'b0001, 0, 0, resp);
            check("TC_04: Loopback and Interrupts Enabled", resp == AXI_RESP_OKAY);
        end

        // TEST 5: Single Byte Loopback Transmission
        begin
            logic [31:0] rdata, stat;
            logic [1:0]  resp;
            bfm.write_reg(32'h00, 32'h0000_00A5, 4'b0001, 0, 0, resp);
            
            // Wait for receiver to capture data
            do begin
                #(CLK_PERIOD * 20);
                bfm.read_reg(32'h04, stat, resp);
            end while (stat[4] == 1'b0); // Wait until RX_DATA_READY

            bfm.read_reg(32'h00, rdata, resp);
            check("TC_05: Single Byte Loopback matches 0xA5", rdata[7:0] == 8'hA5);
        end

        // TEST 6: FIFO Burst Write to Full Capacity (16 Bytes)
        begin
            logic [31:0] stat, cnt;
            logic [1:0]  resp;

            // Disable TX temporarily to fill FIFO without transmitting
            bfm.write_reg(32'h08, 32'h0000_000E, 4'b0001, 0, 0, resp);

            for (int i = 0; i < 16; i++) begin
                bfm.write_reg(32'h00, (i + 8'h10), 4'b0001, 0, 0, resp);
            end

            bfm.read_reg(32'h04, stat, resp);
            bfm.read_reg(32'h10, cnt, resp);
            check("TC_06: TX FIFO is completely FULL (16 words)", (stat[1] == 1'b1) && (cnt[4:0] == 5'd16));

            // Overflow attempt: write 17th byte
            bfm.write_reg(32'h00, 32'hFF, 4'b0001, 0, 0, resp);

            // Re-enable TX to begin drain
            bfm.write_reg(32'h08, 32'h0000_000F, 4'b0001, 0, 0, resp);
        end

        // TEST 7: Drain Burst Loopback & Verify Order
        begin
            logic [31:0] rdata, stat;
            logic [1:0]  resp;
            bit match_ok = 1'b1;

            for (int i = 0; i < 16; i++) begin
                do begin
                    #(CLK_PERIOD * 10);
                    bfm.read_reg(32'h04, stat, resp);
                end while (stat[4] == 1'b0);

                bfm.read_reg(32'h00, rdata, resp);
                if (rdata[7:0] !== (i + 8'h10)) begin
                    match_ok = 1'b0;
                end
            end
            check("TC_07: 16-byte burst loopback transferred in exact order", match_ok);
        end

        // TEST 8: Randomized AXI Latency Stress Testing (100 Packets)
        begin
            logic [31:0] stat, rx_byte;
            logic [1:0]  resp;
            int error_count = 0;

            $display("--- Running Randomized AXI Latency Stress Test (100 Packets) ---");
            for (int p = 0; p < 100; p++) begin
                byte send_val = $urandom_range(0, 255);
                int aw_d = $urandom_range(0, 8);
                int w_d  = $urandom_range(0, 8);

                expected_queue.push_back(send_val);
                bfm.write_reg(32'h00, send_val, 4'b0001, aw_d, w_d, resp);

                // Read whenever available
                bfm.read_reg(32'h04, stat, resp);
                if (stat[4]) begin
                    int ar_d = $urandom_range(0, 5);
                    bfm.read_reg(32'h00, rx_byte, resp, ar_d);
                    if (rx_byte[7:0] !== expected_queue.pop_front()) begin
                        error_count++;
                    end
                end
            end

            // Flush remaining
            while (expected_queue.size() > 0) begin
                do begin
                    #(CLK_PERIOD * 10);
                    bfm.read_reg(32'h04, stat, resp);
                end while (stat[4] == 1'b0);

                bfm.read_reg(32'h00, rx_byte, resp);
                if (rx_byte[7:0] !== expected_queue.pop_front()) begin
                    error_count++;
                end
            end

            check("TC_08: Randomized AXI channel latencies completed with zero errors", error_count == 0);
        end

        // TEST 9: Framing Error Injection & Safe Recovery
        begin
            logic [31:0] stat;
            logic [1:0]  resp;
            time bit_time = (FAST_DIVISOR + 1) * 16 * CLK_PERIOD;

            $display("--- Running Framing Error Injection & Recovery Test ---");

            // Disable internal loopback to manually drive external RX pin
            bfm.write_reg(32'h08, 32'h0000_000B, 4'b0001, 0, 0, resp); // LOOPBACK=0

            // 1. Drive Start Bit (0)
            uart_rxd = 1'b0;
            #(bit_time);

            // 2. Drive 8 Data Bits (0x3C = 8'b00111100, LSB first)
            for (int b = 0; b < 8; b++) begin
                uart_rxd = (8'h3C >> b) & 1'b1;
                #(bit_time);
            end

            // 3. INJECT ERROR: Drive Stop Bit to 0 instead of 1!
            uart_rxd = 1'b0;
            #(bit_time);

            // 4. Verify Framing Error Flag in STATUS
            bfm.read_reg(32'h04, stat, resp);
            check("TC_09: Framing Error Flag Asserted on Corrupted Stop Bit", stat[5] == 1'b1);

            // 5. Release line back to idle Mark (1)
            uart_rxd = 1'b1;
            #(bit_time * 2);

            // 6. Clear framing error via W1C in INTR_STAT
            bfm.write_reg(32'h14, 32'h0000_0004, 4'b0001, 0, 0, resp);

            // 7. Verify Receiver Recovers on Subsequent Valid Frame (0x77)
            uart_rxd = 1'b0; // Start
            #(bit_time);
            for (int b = 0; b < 8; b++) begin
                uart_rxd = (8'h77 >> b) & 1'b1;
                #(bit_time);
            end
            uart_rxd = 1'b1; // Valid Stop bit!
            #(bit_time);

            // Check captured data
            bfm.read_reg(32'h04, stat, resp);
            check("TC_09: Framing Error Flag Cleared", stat[5] == 1'b0);
            check("TC_09: Valid Byte Captured after Recovery", stat[4] == 1'b1);

            begin
                logic [31:0] rx_val;
                bfm.read_reg(32'h00, rx_val, resp);
                check("TC_09: Recovered Data Matches 0x77", rx_val[7:0] == 8'h77);
            end
        end

        // Final Summary
        $display("=========================================================");
        $display("   VERIFICATION COMPLETE: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0) begin
            $display(">>> SUCCESS: All AXI4-Lite UART Test Cases Passed! <<<");
        end else begin
            $display(">>> FAILURE: Verification Test Failures Detected! <<<");
        end

        $finish;
    end

endmodule : tb_uart_axi_top
