`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module dma_channel_wrap #(
    parameter bit ENABLE_UNALIGNED_PARAM = ENABLE_UNALIGNED
) (
    input wire clk,
    input wire rst,

    input wire [AXI_ADDR_WIDTH-1:0] rd_desc_addr,
    input wire [LEN_WIDTH-1:0]      rd_desc_len,
    input wire [TAG_WIDTH-1:0]      rd_desc_tag,
    input wire [AXIS_ID_WIDTH-1:0]  rd_desc_id,
    input wire [AXIS_DEST_WIDTH-1:0] rd_desc_dest,
    input wire [AXIS_USER_WIDTH-1:0] rd_desc_user,
    input wire                       rd_desc_valid,
    output wire                      rd_desc_ready,
    output wire [TAG_WIDTH-1:0]      rd_status_tag,
    output wire [3:0]                rd_status_error,
    output wire                      rd_status_valid,

    output wire [AXIS_DATA_WIDTH-1:0] read_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0] read_axis_tkeep,
    output wire                       read_axis_tvalid,
    input wire                        read_axis_tready,
    output wire                       read_axis_tlast,
    output wire [AXIS_ID_WIDTH-1:0]   read_axis_tid,
    output wire [AXIS_DEST_WIDTH-1:0] read_axis_tdest,
    output wire [AXIS_USER_WIDTH-1:0] read_axis_tuser,

    input wire [AXIS_DATA_WIDTH-1:0] write_axis_tdata,
    input wire [AXIS_KEEP_WIDTH-1:0] write_axis_tkeep,
    input wire                       write_axis_tvalid,
    output wire                      write_axis_tready,
    input wire                       write_axis_tlast,
    input wire [AXIS_ID_WIDTH-1:0]   write_axis_tid,
    input wire [AXIS_DEST_WIDTH-1:0] write_axis_tdest,
    input wire [AXIS_USER_WIDTH-1:0] write_axis_tuser,

    input wire [AXI_ADDR_WIDTH-1:0] wr_desc_addr,
    input wire [LEN_WIDTH-1:0]      wr_desc_len,
    input wire [TAG_WIDTH-1:0]      wr_desc_tag,
    input wire                      wr_desc_valid,
    output wire                     wr_desc_ready,
    output wire [LEN_WIDTH-1:0]     wr_status_len,
    output wire [TAG_WIDTH-1:0]     wr_status_tag,
    output wire [AXIS_ID_WIDTH-1:0] wr_status_id,
    output wire [AXIS_DEST_WIDTH-1:0] wr_status_dest,
    output wire [AXIS_USER_WIDTH-1:0] wr_status_user,
    output wire [3:0]               wr_status_error,
    output wire                     wr_status_valid,

    output wire [AXI_ID_WIDTH-1:0]   m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0]                m_axi_awlen,
    output wire [2:0]                m_axi_awsize,
    output wire [1:0]                m_axi_awburst,
    output wire                      m_axi_awlock,
    output wire [3:0]                m_axi_awcache,
    output wire [2:0]                m_axi_awprot,
    output wire                      m_axi_awvalid,
    input wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0] m_axi_wstrb,
    output wire                      m_axi_wlast,
    output wire                      m_axi_wvalid,
    input wire                       m_axi_wready,
    input wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input wire [1:0]                 m_axi_bresp,
    input wire                       m_axi_bvalid,
    output wire                      m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]   m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output wire                      m_axi_arlock,
    output wire [3:0]                m_axi_arcache,
    output wire [2:0]                m_axi_arprot,
    output wire                      m_axi_arvalid,
    input wire                       m_axi_arready,
    input wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input wire [1:0]                 m_axi_rresp,
    input wire                       m_axi_rlast,
    input wire                       m_axi_rvalid,
    output wire                      m_axi_rready
);

    wire [AXIS_DATA_WIDTH-1:0] dma_read_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] dma_read_tkeep;
    wire dma_read_tvalid;
    wire dma_read_tready;
    wire dma_read_tlast;
    wire [AXIS_ID_WIDTH-1:0] dma_read_tid;
    wire [AXIS_DEST_WIDTH-1:0] dma_read_tdest;
    wire [AXIS_USER_WIDTH-1:0] dma_read_tuser;

    wire [AXIS_DATA_WIDTH-1:0] dma_write_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] dma_write_tkeep;
    wire dma_write_tvalid;
    wire dma_write_tready;
    wire dma_write_tlast;
    wire [AXIS_ID_WIDTH-1:0] dma_write_tid;
    wire [AXIS_DEST_WIDTH-1:0] dma_write_tdest;
    wire [AXIS_USER_WIDTH-1:0] dma_write_tuser;

    wire [AXIS_DATA_WIDTH-1:0] read_fifo_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] read_fifo_tkeep;
    wire read_fifo_tvalid;
    wire read_fifo_tready;
    wire read_fifo_tlast;
    wire [AXIS_ID_WIDTH-1:0] read_fifo_tid;
    wire [AXIS_DEST_WIDTH-1:0] read_fifo_tdest;
    wire [AXIS_USER_WIDTH-1:0] read_fifo_tuser;

    wire [AXIS_DATA_WIDTH-1:0] write_fifo_tdata;
    wire [AXIS_KEEP_WIDTH-1:0] write_fifo_tkeep;
    wire write_fifo_tvalid;
    wire write_fifo_tready;
    wire write_fifo_tlast;
    wire [AXIS_ID_WIDTH-1:0] write_fifo_tid;
    wire [AXIS_DEST_WIDTH-1:0] write_fifo_tdest;
    wire [AXIS_USER_WIDTH-1:0] write_fifo_tuser;

    assign read_axis_tdata = read_fifo_tdata;
    assign read_axis_tkeep = read_fifo_tkeep;
    assign read_axis_tvalid = read_fifo_tvalid;
    assign read_fifo_tready = read_axis_tready;
    assign read_axis_tlast = read_fifo_tlast;
    assign read_axis_tid = read_fifo_tid;
    assign read_axis_tdest = read_fifo_tdest;
    assign read_axis_tuser = read_fifo_tuser;

    assign write_fifo_tdata = write_axis_tdata;
    assign write_fifo_tkeep = write_axis_tkeep;
    assign write_fifo_tvalid = write_axis_tvalid;
    assign write_axis_tready = write_fifo_tready;
    assign write_fifo_tlast = write_axis_tlast;
    assign write_fifo_tid = write_axis_tid;
    assign write_fifo_tdest = write_axis_tdest;
    assign write_fifo_tuser = write_axis_tuser;

    axis_fifo #(
        .DEPTH(AXIS_FIFO_VENDOR_DEPTH),
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .LAST_ENABLE(1),
        .ID_ENABLE(1),
        .ID_WIDTH(AXIS_ID_WIDTH),
        .DEST_ENABLE(1),
        .DEST_WIDTH(AXIS_DEST_WIDTH),
        .USER_ENABLE(1),
        .USER_WIDTH(AXIS_USER_WIDTH),
        .FRAME_FIFO(0),
        .DROP_OVERSIZE_FRAME(0),
        .DROP_BAD_FRAME(0),
        .DROP_WHEN_FULL(0),
        .MARK_WHEN_FULL(0),
        .PAUSE_ENABLE(0)
    ) u_read_fifo (
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
        .m_axis_tdata(read_fifo_tdata),
        .m_axis_tkeep(read_fifo_tkeep),
        .m_axis_tvalid(read_fifo_tvalid),
        .m_axis_tready(read_fifo_tready),
        .m_axis_tlast(read_fifo_tlast),
        .m_axis_tid(read_fifo_tid),
        .m_axis_tdest(read_fifo_tdest),
        .m_axis_tuser(read_fifo_tuser),
        .pause_req(1'b0),
        .pause_ack(),
        .status_depth(),
        .status_depth_commit(),
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    axis_fifo #(
        .DEPTH(AXIS_FIFO_VENDOR_DEPTH),
        .DATA_WIDTH(AXIS_DATA_WIDTH),
        .KEEP_ENABLE(1),
        .KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .LAST_ENABLE(1),
        .ID_ENABLE(1),
        .ID_WIDTH(AXIS_ID_WIDTH),
        .DEST_ENABLE(1),
        .DEST_WIDTH(AXIS_DEST_WIDTH),
        .USER_ENABLE(1),
        .USER_WIDTH(AXIS_USER_WIDTH),
        .FRAME_FIFO(0),
        .DROP_OVERSIZE_FRAME(0),
        .DROP_BAD_FRAME(0),
        .DROP_WHEN_FULL(0),
        .MARK_WHEN_FULL(0),
        .PAUSE_ENABLE(0)
    ) u_write_fifo (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(write_fifo_tdata),
        .s_axis_tkeep(write_fifo_tkeep),
        .s_axis_tvalid(write_fifo_tvalid),
        .s_axis_tready(write_fifo_tready),
        .s_axis_tlast(write_fifo_tlast),
        .s_axis_tid(write_fifo_tid),
        .s_axis_tdest(write_fifo_tdest),
        .s_axis_tuser(write_fifo_tuser),
        .m_axis_tdata(dma_write_tdata),
        .m_axis_tkeep(dma_write_tkeep),
        .m_axis_tvalid(dma_write_tvalid),
        .m_axis_tready(dma_write_tready),
        .m_axis_tlast(dma_write_tlast),
        .m_axis_tid(dma_write_tid),
        .m_axis_tdest(dma_write_tdest),
        .m_axis_tuser(dma_write_tuser),
        .pause_req(1'b0),
        .pause_ack(),
        .status_depth(),
        .status_depth_commit(),
        .status_overflow(),
        .status_bad_frame(),
        .status_good_frame()
    );

    axi_dma #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_KEEP_ENABLE(1),
        .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
        .AXIS_LAST_ENABLE(1),
        .AXIS_ID_ENABLE(1),
        .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
        .AXIS_DEST_ENABLE(1),
        .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
        .AXIS_USER_ENABLE(1),
        .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .ENABLE_SG(ENABLE_SG),
        .ENABLE_UNALIGNED(ENABLE_UNALIGNED_PARAM)
    ) u_dma (
        .clk(clk),
        .rst(rst),
        .s_axis_read_desc_addr(rd_desc_addr),
        .s_axis_read_desc_len(rd_desc_len),
        .s_axis_read_desc_tag(rd_desc_tag),
        .s_axis_read_desc_id(rd_desc_id),
        .s_axis_read_desc_dest(rd_desc_dest),
        .s_axis_read_desc_user(rd_desc_user),
        .s_axis_read_desc_valid(rd_desc_valid),
        .s_axis_read_desc_ready(rd_desc_ready),
        .m_axis_read_desc_status_tag(rd_status_tag),
        .m_axis_read_desc_status_error(rd_status_error),
        .m_axis_read_desc_status_valid(rd_status_valid),
        .m_axis_read_data_tdata(dma_read_tdata),
        .m_axis_read_data_tkeep(dma_read_tkeep),
        .m_axis_read_data_tvalid(dma_read_tvalid),
        .m_axis_read_data_tready(dma_read_tready),
        .m_axis_read_data_tlast(dma_read_tlast),
        .m_axis_read_data_tid(dma_read_tid),
        .m_axis_read_data_tdest(dma_read_tdest),
        .m_axis_read_data_tuser(dma_read_tuser),
        .s_axis_write_desc_addr(wr_desc_addr),
        .s_axis_write_desc_len(wr_desc_len),
        .s_axis_write_desc_tag(wr_desc_tag),
        .s_axis_write_desc_valid(wr_desc_valid),
        .s_axis_write_desc_ready(wr_desc_ready),
        .m_axis_write_desc_status_len(wr_status_len),
        .m_axis_write_desc_status_tag(wr_status_tag),
        .m_axis_write_desc_status_id(wr_status_id),
        .m_axis_write_desc_status_dest(wr_status_dest),
        .m_axis_write_desc_status_user(wr_status_user),
        .m_axis_write_desc_status_error(wr_status_error),
        .m_axis_write_desc_status_valid(wr_status_valid),
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

endmodule

`default_nettype wire
