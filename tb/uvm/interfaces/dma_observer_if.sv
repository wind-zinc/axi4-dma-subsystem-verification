`timescale 1ns/1ps

/*
 * Passive observation interface for the end-to-end DMA checker.
 *
 * It does not drive the DUT.  tb_uvm_top connects it to the accepted DMA
 * descriptor, AXI memory traffic, and completion push point.
 */
interface dma_observer_if #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int LEN_WIDTH  = 20,
    parameter int TAG_WIDTH  = 8
)(
    input logic clk,
    input logic rst
);

    localparam int STRB_WIDTH = DATA_WIDTH/8;

    logic [ADDR_WIDTH-1:0] desc_src_addr;
    logic [ADDR_WIDTH-1:0] desc_dst_addr;
    logic [LEN_WIDTH-1:0]  desc_length;
    logic [TAG_WIDTH-1:0]  desc_tag;
    logic                  desc_valid;
    logic                  desc_ready;

    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arvalid;
    logic                  arready;

    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awvalid;
    logic                  awready;

    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wlast;
    logic                  wvalid;
    logic                  wready;

    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;

    logic [TAG_WIDTH-1:0] completion_tag;
    logic [LEN_WIDTH-1:0] completion_length;
    logic [2:0]           completion_flags;
    logic [3:0]           completion_write_error;
    logic [3:0]           completion_read_error;
    logic                 completion_valid;
    logic                 completion_ready;

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst;
        input desc_src_addr, desc_dst_addr, desc_length, desc_tag;
        input desc_valid, desc_ready;
        input araddr, arlen, arsize, arburst, arvalid, arready;
        input awaddr, awlen, awsize, awburst, awvalid, awready;
        input wdata, wstrb, wlast, wvalid, wready;
        input bresp, bvalid, bready;
        input rdata, rresp, rlast, rvalid, rready;
        input completion_tag, completion_length, completion_flags;
        input completion_write_error, completion_read_error;
        input completion_valid, completion_ready;
    endclocking

endinterface
