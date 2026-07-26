`timescale 1ns/1ps

/*
 * AXI-Lite protocol properties on the UVM-master-facing control interface.
 * This checker is instantiated in tb_uvm_top instead of bound inside the
 * DUT because the testbench owns the legal request-stall gate.
 */
module axi_dma_axil_sva #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst,

    input logic [ADDR_WIDTH-1:0] awaddr,
    input logic [2:0]            awprot,
    input logic                  awvalid,
    input logic                  awready,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH/8-1:0] wstrb,
    input logic                  wvalid,
    input logic                  wready,
    input logic [1:0]            bresp,
    input logic                  bvalid,
    input logic                  bready,
    input logic [ADDR_WIDTH-1:0] araddr,
    input logic [2:0]            arprot,
    input logic                  arvalid,
    input logic                  arready,
    input logic [DATA_WIDTH-1:0] rdata,
    input logic [1:0]            rresp,
    input logic                  rvalid,
    input logic                  rready
);

    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    ap_axil_aw_stable: assert property (
        awvalid && !awready |=>
        awvalid && $stable({awaddr, awprot}));
    ap_axil_w_stable: assert property (
        wvalid && !wready |=>
        wvalid && $stable({wdata, wstrb}));
    ap_axil_ar_stable: assert property (
        arvalid && !arready |=>
        arvalid && $stable({araddr, arprot}));
    ap_axil_b_stable: assert property (
        bvalid && !bready |=> bvalid && $stable(bresp));
    ap_axil_r_stable: assert property (
        rvalid && !rready |=>
        rvalid && $stable({rdata, rresp}));

    /* Explicit witnesses distinguish real success from vacuous success. */
    cp_axil_aw_stable_success: cover property (
        (awvalid && !awready) ##1
        (awvalid && $stable({awaddr, awprot})));
    cp_axil_w_stable_success: cover property (
        (wvalid && !wready) ##1
        (wvalid && $stable({wdata, wstrb})));
    cp_axil_ar_stable_success: cover property (
        (arvalid && !arready) ##1
        (arvalid && $stable({araddr, arprot})));
    cp_axil_b_stable_success: cover property (
        (bvalid && !bready) ##1
        (bvalid && $stable(bresp)));
    cp_axil_r_stable_success: cover property (
        (rvalid && !rready) ##1
        (rvalid && $stable({rdata, rresp})));

endmodule


/* AXI memory-master protocol properties at the subsystem boundary. */
module axi_dma_bus_sva #(
    parameter int AXI_ADDR_WIDTH  = 16,
    parameter int AXI_DATA_WIDTH  = 32,
    parameter int AXI_ID_WIDTH    = 8
)(
    input logic clk,
    input logic rst,

    input logic [AXI_ID_WIDTH-1:0]   m_axi_awid,
    input logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    input logic [7:0]                m_axi_awlen,
    input logic [2:0]                m_axi_awsize,
    input logic [1:0]                m_axi_awburst,
    input logic                      m_axi_awlock,
    input logic [3:0]                m_axi_awcache,
    input logic [2:0]                m_axi_awprot,
    input logic                      m_axi_awvalid,
    input logic                      m_axi_awready,
    input logic [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    input logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    input logic                      m_axi_wlast,
    input logic                      m_axi_wvalid,
    input logic                      m_axi_wready,
    input logic [AXI_ID_WIDTH-1:0]   m_axi_bid,
    input logic [1:0]                m_axi_bresp,
    input logic                      m_axi_bvalid,
    input logic                      m_axi_bready,
    input logic [AXI_ID_WIDTH-1:0]   m_axi_arid,
    input logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    input logic [7:0]                m_axi_arlen,
    input logic [2:0]                m_axi_arsize,
    input logic [1:0]                m_axi_arburst,
    input logic                      m_axi_arlock,
    input logic [3:0]                m_axi_arcache,
    input logic [2:0]                m_axi_arprot,
    input logic                      m_axi_arvalid,
    input logic                      m_axi_arready,
    input logic [AXI_ID_WIDTH-1:0]   m_axi_rid,
    input logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input logic [1:0]                m_axi_rresp,
    input logic                      m_axi_rlast,
    input logic                      m_axi_rvalid,
    input logic                      m_axi_rready
);

    localparam int AXI_SIZE = $clog2(AXI_DATA_WIDTH/8);

    function automatic [12:0] burst_bytes(input logic [7:0] len,
                                           input logic [2:0] size);
        logic [12:0] beats;
        beats = {5'd0, len} + 13'd1;
        return beats << size;
    endfunction

    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    ap_axi_aw_stable: assert property (
        m_axi_awvalid && !m_axi_awready |=>
        m_axi_awvalid && $stable({m_axi_awid, m_axi_awaddr, m_axi_awlen,
                                  m_axi_awsize, m_axi_awburst, m_axi_awlock,
                                  m_axi_awcache, m_axi_awprot}));
    ap_axi_w_stable: assert property (
        m_axi_wvalid && !m_axi_wready |=>
        m_axi_wvalid && $stable({m_axi_wdata, m_axi_wstrb, m_axi_wlast}));
    ap_axi_ar_stable: assert property (
        m_axi_arvalid && !m_axi_arready |=>
        m_axi_arvalid && $stable({m_axi_arid, m_axi_araddr, m_axi_arlen,
                                  m_axi_arsize, m_axi_arburst, m_axi_arlock,
                                  m_axi_arcache, m_axi_arprot}));

    /* The memory slave must also keep response payload stable under stall. */
    ap_axi_b_stable: assert property (
        m_axi_bvalid && !m_axi_bready |=>
        m_axi_bvalid && $stable({m_axi_bid, m_axi_bresp}));
    ap_axi_r_stable: assert property (
        m_axi_rvalid && !m_axi_rready |=>
        m_axi_rvalid && $stable({m_axi_rid, m_axi_rdata,
                                 m_axi_rresp, m_axi_rlast}));

    ap_aw_incr: assert property (
        m_axi_awvalid && m_axi_awready |-> m_axi_awburst == 2'b01);
    ap_ar_incr: assert property (
        m_axi_arvalid && m_axi_arready |-> m_axi_arburst == 2'b01);
    ap_aw_full_width: assert property (
        m_axi_awvalid && m_axi_awready |-> m_axi_awsize == AXI_SIZE);
    ap_ar_full_width: assert property (
        m_axi_arvalid && m_axi_arready |-> m_axi_arsize == AXI_SIZE);

    ap_aw_no_4k_cross: assert property (
        m_axi_awvalid && m_axi_awready |->
        ({1'b0, m_axi_awaddr[11:0]} +
         burst_bytes(m_axi_awlen, m_axi_awsize)) <= 13'd4096);
    ap_ar_no_4k_cross: assert property (
        m_axi_arvalid && m_axi_arready |->
        ({1'b0, m_axi_araddr[11:0]} +
         burst_bytes(m_axi_arlen, m_axi_arsize)) <= 13'd4096);

    ap_aw_known: assert property (m_axi_awvalid |->
        !$isunknown({m_axi_awid, m_axi_awaddr, m_axi_awlen,
                     m_axi_awsize, m_axi_awburst, m_axi_awlock,
                     m_axi_awcache, m_axi_awprot}));
    ap_w_known: assert property (m_axi_wvalid |->
        !$isunknown({m_axi_wdata, m_axi_wstrb, m_axi_wlast}));
    ap_ar_known: assert property (m_axi_arvalid |->
        !$isunknown({m_axi_arid, m_axi_araddr, m_axi_arlen,
                     m_axi_arsize, m_axi_arburst, m_axi_arlock,
                     m_axi_arcache, m_axi_arprot}));

    cp_aw_stall: cover property (m_axi_awvalid && !m_axi_awready);
    cp_w_stall:  cover property (m_axi_wvalid && !m_axi_wready);
    cp_ar_stall: cover property (m_axi_arvalid && !m_axi_arready);
    cp_r_stall:  cover property (m_axi_rvalid && !m_axi_rready);
    cp_read_error: cover property (
        m_axi_rvalid && m_axi_rready && m_axi_rresp != 2'b00);
    cp_write_error: cover property (
        m_axi_bvalid && m_axi_bready && m_axi_bresp != 2'b00);

endmodule


/* Properties on descriptor, stream, FIFO, and IRQ internals. */
module axi_dma_internal_sva #(
    parameter int ADDR_WIDTH       = 16,
    parameter int DATA_WIDTH       = 32,
    parameter int LEN_WIDTH        = 20,
    parameter int TAG_WIDTH        = 8,
    parameter int DESC_FIFO_DEPTH  = 4,
    parameter int COMP_FIFO_DEPTH  = 4,
    parameter int AXIS_FIFO_DEPTH  = 16,
    parameter int COMP_WIDTH       = TAG_WIDTH + LEN_WIDTH + 11
)(
    input logic clk,
    input logic rst,
    input logic irq,

    input logic [ADDR_WIDTH-1:0] read_desc_addr,
    input logic [LEN_WIDTH-1:0]  read_desc_len,
    input logic [TAG_WIDTH-1:0]  read_desc_tag,
    input logic                  read_desc_valid,
    input logic                  read_desc_ready,
    input logic [ADDR_WIDTH-1:0] write_desc_addr,
    input logic [LEN_WIDTH-1:0]  write_desc_len,
    input logic [TAG_WIDTH-1:0]  write_desc_tag,
    input logic                  write_desc_valid,
    input logic                  write_desc_ready,

    input logic [DATA_WIDTH-1:0] read_tdata,
    input logic [DATA_WIDTH/8-1:0] read_tkeep,
    input logic                  read_tlast,
    input logic                  read_tvalid,
    input logic                  read_tready,
    input logic [DATA_WIDTH-1:0] write_tdata,
    input logic [DATA_WIDTH/8-1:0] write_tkeep,
    input logic                  write_tlast,
    input logic                  write_tvalid,
    input logic                  write_tready,

    input logic [$clog2(DESC_FIFO_DEPTH+1)-1:0] req_level,
    input logic [$clog2(COMP_FIFO_DEPTH+1)-1:0] comp_level,
    input logic [$clog2(AXIS_FIFO_DEPTH+1)-1:0] axis_level,
    input logic irq_enable,
    input logic manager_active,
    input logic comp_valid,
    input logic comp_ready,
    input logic [COMP_WIDTH-1:0] comp_data,
    input logic [31:0] submitted_count,
    input logic [31:0] completed_count
);

    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);

    ap_read_desc_stable: assert property (
        read_desc_valid && !read_desc_ready |=>
        read_desc_valid &&
        $stable({read_desc_addr, read_desc_len, read_desc_tag}));
    ap_write_desc_stable: assert property (
        write_desc_valid && !write_desc_ready |=>
        write_desc_valid &&
        $stable({write_desc_addr, write_desc_len, write_desc_tag}));

    cp_read_desc_stable_success: cover property (
        (read_desc_valid && !read_desc_ready) ##1
        (read_desc_valid &&
         $stable({read_desc_addr, read_desc_len, read_desc_tag})));
    cp_write_desc_stable_success: cover property (
        (write_desc_valid && !write_desc_ready) ##1
        (write_desc_valid &&
         $stable({write_desc_addr, write_desc_len, write_desc_tag})));

    ap_read_axis_stable: assert property (
        read_tvalid && !read_tready |=>
        read_tvalid && $stable({read_tdata, read_tkeep, read_tlast}));
    ap_write_axis_stable: assert property (
        write_tvalid && !write_tready |=>
        write_tvalid && $stable({write_tdata, write_tkeep, write_tlast}));
    ap_completion_stable: assert property (
        comp_valid && !comp_ready |=>
        comp_valid && $stable(comp_data));

    ap_req_level_bound: assert property (req_level <= DESC_FIFO_DEPTH);
    ap_comp_level_bound: assert property (comp_level <= COMP_FIFO_DEPTH);
    ap_axis_level_bound: assert property (axis_level <= AXIS_FIFO_DEPTH);
    ap_completion_count_bound: assert property (
        completed_count <= submitted_count);
    ap_irq_definition: assert property (irq == (irq_enable && comp_valid));

    /* This property intentionally overrides the module's normal
     * disable-during-reset rule: reset behavior itself is what is checked. */
    ap_reset_clears_state: assert property (
        @(posedge clk) disable iff (1'b0)
        rst |=> (!irq && !manager_active &&
                 req_level == 0 && comp_level == 0 && axis_level == 0 &&
                 !read_desc_valid && !write_desc_valid &&
                 submitted_count == 0 && completed_count == 0));

    cp_read_desc_stall: cover property (read_desc_valid && !read_desc_ready);
    cp_write_desc_stall: cover property (write_desc_valid && !write_desc_ready);
    cp_axis_fifo_nonempty: cover property (axis_level > 0);
    cp_axis_fifo_backpressure: cover property (read_tvalid && !read_tready);
    cp_completion_backlog: cover property (comp_level > 1);
    cp_reset_during_active: cover property (
        @(posedge clk) disable iff (1'b0)
        $rose(rst) && $past(manager_active));

endmodule


bind axi_dma_subsystem axi_dma_bus_sva #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH)
) axi_dma_bus_sva_inst (
    .clk(clk), .rst(rst),
    .m_axi_awid(m_axi_awid), .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst), .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache), .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid), .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid), .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst), .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache), .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid), .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp), .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
);

bind axi_dma_subsystem axi_dma_internal_sva #(
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .DESC_FIFO_DEPTH(DESC_FIFO_DEPTH),
    .COMP_FIFO_DEPTH(COMP_FIFO_DEPTH),
    .AXIS_FIFO_DEPTH(AXIS_FIFO_DEPTH)
) axi_dma_internal_sva_inst (
    .clk(clk), .rst(rst), .irq(irq),
    .read_desc_addr(read_desc_addr), .read_desc_len(read_desc_len),
    .read_desc_tag(read_desc_tag),
    .read_desc_valid(read_desc_valid), .read_desc_ready(read_desc_ready),
    .write_desc_addr(write_desc_addr), .write_desc_len(write_desc_len),
    .write_desc_tag(write_desc_tag),
    .write_desc_valid(write_desc_valid), .write_desc_ready(write_desc_ready),
    .read_tdata(dma_read_tdata), .read_tkeep(dma_read_tkeep),
    .read_tlast(dma_read_tlast),
    .read_tvalid(dma_read_tvalid), .read_tready(dma_read_tready),
    .write_tdata(dma_write_tdata), .write_tkeep(dma_write_tkeep),
    .write_tlast(dma_write_tlast),
    .write_tvalid(dma_write_tvalid), .write_tready(dma_write_tready),
    .req_level(dma_desc_manager_inst.req_fifo_level),
    .comp_level(dma_desc_manager_inst.comp_fifo_level),
    .axis_level(axis_fifo_inst.count_reg),
    .irq_enable(dma_desc_manager_inst.irq_enable_reg),
    .manager_active(dma_desc_manager_inst.state_reg != 3'd0),
    .comp_valid(dma_desc_manager_inst.comp_fifo_m_valid),
    .comp_ready(dma_desc_manager_inst.comp_fifo_m_ready),
    .comp_data(dma_desc_manager_inst.comp_fifo_m_data),
    .submitted_count(dma_desc_manager_inst.submitted_count_reg),
    .completed_count(dma_desc_manager_inst.completed_count_reg)
);
