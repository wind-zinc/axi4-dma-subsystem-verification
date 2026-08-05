`default_nettype none
`timescale 1ns / 1ps

// Vendor-independent safety net for one AXI4 memory-side interface.  AMD VIP
// remains the primary protocol checker; these assertions keep the most useful
// rules visible in project-owned source and in assertion coverage.
module dma_subsys_axi_sva #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ID_WIDTH = 6
) (
    input logic                  clk,
    input logic                  aresetn,
    input logic [ID_WIDTH-1:0]   awid,
    input logic [ADDR_WIDTH-1:0] awaddr,
    input logic [7:0]            awlen,
    input logic [2:0]            awsize,
    input logic [1:0]            awburst,
    input logic                  awvalid,
    input logic                  awready,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH/8-1:0] wstrb,
    input logic                  wlast,
    input logic                  wvalid,
    input logic                  wready,
    input logic [ID_WIDTH-1:0]   bid,
    input logic [1:0]            bresp,
    input logic                  bvalid,
    input logic                  bready,
    input logic [ID_WIDTH-1:0]   arid,
    input logic [ADDR_WIDTH-1:0] araddr,
    input logic [7:0]            arlen,
    input logic [2:0]            arsize,
    input logic [1:0]            arburst,
    input logic                  arvalid,
    input logic                  arready,
    input logic [ID_WIDTH-1:0]   rid,
    input logic [DATA_WIDTH-1:0] rdata,
    input logic [1:0]            rresp,
    input logic                  rlast,
    input logic                  rvalid,
    input logic                  rready
);

    localparam int unsigned MAX_SIZE = $clog2(DATA_WIDTH / 8);

    function automatic bit incr_stays_in_4k(
        input logic [ADDR_WIDTH-1:0] address,
        input logic [7:0]            length,
        input logic [2:0]            size
    );
        longint unsigned transfer_bytes;
        longint unsigned end_offset;

        transfer_bytes = (longint'(length) + 1) << size;
        end_offset = longint'(address[11:0]) + transfer_bytes;
        return end_offset <= 4096;
    endfunction

    function automatic bit wrap_length_is_legal(input logic [7:0] length);
        return length inside {8'd1, 8'd3, 8'd7, 8'd15};
    endfunction

    a_reset_clears_requests: assert property (
        @(posedge clk) !aresetn |=> (!awvalid && !wvalid && !arvalid))
        else $error("[DMA_AXI_SVA] request VALID remained high after reset");

    a_aw_payload_stable: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid && !awready |=> awvalid
            && $stable({awid, awaddr, awlen, awsize, awburst}))
        else $error("[DMA_AXI_SVA] AW payload changed while stalled");

    a_w_payload_stable: assert property (
        @(posedge clk) disable iff (!aresetn)
        wvalid && !wready |=> wvalid
            && $stable({wdata, wstrb, wlast}))
        else $error("[DMA_AXI_SVA] W payload changed while stalled");

    a_ar_payload_stable: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid && !arready |=> arvalid
            && $stable({arid, araddr, arlen, arsize, arburst}))
        else $error("[DMA_AXI_SVA] AR payload changed while stalled");

    a_b_payload_stable: assert property (
        @(posedge clk) disable iff (!aresetn)
        bvalid && !bready |=> bvalid && $stable({bid, bresp}))
        else $error("[DMA_AXI_SVA] B payload changed while stalled");

    a_r_payload_stable: assert property (
        @(posedge clk) disable iff (!aresetn)
        rvalid && !rready |=> rvalid
            && $stable({rid, rdata, rresp, rlast}))
        else $error("[DMA_AXI_SVA] R payload changed while stalled");

    a_aw_known_when_valid: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid |-> !$isunknown({awid, awaddr, awlen, awsize,
                                awburst, awready}))
        else $error("[DMA_AXI_SVA] X/Z on valid AW channel");

    a_w_known_when_valid: assert property (
        @(posedge clk) disable iff (!aresetn)
        wvalid |-> !$isunknown({wdata, wstrb, wlast, wready}))
        else $error("[DMA_AXI_SVA] X/Z on valid W channel");

    a_ar_known_when_valid: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid |-> !$isunknown({arid, araddr, arlen, arsize,
                                arburst, arready}))
        else $error("[DMA_AXI_SVA] X/Z on valid AR channel");

    a_b_known_when_valid: assert property (
        @(posedge clk) disable iff (!aresetn)
        bvalid |-> !$isunknown({bid, bresp, bready}))
        else $error("[DMA_AXI_SVA] X/Z on valid B channel");

    a_r_known_when_valid: assert property (
        @(posedge clk) disable iff (!aresetn)
        rvalid |-> !$isunknown({rid, rdata, rresp, rlast, rready}))
        else $error("[DMA_AXI_SVA] X/Z on valid R channel");

    a_aw_size_legal: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid |-> (awsize <= MAX_SIZE))
        else $error("[DMA_AXI_SVA] AWSIZE exceeds data bus width");

    a_ar_size_legal: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid |-> (arsize <= MAX_SIZE))
        else $error("[DMA_AXI_SVA] ARSIZE exceeds data bus width");

    a_aw_burst_not_reserved: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid |-> (awburst != 2'b11))
        else $error("[DMA_AXI_SVA] reserved AWBURST encoding");

    a_ar_burst_not_reserved: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid |-> (arburst != 2'b11))
        else $error("[DMA_AXI_SVA] reserved ARBURST encoding");

    a_aw_fixed_length: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid && (awburst == 2'b00) |-> (awlen <= 8'd15))
        else $error("[DMA_AXI_SVA] FIXED write burst exceeds 16 beats");

    a_ar_fixed_length: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid && (arburst == 2'b00) |-> (arlen <= 8'd15))
        else $error("[DMA_AXI_SVA] FIXED read burst exceeds 16 beats");

    a_aw_wrap_length: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid && (awburst == 2'b10) |-> wrap_length_is_legal(awlen))
        else $error("[DMA_AXI_SVA] illegal WRAP write length");

    a_ar_wrap_length: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid && (arburst == 2'b10) |-> wrap_length_is_legal(arlen))
        else $error("[DMA_AXI_SVA] illegal WRAP read length");

    a_aw_incr_4k_boundary: assert property (
        @(posedge clk) disable iff (!aresetn)
        awvalid && awready && (awburst == 2'b01)
            |-> incr_stays_in_4k(awaddr, awlen, awsize))
        else $error("[DMA_AXI_SVA] INCR write crosses a 4-KiB boundary");

    a_ar_incr_4k_boundary: assert property (
        @(posedge clk) disable iff (!aresetn)
        arvalid && arready && (arburst == 2'b01)
            |-> incr_stays_in_4k(araddr, arlen, arsize))
        else $error("[DMA_AXI_SVA] INCR read crosses a 4-KiB boundary");

    c_aw_backpressure: cover property (
        @(posedge clk) disable iff (!aresetn) awvalid && !awready);
    c_w_backpressure: cover property (
        @(posedge clk) disable iff (!aresetn) wvalid && !wready);
    c_ar_backpressure: cover property (
        @(posedge clk) disable iff (!aresetn) arvalid && !arready);
    c_fixed_burst: cover property (
        @(posedge clk) disable iff (!aresetn)
        (awvalid && awready && awburst == 2'b00)
        || (arvalid && arready && arburst == 2'b00));
    c_wrap_burst: cover property (
        @(posedge clk) disable iff (!aresetn)
        (awvalid && awready && awburst == 2'b10)
        || (arvalid && arready && arburst == 2'b10));

endmodule

`default_nettype wire
