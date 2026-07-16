/*
 * AXI-Lite controlled memory-to-memory AXI DMA subsystem
 *
 * Data path:
 *   AXI memory read -> axi_dma_rd -> axis_fifo -> axi_dma_wr -> AXI memory write
 *
 * Control path:
 *   AXI-Lite -> dma_ctrl_regs -> read/write descriptors -> axi_dma
 *
 * The external AXI4 interface is a master interface and should be connected
 * to an AXI RAM, DDR controller, AXI VIP slave, or interconnect in the TB/system.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module axi_dma_subsystem #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 8,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),

    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 16,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_MAX_BURST_LEN = 16,

    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH > 8),
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    parameter AXIS_LAST_ENABLE = 1,
    parameter AXIS_ID_ENABLE = 0,
    parameter AXIS_ID_WIDTH = 8,
    parameter AXIS_DEST_ENABLE = 0,
    parameter AXIS_DEST_WIDTH = 8,
    parameter AXIS_USER_ENABLE = 1,
    parameter AXIS_USER_WIDTH = 1,
    parameter AXIS_FIFO_DEPTH = 16,

    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8,
    parameter ENABLE_SG = 0,
    parameter ENABLE_UNALIGNED = 0
)(
    input  wire                         clk,
    input  wire                         rst,

    /* AXI-Lite control slave interface */
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]   s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,

    /* AXI4 memory master interface */
    output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire                         m_axi_awlock,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arlock,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,

    output wire                         irq
);

/* Descriptor wires between controller and DMA */
wire [AXI_ADDR_WIDTH-1:0] read_desc_addr;
wire [LEN_WIDTH-1:0] read_desc_len;
wire [TAG_WIDTH-1:0] read_desc_tag;
wire read_desc_valid;
wire read_desc_ready;

wire [AXI_ADDR_WIDTH-1:0] write_desc_addr;
wire [LEN_WIDTH-1:0] write_desc_len;
wire [TAG_WIDTH-1:0] write_desc_tag;
wire write_desc_valid;
wire write_desc_ready;

/* DMA completion status */
wire [TAG_WIDTH-1:0] read_status_tag;
wire [3:0] read_status_error;
wire read_status_valid;

wire [LEN_WIDTH-1:0] write_status_len;
wire [TAG_WIDTH-1:0] write_status_tag;
wire [AXIS_ID_WIDTH-1:0] write_status_id;
wire [AXIS_DEST_WIDTH-1:0] write_status_dest;
wire [AXIS_USER_WIDTH-1:0] write_status_user;
wire [3:0] write_status_error;
wire write_status_valid;

/* AXI-Stream from DMA read engine to FIFO */
wire [AXIS_DATA_WIDTH-1:0] dma_read_tdata;
wire [AXIS_KEEP_WIDTH-1:0] dma_read_tkeep;
wire dma_read_tvalid;
wire dma_read_tready;
wire dma_read_tlast;
wire [AXIS_ID_WIDTH-1:0] dma_read_tid;
wire [AXIS_DEST_WIDTH-1:0] dma_read_tdest;
wire [AXIS_USER_WIDTH-1:0] dma_read_tuser;

/* AXI-Stream from FIFO to DMA write engine */
wire [AXIS_DATA_WIDTH-1:0] dma_write_tdata;
wire [AXIS_KEEP_WIDTH-1:0] dma_write_tkeep;
wire dma_write_tvalid;
wire dma_write_tready;
wire dma_write_tlast;
wire [AXIS_ID_WIDTH-1:0] dma_write_tid;
wire [AXIS_DEST_WIDTH-1:0] dma_write_tdest;
wire [AXIS_USER_WIDTH-1:0] dma_write_tuser;

dma_ctrl_regs #(
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXIL_STRB_WIDTH(AXIL_STRB_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
)
dma_ctrl_regs_inst (
    .clk(clk),
    .rst(rst),

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

    .read_desc_addr(read_desc_addr),
    .read_desc_len(read_desc_len),
    .read_desc_tag(read_desc_tag),
    .read_desc_valid(read_desc_valid),
    .read_desc_ready(read_desc_ready),

    .write_desc_addr(write_desc_addr),
    .write_desc_len(write_desc_len),
    .write_desc_tag(write_desc_tag),
    .write_desc_valid(write_desc_valid),
    .write_desc_ready(write_desc_ready),

    .read_status_tag(read_status_tag),
    .read_status_error(read_status_error),
    .read_status_valid(read_status_valid),

    .write_status_tag(write_status_tag),
    .write_status_error(write_status_error),
    .write_status_valid(write_status_valid),

    .irq(irq)
);

