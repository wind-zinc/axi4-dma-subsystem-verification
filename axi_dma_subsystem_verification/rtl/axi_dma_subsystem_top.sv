`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

// Backward-compatible name for the RAM-backed reference system.  New designs
// should instantiate axi_dma_subsystem_core or axi_dma_subsystem_ram_top
// explicitly, depending on whether the memory subsystem is part of the DUT.
module axi_dma_subsystem_top #(
    parameter bit ENABLE_UNALIGNED_PARAM = ENABLE_UNALIGNED
) (
    input wire clk,
    input wire rst,

    input logic [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr,
    input logic [2:0]                 s_axil_awprot,
    input logic                       s_axil_awvalid,
    output logic                      s_axil_awready,
    input logic [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
    input logic [AXIL_STRB_WIDTH-1:0] s_axil_wstrb,
    input logic                       s_axil_wvalid,
    output logic                      s_axil_wready,
    output logic [1:0]                s_axil_bresp,
    output logic                      s_axil_bvalid,
    input logic                       s_axil_bready,
    input logic [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
    input logic [2:0]                 s_axil_arprot,
    input logic                       s_axil_arvalid,
    output logic                      s_axil_arready,
    output logic [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
    output logic [1:0]                s_axil_rresp,
    output logic                      s_axil_rvalid,
    input logic                       s_axil_rready,

    input logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_awid,
    input logic [EXT_AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_awaddr,
    input logic [EXT_AXI_MASTER_COUNT*8-1:0] s_axi_ext_awlen,
    input logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_awsize,
    input logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_awburst,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awlock,
    input logic [EXT_AXI_MASTER_COUNT*4-1:0] s_axi_ext_awcache,
    input logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_awprot,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awvalid,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awready,
    input logic [EXT_AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_wdata,
    input logic [EXT_AXI_MASTER_COUNT*AXI_STRB_WIDTH-1:0] s_axi_ext_wstrb,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wlast,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wvalid,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wready,
    output logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_bid,
    output logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_bresp,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_bvalid,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_bready,
    input logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_arid,
    input logic [EXT_AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_araddr,
    input logic [EXT_AXI_MASTER_COUNT*8-1:0] s_axi_ext_arlen,
    input logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_arsize,
    input logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_arburst,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arlock,
    input logic [EXT_AXI_MASTER_COUNT*4-1:0] s_axi_ext_arcache,
    input logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_arprot,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arvalid,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arready,
    output logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_rid,
    output logic [EXT_AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_rdata,
    output logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_rresp,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rlast,
    output logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rvalid,
    input logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rready,

    output logic [DMA_CH_COUNT-1:0] irq_ch,
    output logic irq,
    output logic [DMA_CH_COUNT-1:0] subsys_busy
);

    axi_dma_subsystem_ram_top #(
        .ENABLE_UNALIGNED_PARAM(ENABLE_UNALIGNED_PARAM)
    ) u_ram_top (.*);

endmodule

`default_nettype wire
