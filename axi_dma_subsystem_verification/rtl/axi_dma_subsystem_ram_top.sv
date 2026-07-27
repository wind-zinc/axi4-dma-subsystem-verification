`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

// Reference system wrapper.  It preserves the original self-contained
// two-RAM system while leaving axi_dma_subsystem_core free of a fixed slave.
module axi_dma_subsystem_ram_top #(
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

    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] m_axi_mem_awid;
    logic [AXI_SLAVE_COUNT*AXI_ADDR_WIDTH-1:0] m_axi_mem_awaddr;
    logic [AXI_SLAVE_COUNT*8-1:0] m_axi_mem_awlen;
    logic [AXI_SLAVE_COUNT*3-1:0] m_axi_mem_awsize;
    logic [AXI_SLAVE_COUNT*2-1:0] m_axi_mem_awburst;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_awlock;
    logic [AXI_SLAVE_COUNT*4-1:0] m_axi_mem_awcache;
    logic [AXI_SLAVE_COUNT*3-1:0] m_axi_mem_awprot;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_awvalid;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_awready;
    logic [AXI_SLAVE_COUNT*AXI_DATA_WIDTH-1:0] m_axi_mem_wdata;
    logic [AXI_SLAVE_COUNT*AXI_STRB_WIDTH-1:0] m_axi_mem_wstrb;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_wlast;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_wvalid;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_wready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] m_axi_mem_bid;
    logic [AXI_SLAVE_COUNT*2-1:0] m_axi_mem_bresp;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_bvalid;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_bready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] m_axi_mem_arid;
    logic [AXI_SLAVE_COUNT*AXI_ADDR_WIDTH-1:0] m_axi_mem_araddr;
    logic [AXI_SLAVE_COUNT*8-1:0] m_axi_mem_arlen;
    logic [AXI_SLAVE_COUNT*3-1:0] m_axi_mem_arsize;
    logic [AXI_SLAVE_COUNT*2-1:0] m_axi_mem_arburst;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_arlock;
    logic [AXI_SLAVE_COUNT*4-1:0] m_axi_mem_arcache;
    logic [AXI_SLAVE_COUNT*3-1:0] m_axi_mem_arprot;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_arvalid;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_arready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] m_axi_mem_rid;
    logic [AXI_SLAVE_COUNT*AXI_DATA_WIDTH-1:0] m_axi_mem_rdata;
    logic [AXI_SLAVE_COUNT*2-1:0] m_axi_mem_rresp;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_rlast;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_rvalid;
    logic [AXI_SLAVE_COUNT-1:0] m_axi_mem_rready;

    axi_dma_subsystem_core #(
        .ENABLE_UNALIGNED_PARAM(ENABLE_UNALIGNED_PARAM)
    ) u_core (.*);

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_RAM_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_XBAR_M_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_ram0 (
        .clk(clk), .rst(rst),
        .s_axi_awid(m_axi_mem_awid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(m_axi_mem_awaddr[0 +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_awlen(m_axi_mem_awlen[0 +: 8]),
        .s_axi_awsize(m_axi_mem_awsize[0 +: 3]),
        .s_axi_awburst(m_axi_mem_awburst[0 +: 2]),
        .s_axi_awlock(m_axi_mem_awlock[0]),
        .s_axi_awcache(m_axi_mem_awcache[0 +: 4]),
        .s_axi_awprot(m_axi_mem_awprot[0 +: 3]),
        .s_axi_awvalid(m_axi_mem_awvalid[0]),
        .s_axi_awready(m_axi_mem_awready[0]),
        .s_axi_wdata(m_axi_mem_wdata[0 +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(m_axi_mem_wstrb[0 +: AXI_STRB_WIDTH]),
        .s_axi_wlast(m_axi_mem_wlast[0]),
        .s_axi_wvalid(m_axi_mem_wvalid[0]),
        .s_axi_wready(m_axi_mem_wready[0]),
        .s_axi_bid(m_axi_mem_bid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_bresp(m_axi_mem_bresp[0 +: 2]),
        .s_axi_bvalid(m_axi_mem_bvalid[0]),
        .s_axi_bready(m_axi_mem_bready[0]),
        .s_axi_arid(m_axi_mem_arid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(m_axi_mem_araddr[0 +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_arlen(m_axi_mem_arlen[0 +: 8]),
        .s_axi_arsize(m_axi_mem_arsize[0 +: 3]),
        .s_axi_arburst(m_axi_mem_arburst[0 +: 2]),
        .s_axi_arlock(m_axi_mem_arlock[0]),
        .s_axi_arcache(m_axi_mem_arcache[0 +: 4]),
        .s_axi_arprot(m_axi_mem_arprot[0 +: 3]),
        .s_axi_arvalid(m_axi_mem_arvalid[0]),
        .s_axi_arready(m_axi_mem_arready[0]),
        .s_axi_rid(m_axi_mem_rid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(m_axi_mem_rdata[0 +: AXI_DATA_WIDTH]),
        .s_axi_rresp(m_axi_mem_rresp[0 +: 2]),
        .s_axi_rlast(m_axi_mem_rlast[0]),
        .s_axi_rvalid(m_axi_mem_rvalid[0]),
        .s_axi_rready(m_axi_mem_rready[0])
    );

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_RAM_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_XBAR_M_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_ram1 (
        .clk(clk), .rst(rst),
        .s_axi_awid(m_axi_mem_awid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(m_axi_mem_awaddr[AXI_ADDR_WIDTH +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_awlen(m_axi_mem_awlen[8 +: 8]),
        .s_axi_awsize(m_axi_mem_awsize[3 +: 3]),
        .s_axi_awburst(m_axi_mem_awburst[2 +: 2]),
        .s_axi_awlock(m_axi_mem_awlock[1]),
        .s_axi_awcache(m_axi_mem_awcache[4 +: 4]),
        .s_axi_awprot(m_axi_mem_awprot[3 +: 3]),
        .s_axi_awvalid(m_axi_mem_awvalid[1]),
        .s_axi_awready(m_axi_mem_awready[1]),
        .s_axi_wdata(m_axi_mem_wdata[AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(m_axi_mem_wstrb[AXI_STRB_WIDTH +: AXI_STRB_WIDTH]),
        .s_axi_wlast(m_axi_mem_wlast[1]),
        .s_axi_wvalid(m_axi_mem_wvalid[1]),
        .s_axi_wready(m_axi_mem_wready[1]),
        .s_axi_bid(m_axi_mem_bid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_bresp(m_axi_mem_bresp[2 +: 2]),
        .s_axi_bvalid(m_axi_mem_bvalid[1]),
        .s_axi_bready(m_axi_mem_bready[1]),
        .s_axi_arid(m_axi_mem_arid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(m_axi_mem_araddr[AXI_ADDR_WIDTH +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_arlen(m_axi_mem_arlen[8 +: 8]),
        .s_axi_arsize(m_axi_mem_arsize[3 +: 3]),
        .s_axi_arburst(m_axi_mem_arburst[2 +: 2]),
        .s_axi_arlock(m_axi_mem_arlock[1]),
        .s_axi_arcache(m_axi_mem_arcache[4 +: 4]),
        .s_axi_arprot(m_axi_mem_arprot[3 +: 3]),
        .s_axi_arvalid(m_axi_mem_arvalid[1]),
        .s_axi_arready(m_axi_mem_arready[1]),
        .s_axi_rid(m_axi_mem_rid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(m_axi_mem_rdata[AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_rresp(m_axi_mem_rresp[2 +: 2]),
        .s_axi_rlast(m_axi_mem_rlast[1]),
        .s_axi_rvalid(m_axi_mem_rvalid[1]),
        .s_axi_rready(m_axi_mem_rready[1])
    );

endmodule

`default_nettype wire
