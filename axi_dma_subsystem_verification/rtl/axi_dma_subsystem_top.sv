`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module axi_dma_subsystem_top #(
    parameter bit ENABLE_UNALIGNED_PARAM = ENABLE_UNALIGNED
) (
    input logic clk,
    input logic rst,

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

    localparam logic [63:0] AXI_XBAR_BASE_ADDR = {RAM1_BASE_ADDR, RAM0_BASE_ADDR};
    localparam logic [63:0] AXI_XBAR_ADDR_WIDTH = {32'd16, 32'd16};
    localparam logic [95:0] AXIL_XBAR_BASE_ADDR = {
        GLOBAL_IRQ_BASE_ADDR, CH1_CTRL_BASE_ADDR, CH0_CTRL_BASE_ADDR
    };
    localparam logic [95:0] AXIL_XBAR_ADDR_WIDTH = {32'd12, 32'd12, 32'd12};

    logic [DMA_CH_COUNT-1:0] cmd_valid;
    dma_cmd_t cmd_payload [DMA_CH_COUNT-1:0];
    logic [DMA_CH_COUNT-1:0] cmd_ready;
    logic [DMA_CH_COUNT-1:0] manager_busy;
    logic [DMA_CH_COUNT-1:0] abort_req;
    logic [DMA_CH_COUNT-1:0] completion_valid;
    dma_completion_t completion [DMA_CH_COUNT-1:0];

    logic [DMA_CH_COUNT-1:0] route_req_valid;
    logic [DMA_CH_COUNT-1:0] route_req_src;
    logic [DMA_CH_COUNT-1:0] route_req_dst;
    logic [DMA_CH_COUNT-1:0] route_req_ready;
    logic [DMA_CH_COUNT-1:0] route_dest;
    logic [DMA_CH_COUNT-1:0] route_release;
    logic [DMA_CH_COUNT-1:0] route_active;
    logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0] route_matrix;
    logic route_fault_valid;
    dma_error_e route_fault_code;
    logic [2:0] route_fault_source;

    logic manager_fault_valid;
    dma_fault_t manager_fault;
    logic combined_fault_valid;
    dma_fault_t combined_fault;

    logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] rd_desc_addr;
    logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] rd_desc_len;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] rd_desc_tag;
    logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] rd_desc_id;
    logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] rd_desc_dest;
    logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] rd_desc_user;
    logic [DMA_CH_COUNT-1:0] rd_desc_valid;
    logic [DMA_CH_COUNT-1:0] rd_desc_ready;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] rd_status_tag;
    logic [DMA_CH_COUNT-1:0][3:0] rd_status_error;
    logic [DMA_CH_COUNT-1:0] rd_status_valid;

    logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] wr_desc_addr;
    logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] wr_desc_len;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] wr_desc_tag;
    logic [DMA_CH_COUNT-1:0] wr_desc_valid;
    logic [DMA_CH_COUNT-1:0] wr_desc_ready;
    logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] wr_status_len;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] wr_status_tag;
    logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] wr_status_id;
    logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] wr_status_dest;
    logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] wr_status_user;
    logic [DMA_CH_COUNT-1:0][3:0] wr_status_error;
    logic [DMA_CH_COUNT-1:0] wr_status_valid;

    logic [DMA_CH_COUNT-1:0][AXIS_DATA_WIDTH-1:0] axis_read_tdata;
    logic [DMA_CH_COUNT-1:0][AXIS_KEEP_WIDTH-1:0] axis_read_tkeep;
    logic [DMA_CH_COUNT-1:0] axis_read_tvalid;
    logic [DMA_CH_COUNT-1:0] axis_read_tready;
    logic [DMA_CH_COUNT-1:0] axis_read_tlast;
    logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] axis_read_tid;
    logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] axis_read_tdest;
    logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] axis_read_tuser;
    logic [DMA_CH_COUNT-1:0][AXIS_DATA_WIDTH-1:0] axis_write_tdata;
    logic [DMA_CH_COUNT-1:0][AXIS_KEEP_WIDTH-1:0] axis_write_tkeep;
    logic [DMA_CH_COUNT-1:0] axis_write_tvalid;
    logic [DMA_CH_COUNT-1:0] axis_write_tready;
    logic [DMA_CH_COUNT-1:0] axis_write_tlast;
    logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] axis_write_tid;
    logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] axis_write_tdest;
    logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] axis_write_tuser;

    logic [DMA_CH_COUNT-1:0][AXI_ID_WIDTH-1:0] dma_axi_awid;
    logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] dma_axi_awaddr;
    logic [DMA_CH_COUNT-1:0][7:0] dma_axi_awlen;
    logic [DMA_CH_COUNT-1:0][2:0] dma_axi_awsize;
    logic [DMA_CH_COUNT-1:0][1:0] dma_axi_awburst;
    logic [DMA_CH_COUNT-1:0] dma_axi_awlock;
    logic [DMA_CH_COUNT-1:0][3:0] dma_axi_awcache;
    logic [DMA_CH_COUNT-1:0][2:0] dma_axi_awprot;
    logic [DMA_CH_COUNT-1:0] dma_axi_awvalid;
    logic [DMA_CH_COUNT-1:0] dma_axi_awready;
    logic [DMA_CH_COUNT-1:0][AXI_DATA_WIDTH-1:0] dma_axi_wdata;
    logic [DMA_CH_COUNT-1:0][AXI_STRB_WIDTH-1:0] dma_axi_wstrb;
    logic [DMA_CH_COUNT-1:0] dma_axi_wlast;
    logic [DMA_CH_COUNT-1:0] dma_axi_wvalid;
    logic [DMA_CH_COUNT-1:0] dma_axi_wready;
    logic [DMA_CH_COUNT-1:0][AXI_ID_WIDTH-1:0] dma_axi_bid;
    logic [DMA_CH_COUNT-1:0][1:0] dma_axi_bresp;
    logic [DMA_CH_COUNT-1:0] dma_axi_bvalid;
    logic [DMA_CH_COUNT-1:0] dma_axi_bready;
    logic [DMA_CH_COUNT-1:0][AXI_ID_WIDTH-1:0] dma_axi_arid;
    logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] dma_axi_araddr;
    logic [DMA_CH_COUNT-1:0][7:0] dma_axi_arlen;
    logic [DMA_CH_COUNT-1:0][2:0] dma_axi_arsize;
    logic [DMA_CH_COUNT-1:0][1:0] dma_axi_arburst;
    logic [DMA_CH_COUNT-1:0] dma_axi_arlock;
    logic [DMA_CH_COUNT-1:0][3:0] dma_axi_arcache;
    logic [DMA_CH_COUNT-1:0][2:0] dma_axi_arprot;
    logic [DMA_CH_COUNT-1:0] dma_axi_arvalid;
    logic [DMA_CH_COUNT-1:0] dma_axi_arready;
    logic [DMA_CH_COUNT-1:0][AXI_ID_WIDTH-1:0] dma_axi_rid;
    logic [DMA_CH_COUNT-1:0][AXI_DATA_WIDTH-1:0] dma_axi_rdata;
    logic [DMA_CH_COUNT-1:0][1:0] dma_axi_rresp;
    logic [DMA_CH_COUNT-1:0] dma_axi_rlast;
    logic [DMA_CH_COUNT-1:0] dma_axi_rvalid;
    logic [DMA_CH_COUNT-1:0] dma_axi_rready;

    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] ram_bid;
    logic [AXI_SLAVE_COUNT*2-1:0] ram_bresp;
    logic [AXI_SLAVE_COUNT-1:0] ram_bvalid;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] ram_rid;
    logic [AXI_SLAVE_COUNT*AXI_DATA_WIDTH-1:0] ram_rdata;
    logic [AXI_SLAVE_COUNT*2-1:0] ram_rresp;
    logic [AXI_SLAVE_COUNT-1:0] ram_rlast;
    logic [AXI_SLAVE_COUNT-1:0] ram_rvalid;

    logic [AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] axi_s_awid;
    logic [AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] axi_s_awaddr;
    logic [AXI_MASTER_COUNT*8-1:0] axi_s_awlen;
    logic [AXI_MASTER_COUNT*3-1:0] axi_s_awsize;
    logic [AXI_MASTER_COUNT*2-1:0] axi_s_awburst;
    logic [AXI_MASTER_COUNT-1:0] axi_s_awlock;
    logic [AXI_MASTER_COUNT*4-1:0] axi_s_awcache;
    logic [AXI_MASTER_COUNT*3-1:0] axi_s_awprot;
    logic [AXI_MASTER_COUNT*4-1:0] axi_s_awqos;
    logic [AXI_MASTER_COUNT-1:0] axi_s_awvalid;
    logic [AXI_MASTER_COUNT-1:0] axi_s_awready;
    logic [AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] axi_s_wdata;
    logic [AXI_MASTER_COUNT*AXI_STRB_WIDTH-1:0] axi_s_wstrb;
    logic [AXI_MASTER_COUNT-1:0] axi_s_wlast;
    logic [AXI_MASTER_COUNT-1:0] axi_s_wvalid;
    logic [AXI_MASTER_COUNT-1:0] axi_s_wready;
    logic [AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] axi_s_bid;
    logic [AXI_MASTER_COUNT*2-1:0] axi_s_bresp;
    logic [AXI_MASTER_COUNT-1:0] axi_s_bvalid;
    logic [AXI_MASTER_COUNT-1:0] axi_s_bready;
    logic [AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] axi_s_arid;
    logic [AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] axi_s_araddr;
    logic [AXI_MASTER_COUNT*8-1:0] axi_s_arlen;
    logic [AXI_MASTER_COUNT*3-1:0] axi_s_arsize;
    logic [AXI_MASTER_COUNT*2-1:0] axi_s_arburst;
    logic [AXI_MASTER_COUNT-1:0] axi_s_arlock;
    logic [AXI_MASTER_COUNT*4-1:0] axi_s_arcache;
    logic [AXI_MASTER_COUNT*3-1:0] axi_s_arprot;
    logic [AXI_MASTER_COUNT*4-1:0] axi_s_arqos;
    logic [AXI_MASTER_COUNT-1:0] axi_s_arvalid;
    logic [AXI_MASTER_COUNT-1:0] axi_s_arready;
    logic [AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] axi_s_rid;
    logic [AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] axi_s_rdata;
    logic [AXI_MASTER_COUNT*2-1:0] axi_s_rresp;
    logic [AXI_MASTER_COUNT-1:0] axi_s_rlast;
    logic [AXI_MASTER_COUNT-1:0] axi_s_rvalid;
    logic [AXI_MASTER_COUNT-1:0] axi_s_rready;

    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] axi_m_awid;
    logic [AXI_SLAVE_COUNT*AXI_ADDR_WIDTH-1:0] axi_m_awaddr;
    logic [AXI_SLAVE_COUNT*8-1:0] axi_m_awlen;
    logic [AXI_SLAVE_COUNT*3-1:0] axi_m_awsize;
    logic [AXI_SLAVE_COUNT*2-1:0] axi_m_awburst;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_awlock;
    logic [AXI_SLAVE_COUNT*4-1:0] axi_m_awcache;
    logic [AXI_SLAVE_COUNT*3-1:0] axi_m_awprot;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_awvalid;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_awready;
    logic [AXI_SLAVE_COUNT*AXI_DATA_WIDTH-1:0] axi_m_wdata;
    logic [AXI_SLAVE_COUNT*AXI_STRB_WIDTH-1:0] axi_m_wstrb;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_wlast;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_wvalid;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_wready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] axi_m_bid;
    logic [AXI_SLAVE_COUNT*2-1:0] axi_m_bresp;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_bvalid;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_bready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] axi_m_arid;
    logic [AXI_SLAVE_COUNT*AXI_ADDR_WIDTH-1:0] axi_m_araddr;
    logic [AXI_SLAVE_COUNT*8-1:0] axi_m_arlen;
    logic [AXI_SLAVE_COUNT*3-1:0] axi_m_arsize;
    logic [AXI_SLAVE_COUNT*2-1:0] axi_m_arburst;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_arlock;
    logic [AXI_SLAVE_COUNT*4-1:0] axi_m_arcache;
    logic [AXI_SLAVE_COUNT*3-1:0] axi_m_arprot;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_arvalid;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_arready;
    logic [AXI_SLAVE_COUNT*AXI_XBAR_M_ID_WIDTH-1:0] axi_m_rid;
    logic [AXI_SLAVE_COUNT*AXI_DATA_WIDTH-1:0] axi_m_rdata;
    logic [AXI_SLAVE_COUNT*2-1:0] axi_m_rresp;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_rlast;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_rvalid;
    logic [AXI_SLAVE_COUNT-1:0] axi_m_rready;

    logic [AXIL_ADDR_WIDTH*3-1:0] axil_m_awaddr;
    logic [3*3-1:0] axil_m_awprot;
    logic [2:0] axil_m_awvalid;
    logic [2:0] axil_m_awready;
    logic [AXIL_DATA_WIDTH*3-1:0] axil_m_wdata;
    logic [AXIL_STRB_WIDTH*3-1:0] axil_m_wstrb;
    logic [2:0] axil_m_wvalid;
    logic [2:0] axil_m_wready;
    logic [3*2-1:0] axil_m_bresp;
    logic [2:0] axil_m_bvalid;
    logic [2:0] axil_m_bready;
    logic [AXIL_ADDR_WIDTH*3-1:0] axil_m_araddr;
    logic [3*3-1:0] axil_m_arprot;
    logic [2:0] axil_m_arvalid;
    logic [2:0] axil_m_arready;
    logic [AXIL_DATA_WIDTH*3-1:0] axil_m_rdata;
    logic [3*2-1:0] axil_m_rresp;
    logic [2:0] axil_m_rvalid;
    logic [2:0] axil_m_rready;

    logic [DMA_CH_COUNT*AXIL_BLOCK_ADDR_WIDTH-1:0] ctrl_awaddr;
    logic [DMA_CH_COUNT*3-1:0] ctrl_awprot;
    logic [DMA_CH_COUNT-1:0] ctrl_awvalid;
    logic [DMA_CH_COUNT-1:0] ctrl_awready;
    logic [DMA_CH_COUNT*AXIL_DATA_WIDTH-1:0] ctrl_wdata;
    logic [DMA_CH_COUNT*AXIL_STRB_WIDTH-1:0] ctrl_wstrb;
    logic [DMA_CH_COUNT-1:0] ctrl_wvalid;
    logic [DMA_CH_COUNT-1:0] ctrl_wready;
    logic [DMA_CH_COUNT*2-1:0] ctrl_bresp;
    logic [DMA_CH_COUNT-1:0] ctrl_bvalid;
    logic [DMA_CH_COUNT-1:0] ctrl_bready;
    logic [DMA_CH_COUNT*AXIL_BLOCK_ADDR_WIDTH-1:0] ctrl_araddr;
    logic [DMA_CH_COUNT*3-1:0] ctrl_arprot;
    logic [DMA_CH_COUNT-1:0] ctrl_arvalid;
    logic [DMA_CH_COUNT-1:0] ctrl_arready;
    logic [DMA_CH_COUNT*AXIL_DATA_WIDTH-1:0] ctrl_rdata;
    logic [DMA_CH_COUNT*2-1:0] ctrl_rresp;
    logic [DMA_CH_COUNT-1:0] ctrl_rvalid;
    logic [DMA_CH_COUNT-1:0] ctrl_rready;

    logic [AXIL_BLOCK_ADDR_WIDTH-1:0] irq_awaddr;
    logic [2:0] irq_awprot;
    logic irq_awvalid;
    logic irq_awready;
    logic [AXIL_DATA_WIDTH-1:0] irq_wdata;
    logic [AXIL_STRB_WIDTH-1:0] irq_wstrb;
    logic irq_wvalid;
    logic irq_wready;
    logic [1:0] irq_bresp;
    logic irq_bvalid;
    logic irq_bready;
    logic [AXIL_BLOCK_ADDR_WIDTH-1:0] irq_araddr;
    logic [2:0] irq_arprot;
    logic irq_arvalid;
    logic irq_arready;
    logic [AXIL_DATA_WIDTH-1:0] irq_rdata;
    logic [1:0] irq_rresp;
    logic irq_rvalid;
    logic irq_rready;

    assign subsys_busy = manager_busy;

    always_comb begin
        if (manager_fault_valid) begin
            combined_fault_valid = 1'b1;
            combined_fault = manager_fault;
        end else begin
            combined_fault_valid = route_fault_valid;
            combined_fault.error = route_fault_code;
            combined_fault.source = route_fault_source;
        end
    end

    assign axi_s_awid = {s_axi_ext_awid, dma_axi_awid};
    assign axi_s_awaddr = {s_axi_ext_awaddr, dma_axi_awaddr};
    assign axi_s_awlen = {s_axi_ext_awlen, dma_axi_awlen};
    assign axi_s_awsize = {s_axi_ext_awsize, dma_axi_awsize};
    assign axi_s_awburst = {s_axi_ext_awburst, dma_axi_awburst};
    assign axi_s_awlock = {s_axi_ext_awlock, dma_axi_awlock};
    assign axi_s_awcache = {s_axi_ext_awcache, dma_axi_awcache};
    assign axi_s_awprot = {s_axi_ext_awprot, dma_axi_awprot};
    assign axi_s_awvalid = {s_axi_ext_awvalid, dma_axi_awvalid};
    assign axi_s_wdata = {s_axi_ext_wdata, dma_axi_wdata};
    assign axi_s_wstrb = {s_axi_ext_wstrb, dma_axi_wstrb};
    assign axi_s_wlast = {s_axi_ext_wlast, dma_axi_wlast};
    assign axi_s_wvalid = {s_axi_ext_wvalid, dma_axi_wvalid};
    assign axi_s_bready = {s_axi_ext_bready, dma_axi_bready};
    assign axi_s_arid = {s_axi_ext_arid, dma_axi_arid};
    assign axi_s_araddr = {s_axi_ext_araddr, dma_axi_araddr};
    assign axi_s_arlen = {s_axi_ext_arlen, dma_axi_arlen};
    assign axi_s_arsize = {s_axi_ext_arsize, dma_axi_arsize};
    assign axi_s_arburst = {s_axi_ext_arburst, dma_axi_arburst};
    assign axi_s_arlock = {s_axi_ext_arlock, dma_axi_arlock};
    assign axi_s_arcache = {s_axi_ext_arcache, dma_axi_arcache};
    assign axi_s_arprot = {s_axi_ext_arprot, dma_axi_arprot};
    assign axi_s_arvalid = {s_axi_ext_arvalid, dma_axi_arvalid};
    assign axi_s_rready = {s_axi_ext_rready, dma_axi_rready};
    assign axi_s_awqos = '0;
    assign axi_s_arqos = '0;

    assign dma_axi_awready = axi_s_awready[DMA_CH_COUNT-1:0];
    assign dma_axi_wready = axi_s_wready[DMA_CH_COUNT-1:0];
    assign dma_axi_bid = axi_s_bid[DMA_CH_COUNT*AXI_ID_WIDTH-1:0];
    assign dma_axi_bresp = axi_s_bresp[DMA_CH_COUNT*2-1:0];
    assign dma_axi_bvalid = axi_s_bvalid[DMA_CH_COUNT-1:0];
    assign dma_axi_arready = axi_s_arready[DMA_CH_COUNT-1:0];
    assign dma_axi_rid = axi_s_rid[DMA_CH_COUNT*AXI_ID_WIDTH-1:0];
    assign dma_axi_rdata = axi_s_rdata[DMA_CH_COUNT*AXI_DATA_WIDTH-1:0];
    assign dma_axi_rresp = axi_s_rresp[DMA_CH_COUNT*2-1:0];
    assign dma_axi_rlast = axi_s_rlast[DMA_CH_COUNT-1:0];
    assign dma_axi_rvalid = axi_s_rvalid[DMA_CH_COUNT-1:0];
    assign s_axi_ext_awready = axi_s_awready[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];
    assign s_axi_ext_wready = axi_s_wready[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];
    assign s_axi_ext_bid = axi_s_bid[DMA_CH_COUNT*AXI_ID_WIDTH +: EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH];
    assign s_axi_ext_bresp = axi_s_bresp[DMA_CH_COUNT*2 +: EXT_AXI_MASTER_COUNT*2];
    assign s_axi_ext_bvalid = axi_s_bvalid[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];
    assign s_axi_ext_arready = axi_s_arready[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];
    assign s_axi_ext_rid = axi_s_rid[DMA_CH_COUNT*AXI_ID_WIDTH +: EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH];
    assign s_axi_ext_rdata = axi_s_rdata[DMA_CH_COUNT*AXI_DATA_WIDTH +: EXT_AXI_MASTER_COUNT*AXI_DATA_WIDTH];
    assign s_axi_ext_rresp = axi_s_rresp[DMA_CH_COUNT*2 +: EXT_AXI_MASTER_COUNT*2];
    assign s_axi_ext_rlast = axi_s_rlast[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];
    assign s_axi_ext_rvalid = axi_s_rvalid[DMA_CH_COUNT +: EXT_AXI_MASTER_COUNT];

    assign axi_m_bid[0 +: AXI_XBAR_M_ID_WIDTH] = ram_bid[0 +: AXI_XBAR_M_ID_WIDTH];
    assign axi_m_bid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH] = ram_bid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH];
    assign axi_m_bresp = ram_bresp;
    assign axi_m_bvalid = ram_bvalid;
    assign axi_m_rid = ram_rid;
    assign axi_m_rdata = ram_rdata;
    assign axi_m_rresp = ram_rresp;
    assign axi_m_rlast = ram_rlast;
    assign axi_m_rvalid = ram_rvalid;

    assign axil_m_bresp[0 +: 2] = ctrl_bresp[0 +: 2];
    assign axil_m_bresp[2 +: 2] = ctrl_bresp[2 +: 2];
    assign axil_m_bresp[4 +: 2] = irq_bresp;
    assign axil_m_bvalid[0] = ctrl_bvalid[0];
    assign axil_m_bvalid[1] = ctrl_bvalid[1];
    assign axil_m_bvalid[2] = irq_bvalid;
    assign axil_m_rdata[0 +: AXIL_DATA_WIDTH] = ctrl_rdata[0 +: AXIL_DATA_WIDTH];
    assign axil_m_rdata[AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH] = ctrl_rdata[AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH];
    assign axil_m_rdata[2*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH] = irq_rdata;
    assign axil_m_rresp[0 +: 2] = ctrl_rresp[0 +: 2];
    assign axil_m_rresp[2 +: 2] = ctrl_rresp[2 +: 2];
    assign axil_m_rresp[4 +: 2] = irq_rresp;
    assign axil_m_rvalid[0] = ctrl_rvalid[0];
    assign axil_m_rvalid[1] = ctrl_rvalid[1];
    assign axil_m_rvalid[2] = irq_rvalid;

    axi_crossbar #(
        .S_COUNT(AXI_MASTER_COUNT),
        .M_COUNT(AXI_SLAVE_COUNT),
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .S_ID_WIDTH(AXI_ID_WIDTH),
        .M_ID_WIDTH(AXI_XBAR_M_ID_WIDTH),
        .AWUSER_ENABLE(0),
        .WUSER_ENABLE(0),
        .BUSER_ENABLE(0),
        .ARUSER_ENABLE(0),
        .RUSER_ENABLE(0),
        .S_THREADS({AXI_MASTER_COUNT{32'd2}}),
        .S_ACCEPT({AXI_MASTER_COUNT{32'd16}}),
        .M_REGIONS(1),
        .M_BASE_ADDR(AXI_XBAR_BASE_ADDR),
        .M_ADDR_WIDTH(AXI_XBAR_ADDR_WIDTH),
        .M_CONNECT_READ(8'hFF),
        .M_CONNECT_WRITE(8'hFF),
        .M_ISSUE({AXI_SLAVE_COUNT{32'd4}}),
        .M_SECURE({AXI_SLAVE_COUNT{1'b0}})
    ) u_axi_xbar (
        .clk(clk),
        .rst(rst),
        .s_axi_awid(axi_s_awid),
        .s_axi_awaddr(axi_s_awaddr),
        .s_axi_awlen(axi_s_awlen),
        .s_axi_awsize(axi_s_awsize),
        .s_axi_awburst(axi_s_awburst),
        .s_axi_awlock(axi_s_awlock),
        .s_axi_awcache(axi_s_awcache),
        .s_axi_awprot(axi_s_awprot),
        .s_axi_awqos(axi_s_awqos),
        .s_axi_awuser('0),
        .s_axi_awvalid(axi_s_awvalid),
        .s_axi_awready(axi_s_awready),
        .s_axi_wdata(axi_s_wdata),
        .s_axi_wstrb(axi_s_wstrb),
        .s_axi_wlast(axi_s_wlast),
        .s_axi_wuser('0),
        .s_axi_wvalid(axi_s_wvalid),
        .s_axi_wready(axi_s_wready),
        .s_axi_bid(axi_s_bid),
        .s_axi_bresp(axi_s_bresp),
        .s_axi_buser(),
        .s_axi_bvalid(axi_s_bvalid),
        .s_axi_bready(axi_s_bready),
        .s_axi_arid(axi_s_arid),
        .s_axi_araddr(axi_s_araddr),
        .s_axi_arlen(axi_s_arlen),
        .s_axi_arsize(axi_s_arsize),
        .s_axi_arburst(axi_s_arburst),
        .s_axi_arlock(axi_s_arlock),
        .s_axi_arcache(axi_s_arcache),
        .s_axi_arprot(axi_s_arprot),
        .s_axi_arqos(axi_s_arqos),
        .s_axi_aruser('0),
        .s_axi_arvalid(axi_s_arvalid),
        .s_axi_arready(axi_s_arready),
        .s_axi_rid(axi_s_rid),
        .s_axi_rdata(axi_s_rdata),
        .s_axi_rresp(axi_s_rresp),
        .s_axi_rlast(axi_s_rlast),
        .s_axi_ruser(),
        .s_axi_rvalid(axi_s_rvalid),
        .s_axi_rready(axi_s_rready),
        .m_axi_awid(axi_m_awid),
        .m_axi_awaddr(axi_m_awaddr),
        .m_axi_awlen(axi_m_awlen),
        .m_axi_awsize(axi_m_awsize),
        .m_axi_awburst(axi_m_awburst),
        .m_axi_awlock(axi_m_awlock),
        .m_axi_awcache(axi_m_awcache),
        .m_axi_awprot(axi_m_awprot),
        .m_axi_awqos(),
        .m_axi_awregion(),
        .m_axi_awuser(),
        .m_axi_awvalid(axi_m_awvalid),
        .m_axi_awready(axi_m_awready),
        .m_axi_wdata(axi_m_wdata),
        .m_axi_wstrb(axi_m_wstrb),
        .m_axi_wlast(axi_m_wlast),
        .m_axi_wuser(),
        .m_axi_wvalid(axi_m_wvalid),
        .m_axi_wready(axi_m_wready),
        .m_axi_bid(axi_m_bid),
        .m_axi_bresp(axi_m_bresp),
        .m_axi_buser('0),
        .m_axi_bvalid(axi_m_bvalid),
        .m_axi_bready(axi_m_bready),
        .m_axi_arid(axi_m_arid),
        .m_axi_araddr(axi_m_araddr),
        .m_axi_arlen(axi_m_arlen),
        .m_axi_arsize(axi_m_arsize),
        .m_axi_arburst(axi_m_arburst),
        .m_axi_arlock(axi_m_arlock),
        .m_axi_arcache(axi_m_arcache),
        .m_axi_arprot(axi_m_arprot),
        .m_axi_arqos(),
        .m_axi_arregion(),
        .m_axi_aruser(),
        .m_axi_arvalid(axi_m_arvalid),
        .m_axi_arready(axi_m_arready),
        .m_axi_rid(axi_m_rid),
        .m_axi_rdata(axi_m_rdata),
        .m_axi_rresp(axi_m_rresp),
        .m_axi_rlast(axi_m_rlast),
        .m_axi_ruser('0),
        .m_axi_rvalid(axi_m_rvalid),
        .m_axi_rready(axi_m_rready)
    );

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_RAM_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_XBAR_M_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_ram0 (
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_m_awid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(axi_m_awaddr[0 +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_awlen(axi_m_awlen[0 +: 8]),
        .s_axi_awsize(axi_m_awsize[0 +: 3]),
        .s_axi_awburst(axi_m_awburst[0 +: 2]),
        .s_axi_awlock(axi_m_awlock[0]),
        .s_axi_awcache(axi_m_awcache[0 +: 4]),
        .s_axi_awprot(axi_m_awprot[0 +: 3]),
        .s_axi_awvalid(axi_m_awvalid[0]),
        .s_axi_awready(axi_m_awready[0]),
        .s_axi_wdata(axi_m_wdata[0 +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(axi_m_wstrb[0 +: AXI_STRB_WIDTH]),
        .s_axi_wlast(axi_m_wlast[0]),
        .s_axi_wvalid(axi_m_wvalid[0]),
        .s_axi_wready(axi_m_wready[0]),
        .s_axi_bid(ram_bid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_bresp(ram_bresp[0 +: 2]),
        .s_axi_bvalid(ram_bvalid[0]),
        .s_axi_bready(axi_m_bready[0]),
        .s_axi_arid(axi_m_arid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(axi_m_araddr[0 +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_arlen(axi_m_arlen[0 +: 8]),
        .s_axi_arsize(axi_m_arsize[0 +: 3]),
        .s_axi_arburst(axi_m_arburst[0 +: 2]),
        .s_axi_arlock(axi_m_arlock[0]),
        .s_axi_arcache(axi_m_arcache[0 +: 4]),
        .s_axi_arprot(axi_m_arprot[0 +: 3]),
        .s_axi_arvalid(axi_m_arvalid[0]),
        .s_axi_arready(axi_m_arready[0]),
        .s_axi_rid(ram_rid[0 +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(ram_rdata[0 +: AXI_DATA_WIDTH]),
        .s_axi_rresp(ram_rresp[0 +: 2]),
        .s_axi_rlast(ram_rlast[0]),
        .s_axi_rvalid(ram_rvalid[0]),
        .s_axi_rready(axi_m_rready[0])
    );

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_RAM_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_XBAR_M_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) u_ram1 (
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_m_awid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(axi_m_awaddr[AXI_ADDR_WIDTH +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_awlen(axi_m_awlen[8 +: 8]),
        .s_axi_awsize(axi_m_awsize[3 +: 3]),
        .s_axi_awburst(axi_m_awburst[2 +: 2]),
        .s_axi_awlock(axi_m_awlock[1]),
        .s_axi_awcache(axi_m_awcache[4 +: 4]),
        .s_axi_awprot(axi_m_awprot[3 +: 3]),
        .s_axi_awvalid(axi_m_awvalid[1]),
        .s_axi_awready(axi_m_awready[1]),
        .s_axi_wdata(axi_m_wdata[AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(axi_m_wstrb[AXI_STRB_WIDTH +: AXI_STRB_WIDTH]),
        .s_axi_wlast(axi_m_wlast[1]),
        .s_axi_wvalid(axi_m_wvalid[1]),
        .s_axi_wready(axi_m_wready[1]),
        .s_axi_bid(ram_bid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_bresp(ram_bresp[2 +: 2]),
        .s_axi_bvalid(ram_bvalid[1]),
        .s_axi_bready(axi_m_bready[1]),
        .s_axi_arid(axi_m_arid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(axi_m_araddr[AXI_ADDR_WIDTH +: AXI_RAM_ADDR_WIDTH]),
        .s_axi_arlen(axi_m_arlen[8 +: 8]),
        .s_axi_arsize(axi_m_arsize[3 +: 3]),
        .s_axi_arburst(axi_m_arburst[2 +: 2]),
        .s_axi_arlock(axi_m_arlock[1]),
        .s_axi_arcache(axi_m_arcache[4 +: 4]),
        .s_axi_arprot(axi_m_arprot[3 +: 3]),
        .s_axi_arvalid(axi_m_arvalid[1]),
        .s_axi_arready(axi_m_arready[1]),
        .s_axi_rid(ram_rid[AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(ram_rdata[AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_rresp(ram_rresp[2 +: 2]),
        .s_axi_rlast(ram_rlast[1]),
        .s_axi_rvalid(ram_rvalid[1]),
        .s_axi_rready(axi_m_rready[1])
    );

    axil_crossbar #(
        .S_COUNT(1),
        .M_COUNT(3),
        .DATA_WIDTH(AXIL_DATA_WIDTH),
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .STRB_WIDTH(AXIL_STRB_WIDTH),
        .S_ACCEPT(32'd16),
        .M_REGIONS(1),
        .M_BASE_ADDR(AXIL_XBAR_BASE_ADDR),
        .M_ADDR_WIDTH(AXIL_XBAR_ADDR_WIDTH),
        .M_CONNECT_READ(3'b111),
        .M_CONNECT_WRITE(3'b111),
        .M_ISSUE({3{32'd4}})
    ) u_axil_xbar (
        .clk(clk), .rst(rst),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .m_axil_awaddr(axil_m_awaddr),
        .m_axil_awprot(axil_m_awprot),
        .m_axil_awvalid(axil_m_awvalid),
        .m_axil_awready(axil_m_awready),
        .m_axil_wdata(axil_m_wdata),
        .m_axil_wstrb(axil_m_wstrb),
        .m_axil_wvalid(axil_m_wvalid),
        .m_axil_wready(axil_m_wready),
        .m_axil_bresp(axil_m_bresp),
        .m_axil_bvalid(axil_m_bvalid),
        .m_axil_bready(axil_m_bready),
        .m_axil_araddr(axil_m_araddr),
        .m_axil_arprot(axil_m_arprot),
        .m_axil_arvalid(axil_m_arvalid),
        .m_axil_arready(axil_m_arready),
        .m_axil_rdata(axil_m_rdata),
        .m_axil_rresp(axil_m_rresp),
        .m_axil_rvalid(axil_m_rvalid),
        .m_axil_rready(axil_m_rready)
    );

    assign ctrl_awaddr[0 +: AXIL_BLOCK_ADDR_WIDTH] = axil_m_awaddr[0 +: AXIL_BLOCK_ADDR_WIDTH];
    assign ctrl_awaddr[AXIL_BLOCK_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH] = axil_m_awaddr[AXIL_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH];
    assign ctrl_awprot = axil_m_awprot[0 +: DMA_CH_COUNT*3];
    assign ctrl_awvalid = axil_m_awvalid[DMA_CH_COUNT-1:0];
    assign axil_m_awready[0] = ctrl_awready[0];
    assign axil_m_awready[1] = ctrl_awready[1];
    assign ctrl_wdata = axil_m_wdata[0 +: DMA_CH_COUNT*AXIL_DATA_WIDTH];
    assign ctrl_wstrb = axil_m_wstrb[0 +: DMA_CH_COUNT*AXIL_STRB_WIDTH];
    assign ctrl_wvalid = axil_m_wvalid[DMA_CH_COUNT-1:0];
    assign axil_m_wready[0] = ctrl_wready[0];
    assign axil_m_wready[1] = ctrl_wready[1];
    assign ctrl_bready = axil_m_bready[DMA_CH_COUNT-1:0];
    assign ctrl_araddr[0 +: AXIL_BLOCK_ADDR_WIDTH] = axil_m_araddr[0 +: AXIL_BLOCK_ADDR_WIDTH];
    assign ctrl_araddr[AXIL_BLOCK_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH] = axil_m_araddr[AXIL_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH];
    assign ctrl_arprot = axil_m_arprot[0 +: DMA_CH_COUNT*3];
    assign ctrl_arvalid = axil_m_arvalid[DMA_CH_COUNT-1:0];
    assign axil_m_arready[0] = ctrl_arready[0];
    assign axil_m_arready[1] = ctrl_arready[1];
    assign ctrl_rready = axil_m_rready[DMA_CH_COUNT-1:0];

    assign irq_awaddr = axil_m_awaddr[2*AXIL_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH];
    assign irq_awprot = axil_m_awprot[2*3 +: 3];
    assign irq_awvalid = axil_m_awvalid[2];
    assign axil_m_awready[2] = irq_awready;
    assign irq_wdata = axil_m_wdata[2*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH];
    assign irq_wstrb = axil_m_wstrb[2*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH];
    assign irq_wvalid = axil_m_wvalid[2];
    assign axil_m_wready[2] = irq_wready;
    assign irq_bready = axil_m_bready[2];
    assign irq_araddr = axil_m_araddr[2*AXIL_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH];
    assign irq_arprot = axil_m_arprot[2*3 +: 3];
    assign irq_arvalid = axil_m_arvalid[2];
    assign axil_m_arready[2] = irq_arready;
    assign irq_rready = axil_m_rready[2];

    generate
        genvar ch;
        for (ch = 0; ch < DMA_CH_COUNT; ch = ch + 1) begin : g_ctrl
            dma_ctrl_regs #(.CHANNEL_INDEX(ch)) u_ctrl_regs (
                .clk(clk), .rst(rst),
                .s_axil_awaddr(ctrl_awaddr[ch*AXIL_BLOCK_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH]),
                .s_axil_awprot(ctrl_awprot[ch*3 +: 3]),
                .s_axil_awvalid(ctrl_awvalid[ch]),
                .s_axil_awready(ctrl_awready[ch]),
                .s_axil_wdata(ctrl_wdata[ch*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
                .s_axil_wstrb(ctrl_wstrb[ch*AXIL_STRB_WIDTH +: AXIL_STRB_WIDTH]),
                .s_axil_wvalid(ctrl_wvalid[ch]),
                .s_axil_wready(ctrl_wready[ch]),
                .s_axil_bresp(ctrl_bresp[ch*2 +: 2]),
                .s_axil_bvalid(ctrl_bvalid[ch]),
                .s_axil_bready(ctrl_bready[ch]),
                .s_axil_araddr(ctrl_araddr[ch*AXIL_BLOCK_ADDR_WIDTH +: AXIL_BLOCK_ADDR_WIDTH]),
                .s_axil_arprot(ctrl_arprot[ch*3 +: 3]),
                .s_axil_arvalid(ctrl_arvalid[ch]),
                .s_axil_arready(ctrl_arready[ch]),
                .s_axil_rdata(ctrl_rdata[ch*AXIL_DATA_WIDTH +: AXIL_DATA_WIDTH]),
                .s_axil_rresp(ctrl_rresp[ch*2 +: 2]),
                .s_axil_rvalid(ctrl_rvalid[ch]),
                .s_axil_rready(ctrl_rready[ch]),
                .cmd_valid(cmd_valid[ch]),
                .cmd_payload(cmd_payload[ch]),
                .cmd_ready(cmd_ready[ch]),
                .abort_req(abort_req[ch]),
                .busy_i(manager_busy[ch]),
                .completion_valid_i(completion_valid[ch]),
                .completion_i(completion[ch])
            );
        end
    endgenerate

    dma_desc_manager #(.ENABLE_UNALIGNED_PARAM(ENABLE_UNALIGNED_PARAM)) u_desc_manager (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_payload(cmd_payload), .cmd_ready(cmd_ready), .busy(manager_busy),
        .route_req_valid(route_req_valid), .route_req_src(route_req_src), .route_req_dst(route_req_dst),
        .route_req_ready(route_req_ready), .route_dest(route_dest), .route_release(route_release),
        .rd_desc_addr(rd_desc_addr), .rd_desc_len(rd_desc_len), .rd_desc_tag(rd_desc_tag),
        .rd_desc_id(rd_desc_id), .rd_desc_dest(rd_desc_dest), .rd_desc_user(rd_desc_user),
        .rd_desc_valid(rd_desc_valid), .rd_desc_ready(rd_desc_ready),
        .rd_status_tag(rd_status_tag), .rd_status_error(rd_status_error), .rd_status_valid(rd_status_valid),
        .wr_desc_addr(wr_desc_addr), .wr_desc_len(wr_desc_len), .wr_desc_tag(wr_desc_tag),
        .wr_desc_valid(wr_desc_valid), .wr_desc_ready(wr_desc_ready),
        .wr_status_len(wr_status_len), .wr_status_tag(wr_status_tag), .wr_status_id(wr_status_id),
        .wr_status_dest(wr_status_dest), .wr_status_user(wr_status_user),
        .wr_status_error(wr_status_error), .wr_status_valid(wr_status_valid),
        .abort_req(abort_req), .completion_valid(completion_valid), .completion(completion),
        .fault_valid(manager_fault_valid), .fault(manager_fault)
    );

    dma_axis_route_ctrl u_route_ctrl (
        .clk(clk), .rst(rst),
        .route_req_valid(route_req_valid), .route_req_src(route_req_src), .route_req_dst(route_req_dst),
        .route_req_ready(route_req_ready), .route_dest(route_dest), .route_release(route_release),
        .route_active(route_active), .route_matrix(route_matrix), .route_fault_valid(route_fault_valid),
        .route_fault_code(route_fault_code), .route_fault_source(route_fault_source)
    );

    dma_irq_status_ctrl u_irq_status_ctrl (
        .clk(clk), .rst(rst),
        .s_axil_awaddr(irq_awaddr), .s_axil_awprot(irq_awprot), .s_axil_awvalid(irq_awvalid), .s_axil_awready(irq_awready),
        .s_axil_wdata(irq_wdata), .s_axil_wstrb(irq_wstrb), .s_axil_wvalid(irq_wvalid), .s_axil_wready(irq_wready),
        .s_axil_bresp(irq_bresp), .s_axil_bvalid(irq_bvalid), .s_axil_bready(irq_bready),
        .s_axil_araddr(irq_araddr), .s_axil_arprot(irq_arprot), .s_axil_arvalid(irq_arvalid), .s_axil_arready(irq_arready),
        .s_axil_rdata(irq_rdata), .s_axil_rresp(irq_rresp), .s_axil_rvalid(irq_rvalid), .s_axil_rready(irq_rready),
        .completion_valid(completion_valid), .completion(completion), .busy(manager_busy),
        .route_matrix(route_matrix), .route_active(route_active), .fault_valid(combined_fault_valid), .fault(combined_fault),
        .irq_ch(irq_ch), .irq(irq)
    );

    generate
        genvar dma_index;
        for (dma_index = 0; dma_index < DMA_CH_COUNT; dma_index = dma_index + 1) begin : g_dma_ch
            dma_channel_wrap #(.ENABLE_UNALIGNED_PARAM(ENABLE_UNALIGNED_PARAM)) u_dma_ch (
                .clk(clk), .rst(rst),
                .rd_desc_addr(rd_desc_addr[dma_index]), .rd_desc_len(rd_desc_len[dma_index]),
                .rd_desc_tag(rd_desc_tag[dma_index]), .rd_desc_id(rd_desc_id[dma_index]),
                .rd_desc_dest(rd_desc_dest[dma_index]), .rd_desc_user(rd_desc_user[dma_index]),
                .rd_desc_valid(rd_desc_valid[dma_index]), .rd_desc_ready(rd_desc_ready[dma_index]),
                .rd_status_tag(rd_status_tag[dma_index]), .rd_status_error(rd_status_error[dma_index]),
                .rd_status_valid(rd_status_valid[dma_index]),
                .read_axis_tdata(axis_read_tdata[dma_index]), .read_axis_tkeep(axis_read_tkeep[dma_index]),
                .read_axis_tvalid(axis_read_tvalid[dma_index]), .read_axis_tready(axis_read_tready[dma_index]),
                .read_axis_tlast(axis_read_tlast[dma_index]), .read_axis_tid(axis_read_tid[dma_index]),
                .read_axis_tdest(axis_read_tdest[dma_index]), .read_axis_tuser(axis_read_tuser[dma_index]),
                .write_axis_tdata(axis_write_tdata[dma_index]), .write_axis_tkeep(axis_write_tkeep[dma_index]),
                .write_axis_tvalid(axis_write_tvalid[dma_index]), .write_axis_tready(axis_write_tready[dma_index]),
                .write_axis_tlast(axis_write_tlast[dma_index]), .write_axis_tid(axis_write_tid[dma_index]),
                .write_axis_tdest(axis_write_tdest[dma_index]), .write_axis_tuser(axis_write_tuser[dma_index]),
                .wr_desc_addr(wr_desc_addr[dma_index]), .wr_desc_len(wr_desc_len[dma_index]),
                .wr_desc_tag(wr_desc_tag[dma_index]), .wr_desc_valid(wr_desc_valid[dma_index]),
                .wr_desc_ready(wr_desc_ready[dma_index]), .wr_status_len(wr_status_len[dma_index]),
                .wr_status_tag(wr_status_tag[dma_index]), .wr_status_id(wr_status_id[dma_index]),
                .wr_status_dest(wr_status_dest[dma_index]), .wr_status_user(wr_status_user[dma_index]),
                .wr_status_error(wr_status_error[dma_index]), .wr_status_valid(wr_status_valid[dma_index]),
                .m_axi_awid(dma_axi_awid[dma_index]), .m_axi_awaddr(dma_axi_awaddr[dma_index]),
                .m_axi_awlen(dma_axi_awlen[dma_index]), .m_axi_awsize(dma_axi_awsize[dma_index]),
                .m_axi_awburst(dma_axi_awburst[dma_index]), .m_axi_awlock(dma_axi_awlock[dma_index]),
                .m_axi_awcache(dma_axi_awcache[dma_index]), .m_axi_awprot(dma_axi_awprot[dma_index]),
                .m_axi_awvalid(dma_axi_awvalid[dma_index]), .m_axi_awready(dma_axi_awready[dma_index]),
                .m_axi_wdata(dma_axi_wdata[dma_index]), .m_axi_wstrb(dma_axi_wstrb[dma_index]),
                .m_axi_wlast(dma_axi_wlast[dma_index]), .m_axi_wvalid(dma_axi_wvalid[dma_index]),
                .m_axi_wready(dma_axi_wready[dma_index]), .m_axi_bid(dma_axi_bid[dma_index]),
                .m_axi_bresp(dma_axi_bresp[dma_index]), .m_axi_bvalid(dma_axi_bvalid[dma_index]),
                .m_axi_bready(dma_axi_bready[dma_index]), .m_axi_arid(dma_axi_arid[dma_index]),
                .m_axi_araddr(dma_axi_araddr[dma_index]), .m_axi_arlen(dma_axi_arlen[dma_index]),
                .m_axi_arsize(dma_axi_arsize[dma_index]), .m_axi_arburst(dma_axi_arburst[dma_index]),
                .m_axi_arlock(dma_axi_arlock[dma_index]), .m_axi_arcache(dma_axi_arcache[dma_index]),
                .m_axi_arprot(dma_axi_arprot[dma_index]), .m_axi_arvalid(dma_axi_arvalid[dma_index]),
                .m_axi_arready(dma_axi_arready[dma_index]), .m_axi_rid(dma_axi_rid[dma_index]),
                .m_axi_rdata(dma_axi_rdata[dma_index]), .m_axi_rresp(dma_axi_rresp[dma_index]),
                .m_axi_rlast(dma_axi_rlast[dma_index]), .m_axi_rvalid(dma_axi_rvalid[dma_index]),
                .m_axi_rready(dma_axi_rready[dma_index])
            );
        end
    endgenerate

    axis_switch #(
        .S_COUNT(2), .M_COUNT(2), .DATA_WIDTH(AXIS_DATA_WIDTH), .KEEP_ENABLE(1), .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .ID_ENABLE(1), .S_ID_WIDTH(AXIS_ID_WIDTH), .M_ID_WIDTH(AXIS_ID_WIDTH),
        .M_DEST_WIDTH(AXIS_DEST_WIDTH), .S_DEST_WIDTH(AXIS_DEST_WIDTH), .USER_ENABLE(1), .USER_WIDTH(AXIS_USER_WIDTH),
        .M_BASE(0), .M_TOP(0), .M_CONNECT(4'b1111), .UPDATE_TID(0),
        .S_REG_TYPE(0), .M_REG_TYPE(2), .ARB_TYPE_ROUND_ROBIN(1), .ARB_LSB_HIGH_PRIORITY(1)
    ) u_axis_switch (
        .clk(clk), .rst(rst),
        .s_axis_tdata(axis_read_tdata), .s_axis_tkeep(axis_read_tkeep), .s_axis_tvalid(axis_read_tvalid),
        .s_axis_tready(axis_read_tready), .s_axis_tlast(axis_read_tlast), .s_axis_tid(axis_read_tid),
        .s_axis_tdest(axis_read_tdest), .s_axis_tuser(axis_read_tuser),
        .m_axis_tdata(axis_write_tdata), .m_axis_tkeep(axis_write_tkeep), .m_axis_tvalid(axis_write_tvalid),
        .m_axis_tready(axis_write_tready), .m_axis_tlast(axis_write_tlast), .m_axis_tid(axis_write_tid),
        .m_axis_tdest(axis_write_tdest), .m_axis_tuser(axis_write_tuser)
    );

    initial begin
        if (DMA_CH_COUNT != 2 || EXT_AXI_MASTER_COUNT != 2 || AXI_MASTER_COUNT != 4 || AXI_SLAVE_COUNT != 2) begin
            $error("AXI DMA subsystem V1.0 requires fixed channel and master counts");
            $finish;
        end
        if (AXI_DATA_WIDTH != AXIS_DATA_WIDTH || (AXI_DATA_WIDTH % 8) != 0) begin
            $error("AXI and AXIS data widths must match and be byte aligned");
            $finish;
        end
        if (AXI_XBAR_M_ID_WIDTH != AXI_ID_WIDTH + $clog2(AXI_MASTER_COUNT)) begin
            $error("AXI crossbar ID width configuration is inconsistent");
            $finish;
        end
        if (AXIS_FIFO_DEPTH_BEATS == 0 || AXIS_DEST_WIDTH < $clog2(AXI_SLAVE_COUNT)) begin
            $error("AXIS FIFO or DEST width configuration is invalid");
            $finish;
        end
    end

endmodule

`default_nettype wire
