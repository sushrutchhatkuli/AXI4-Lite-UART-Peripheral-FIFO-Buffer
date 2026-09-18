---
title: "AXI4-Lite Master BFM & Test Scenarios"
tags:
  - testbench
  - bfm
  - systemverilog
  - verification
  - randomization
date: 2026-09-18
status: active
---

# AXI4-Lite Master BFM & Test Scenarios

The testbench incorporates an **AXI4-Lite Master Bus Functional Model (BFM)** capable of driving write and read transactions with randomized inter-channel latencies, simulating real CPU and DMA interconnect behavior.

---

## 1. Synthesizable BFM Architecture

The Master BFM provides task-based procedural methods in SystemVerilog to execute transactions:
- `axi_write(addr, data, [strb], [aw_delay], [w_delay], [b_delay])`
- `axi_read(addr, [output data], [output resp], [ar_delay], [r_delay])`

```systemverilog
class axi_master_bfm;
    virtual axi4_lite_if vif;

    function new(virtual axi4_lite_if vif);
        this.vif = vif;
    endfunction

    // Write Transaction with Randomized Handshake Delays
    task write_reg(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb = 4'b1111,
        input int          aw_delay = 0,
        input int          w_delay = 0,
        output logic [1:0] bresp
    );
        // Fork independent AW and W channel drivers to test concurrency
        fork
            begin
                repeat(aw_delay) @(posedge vif.aclk);
                vif.awaddr  <= addr;
                vif.awprot  <= 3'b000;
                vif.awvalid <= 1'b1;
                do @(posedge vif.aclk); while (!vif.awready);
                vif.awvalid <= 1'b0;
            end
            begin
                repeat(w_delay) @(posedge vif.aclk);
                vif.wdata  <= data;
                vif.wstrb  <= strb;
                vif.wvalid <= 1'b1;
                do @(posedge vif.aclk); while (!vif.wready);
                vif.wvalid <= 1'b0;
            end
        join

        // Wait for response
        vif.bready <= 1'b1;
        do @(posedge vif.aclk); while (!vif.bvalid);
        bresp = vif.bresp;
        vif.bready <= 1'b0;
    endtask

    // Read Transaction
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
endclass
```

---

## 2. Randomized Delay Testing Strategy

To flush out corner-case race conditions in the slave's register slicing:
1. **`aw_delay > w_delay`**: Data arrives early; slave must hold data and wait for address.
2. **`w_delay > aw_delay`**: Address arrives early; slave must hold address and wait for data.
3. **`bready_delay > 0`**: Master delays response acknowledgment; slave must hold `bvalid` and `bresp` completely stable until master is ready.
4. **`rready_delay > 0`**: Master delays reading data; slave must hold `rvalid` and `rdata` stable.

[[03_Loopback_Testing_&_Framing_Error_Injection|Next: Loopback Testing & Framing Error Injection ->]]