axis_fifo #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .ID_WIDTH(AXIS_ID_WIDTH),
    .DEST_WIDTH(AXIS_DEST_WIDTH),
    .USER_WIDTH(AXIS_USER_WIDTH),
    .DEPTH(AXIS_FIFO_DEPTH)
)
axis_fifo_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(dma_read_tdata),
    .s_axis_tkeep(dma_read_tkeep),
    .s_axis_tvalid(dma_read_tvalid),
    .s_axis_tready(dma_read_tready),
    .s_axis_tlast(dma_read_tlast),
    .s_axis_tid(dma_read_tid),
    .s_axis_tdest(dma_read_tdest),
    .s_axis_tuser(dma_read_tuser),

    .m_axis_tdata(dma_write_tdata),
    .m_axis_tkeep(dma_write_tkeep),
    .m_axis_tvalid(dma_write_tvalid),
    .m_axis_tready(dma_write_tready),
    .m_axis_tlast(dma_write_tlast),
    .m_axis_tid(dma_write_tid),
    .m_axis_tdest(dma_write_tdest),
    .m_axis_tuser(dma_write_tuser)
);

axi_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
)
axi_dma_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_read_desc_addr(read_desc_addr),
    .s_axis_read_desc_len(read_desc_len),
    .s_axis_read_desc_tag(read_desc_tag),
    .s_axis_read_desc_id({AXIS_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_dest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_user({AXIS_USER_WIDTH{1'b0}}),
    .s_axis_read_desc_valid(read_desc_valid),
    .s_axis_read_desc_ready(read_desc_ready),

    .m_axis_read_desc_status_tag(read_status_tag),
    .m_axis_read_desc_status_error(read_status_error),
    .m_axis_read_desc_status_valid(read_status_valid),

    .m_axis_read_data_tdata(dma_read_tdata),
    .m_axis_read_data_tkeep(dma_read_tkeep),
    .m_axis_read_data_tvalid(dma_read_tvalid),
    .m_axis_read_data_tready(dma_read_tready),
    .m_axis_read_data_tlast(dma_read_tlast),
    .m_axis_read_data_tid(dma_read_tid),
    .m_axis_read_data_tdest(dma_read_tdest),
    .m_axis_read_data_tuser(dma_read_tuser),

    .s_axis_write_desc_addr(write_desc_addr),
    .s_axis_write_desc_len(write_desc_len),
    .s_axis_write_desc_tag(write_desc_tag),
    .s_axis_write_desc_valid(write_desc_valid),
    .s_axis_write_desc_ready(write_desc_ready),

    .m_axis_write_desc_status_len(write_status_len),
    .m_axis_write_desc_status_tag(write_status_tag),
    .m_axis_write_desc_status_id(write_status_id),
    .m_axis_write_desc_status_dest(write_status_dest),
    .m_axis_write_desc_status_user(write_status_user),
    .m_axis_write_desc_status_error(write_status_error),
    .m_axis_write_desc_status_valid(write_status_valid),

    .s_axis_write_data_tdata(dma_write_tdata),
    .s_axis_write_data_tkeep(dma_write_tkeep),
    .s_axis_write_data_tvalid(dma_write_tvalid),
    .s_axis_write_data_tready(dma_write_tready),
    .s_axis_write_data_tlast(dma_write_tlast),
    .s_axis_write_data_tid(dma_write_tid),
    .s_axis_write_data_tdest(dma_write_tdest),
    .s_axis_write_data_tuser(dma_write_tuser),

    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    .read_enable(1'b1),
    .write_enable(1'b1),
    .write_abort(1'b0)
);

initial begin
    if (AXIS_DATA_WIDTH != AXI_DATA_WIDTH) begin
        $error("axi_dma_subsystem first version requires AXIS_DATA_WIDTH = AXI_DATA_WIDTH");
        $finish;
    end
end

endmodule

`resetall
