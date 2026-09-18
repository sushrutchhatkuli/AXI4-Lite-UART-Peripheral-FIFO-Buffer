// =============================================================================
// Company/Author: Sushrut Chhatkuli
// Project: AXI4-Lite UART Peripheral & FIFO Buffer
// Module:  axi_master_bfm
// Description: SystemVerilog class implementing an AXI4-Lite Master Bus Functional
//              Model with randomized AW/W skew and backpressure wait states.
// =============================================================================

class axi_master_bfm;

    virtual axi4_lite_if vif;

    function new(virtual axi4_lite_if vif);
        this.vif = vif;
    endfunction

    // Write Register Task with Randomized Latencies
    task write_reg(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb = 4'b1111,
        input int          aw_delay = 0,
        input int          w_delay = 0,
        output logic [1:0] bresp
    );
        fork
            // AW Channel Thread
            begin
                repeat(aw_delay) @(posedge vif.aclk);
                vif.awaddr  <= addr;
                vif.awprot  <= 3'b000;
                vif.awvalid <= 1'b1;
                do @(posedge vif.aclk); while (!vif.awready);
                vif.awvalid <= 1'b0;
            end

            // W Channel Thread
            begin
                repeat(w_delay) @(posedge vif.aclk);
                vif.wdata  <= data;
                vif.wstrb  <= strb;
                vif.wvalid <= 1'b1;
                do @(posedge vif.aclk); while (!vif.wready);
                vif.wvalid <= 1'b0;
            end
        join

        // B Channel Response
        vif.bready <= 1'b1;
        do @(posedge vif.aclk); while (!vif.bvalid);
        bresp = vif.bresp;
        vif.bready <= 1'b0;
    endtask

    // Read Register Task
    task read_reg(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  rresp,
        input  int          ar_delay = 0
    );
        repeat(ar_delay) @(posedge vif.aclk);
        vif.araddr  <= addr;
        vif.arprot  <= 3'b000;
        vif.arvalid <= 1'b1;
        do @(posedge vif.aclk); while (!vif.arready);
        vif.arvalid <= 1'b0;

        vif.rready <= 1'b1;
        do @(posedge vif.aclk); while (!vif.rvalid);
        data  = vif.rdata;
        rresp = vif.rresp;
        vif.rready <= 1'b0;
    endtask

endclass : axi_master_bfm
