---
title: "UART Top-Level Interconnect"
tags:
  - top-level
  - integration
  - systemverilog
  - interconnect
  - loopback
date: 2026-09-18
status: active
---

# UART Top-Level Interconnect

The top-level module `uart_axi_top.sv` integrates the AMBA AXI4-Lite slave interface, the dual 16-element circular FIFOs, the 16X oversampling baud rate generator, the UART TX/RX cores, loopback multiplexing, and the interrupt controller.

---

## 1. System Interconnect Wiring Diagram

```mermaid
graph TD
    subgraph AXI_INTERFACE ["AXI4-Lite Port (32-bit)"]
        S_AW["s_axi_aw*"]
        S_W["s_axi_w*"]
        S_B["s_axi_b*"]
        S_AR["s_axi_ar*"]
        S_R["s_axi_r*"]
    end

    subgraph CORE ["uart_axi_top"]
        AXI_SLV["axi4_lite_slave<br/>(Bus Protocol Engine)"]
        
        TX_FIFO["fifo_circular (TX)<br/>Depth: 16, Width: 8"]
        RX_FIFO["fifo_circular (RX)<br/>Depth: 16, Width: 8"]
        
        BAUD_GEN["uart_baud_gen<br/>(16X Oversampler)"]
        
        TX_MOD["uart_tx<br/>(8-N-1 Serializer)"]
        RX_MOD["uart_rx<br/>(8-N-1 Deserializer)"]
        
        LP_MUX{"Loopback<br/>Mux"}
        INTR_LOGIC["Interrupt Logic<br/>(W1C Register)"]
    end

    subgraph PINS ["External Chip Pins"]
        PIN_TXD["TXD Output"]
        PIN_RXD["RXD Input"]
        PIN_IRQ["IRQ Output"]
    end

    S_AW --> AXI_SLV
    S_W --> AXI_SLV
    AXI_SLV --> S_B
    S_AR --> AXI_SLV
    AXI_SLV --> S_R

    AXI_SLV -- "Write 0x00 (tx_push, wdata[7:0])" --> TX_FIFO
    RX_FIFO -- "Read 0x00 (rdata[7:0])" --> AXI_SLV
    AXI_SLV -- "rx_pop" --> RX_FIFO

    AXI_SLV -- "baud_div[15:0]" --> BAUD_GEN
    BAUD_GEN -- "baud_16x_tick" --> TX_MOD
    BAUD_GEN -- "baud_16x_tick" --> RX_MOD

    TX_FIFO -- "tx_pop, data" --> TX_MOD
    TX_MOD -- "tx_serial" --> LP_MUX
    TX_MOD -- "tx_serial" --> PIN_TXD

    PIN_RXD --> LP_MUX
    LP_MUX -- "rx_selected" --> RX_MOD
    RX_MOD -- "rx_push, data" --> RX_FIFO

    AXI_SLV --> INTR_LOGIC
    TX_FIFO --> INTR_LOGIC
    RX_FIFO --> INTR_LOGIC
    RX_MOD --> INTR_LOGIC
    INTR_LOGIC --> PIN_IRQ
```

---

## 2. Loopback Multiplexing Logic

The control register bit `UART_CTRL[2]` (`LOOPBACK_EN`) governs whether the receiver listens to the external pin or the internal transmitter:

```systemverilog
// Loopback multiplexer
wire rx_internal_line = (ctrl_reg[2]) ? tx_serial_out : ext_uart_rxd;
```

### Advantages of Internal Loopback
1. **Self-Diagnostic Testing**: Software drivers can verify the integrity of the AXI slave, FIFOs, baud generator, and serializer/deserializer without requiring any external wiring or test equipment.
2. **Deterministic Automated Regression**: Enables automated ModelSim and FPGA board-level self-tests.

---

## 3. Top-Level Module Interface (`uart_axi_top.sv`)

```systemverilog
module uart_axi_top #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int FIFO_DEPTH     = 16,
    parameter int DEFAULT_DIV    = 53 // 115200 baud @ 100MHz
)(
    input  logic                      s_axi_aclk,
    input  logic                      s_axi_aresetn,

    // AXI4-Lite Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]                s_axi_awprot,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]                s_axi_arprot,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // Serial Pins
    output logic                      uart_txd,
    input  logic                      uart_rxd,

    // Interrupt Line
    output logic                      uart_irq
);
    // Complete internal interconnect logic defined in rtl/uart_axi_top.sv
endmodule
```

[[02_Interrupt_Architecture_&_Status_Reporting|Next: Interrupt Architecture & Status Reporting ->]]
