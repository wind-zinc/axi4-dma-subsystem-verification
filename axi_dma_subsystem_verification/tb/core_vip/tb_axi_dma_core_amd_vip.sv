`default_nettype none
`timescale 1ns / 1ps

// Static integration point for the five AMD AXI VIP instances.  The VIP HDL
// itself intentionally remains outside this repository; see
// sim/run_vcs_core_amd_vip.sh for the AXI_VIP_HOME contract.
module tb_axi_dma_core_amd_vip;
    import uvm_pkg::*;
    import dma_subsystem_pkg::*;
    `include "uvm_macros.svh"

    logic clk;
    logic rst;
    wire aresetn = ~rst;

    logic [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr;
    logic [2:0] s_axil_awprot;
    logic s_axil_awvalid;
    logic s_axil_awready;
    logic [AXIL_DATA_WIDTH-1:0] s_axil_wdata;
    logic [AXIL_STRB_WIDTH-1:0] s_axil_wstrb;
    logic s_axil_wvalid;
    logic s_axil_wready;
    logic [1:0] s_axil_bresp;
    logic s_axil_bvalid;
    logic s_axil_bready;
    logic [AXIL_ADDR_WIDTH-1:0] s_axil_araddr;
    logic [2:0] s_axil_arprot;
    logic s_axil_arvalid;
    logic s_axil_arready;
    logic [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
    logic [1:0] s_axil_rresp;
    logic s_axil_rvalid;
    logic s_axil_rready;

    logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_awid;
    logic [EXT_AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_awaddr;
    logic [EXT_AXI_MASTER_COUNT*8-1:0] s_axi_ext_awlen;
    logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_awsize;
    logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_awburst;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awlock;
    logic [EXT_AXI_MASTER_COUNT*4-1:0] s_axi_ext_awcache;
    logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_awprot;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awvalid;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_awready;
    logic [EXT_AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_wdata;
    logic [EXT_AXI_MASTER_COUNT*AXI_STRB_WIDTH-1:0] s_axi_ext_wstrb;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wlast;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wvalid;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_wready;
    logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_bid;
    logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_bresp;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_bvalid;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_bready;
    logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_arid;
    logic [EXT_AXI_MASTER_COUNT*AXI_ADDR_WIDTH-1:0] s_axi_ext_araddr;
    logic [EXT_AXI_MASTER_COUNT*8-1:0] s_axi_ext_arlen;
    logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_arsize;
    logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_arburst;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arlock;
    logic [EXT_AXI_MASTER_COUNT*4-1:0] s_axi_ext_arcache;
    logic [EXT_AXI_MASTER_COUNT*3-1:0] s_axi_ext_arprot;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arvalid;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_arready;
    logic [EXT_AXI_MASTER_COUNT*AXI_ID_WIDTH-1:0] s_axi_ext_rid;
    logic [EXT_AXI_MASTER_COUNT*AXI_DATA_WIDTH-1:0] s_axi_ext_rdata;
    logic [EXT_AXI_MASTER_COUNT*2-1:0] s_axi_ext_rresp;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rlast;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rvalid;
    logic [EXT_AXI_MASTER_COUNT-1:0] s_axi_ext_rready;

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

    logic [DMA_CH_COUNT-1:0] irq_ch;
    logic irq;
    logic [DMA_CH_COUNT-1:0] subsys_busy;

    axi_dma_subsystem_core dut (.*);

    axil_cpu_vip u_axil_cpu_vip (
        .aclk(clk), .aresetn(aresetn),
        .m_axi_awaddr(s_axil_awaddr), .m_axi_awprot(s_axil_awprot),
        .m_axi_awvalid(s_axil_awvalid), .m_axi_awready(s_axil_awready),
        .m_axi_wdata(s_axil_wdata), .m_axi_wstrb(s_axil_wstrb),
        .m_axi_wvalid(s_axil_wvalid), .m_axi_wready(s_axil_wready),
        .m_axi_bresp(s_axil_bresp), .m_axi_bvalid(s_axil_bvalid),
        .m_axi_bready(s_axil_bready), .m_axi_araddr(s_axil_araddr),
        .m_axi_arprot(s_axil_arprot), .m_axi_arvalid(s_axil_arvalid),
        .m_axi_arready(s_axil_arready), .m_axi_rdata(s_axil_rdata),
        .m_axi_rresp(s_axil_rresp), .m_axi_rvalid(s_axil_rvalid),
        .m_axi_rready(s_axil_rready)
    );

    ext_m0_vip u_ext_m0_vip (
        .aclk(clk), .aresetn(aresetn),
        .m_axi_awid(s_axi_ext_awid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_awaddr(s_axi_ext_awaddr[0*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
        .m_axi_awlen(s_axi_ext_awlen[0*8 +: 8]), .m_axi_awsize(s_axi_ext_awsize[0*3 +: 3]),
        .m_axi_awburst(s_axi_ext_awburst[0*2 +: 2]), .m_axi_awlock(s_axi_ext_awlock[0]),
        .m_axi_awcache(s_axi_ext_awcache[0*4 +: 4]), .m_axi_awprot(s_axi_ext_awprot[0*3 +: 3]),
        .m_axi_awregion(), .m_axi_awqos(), .m_axi_awvalid(s_axi_ext_awvalid[0]),
        .m_axi_awready(s_axi_ext_awready[0]), .m_axi_wdata(s_axi_ext_wdata[0*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .m_axi_wstrb(s_axi_ext_wstrb[0*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]), .m_axi_wlast(s_axi_ext_wlast[0]),
        .m_axi_wvalid(s_axi_ext_wvalid[0]), .m_axi_wready(s_axi_ext_wready[0]),
        .m_axi_bid(s_axi_ext_bid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_bresp(s_axi_ext_bresp[0*2 +: 2]),
        .m_axi_bvalid(s_axi_ext_bvalid[0]), .m_axi_bready(s_axi_ext_bready[0]),
        .m_axi_arid(s_axi_ext_arid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_araddr(s_axi_ext_araddr[0*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
        .m_axi_arlen(s_axi_ext_arlen[0*8 +: 8]), .m_axi_arsize(s_axi_ext_arsize[0*3 +: 3]),
        .m_axi_arburst(s_axi_ext_arburst[0*2 +: 2]), .m_axi_arlock(s_axi_ext_arlock[0]),
        .m_axi_arcache(s_axi_ext_arcache[0*4 +: 4]), .m_axi_arprot(s_axi_ext_arprot[0*3 +: 3]),
        .m_axi_arregion(), .m_axi_arqos(), .m_axi_arvalid(s_axi_ext_arvalid[0]),
        .m_axi_arready(s_axi_ext_arready[0]), .m_axi_rid(s_axi_ext_rid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_rdata(s_axi_ext_rdata[0*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]), .m_axi_rresp(s_axi_ext_rresp[0*2 +: 2]),
        .m_axi_rlast(s_axi_ext_rlast[0]), .m_axi_rvalid(s_axi_ext_rvalid[0]), .m_axi_rready(s_axi_ext_rready[0])
    );

    ext_m1_vip u_ext_m1_vip (
        .aclk(clk), .aresetn(aresetn),
        .m_axi_awid(s_axi_ext_awid[1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_awaddr(s_axi_ext_awaddr[1*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
        .m_axi_awlen(s_axi_ext_awlen[1*8 +: 8]), .m_axi_awsize(s_axi_ext_awsize[1*3 +: 3]),
        .m_axi_awburst(s_axi_ext_awburst[1*2 +: 2]), .m_axi_awlock(s_axi_ext_awlock[1]),
        .m_axi_awcache(s_axi_ext_awcache[1*4 +: 4]), .m_axi_awprot(s_axi_ext_awprot[1*3 +: 3]),
        .m_axi_awregion(), .m_axi_awqos(), .m_axi_awvalid(s_axi_ext_awvalid[1]),
        .m_axi_awready(s_axi_ext_awready[1]), .m_axi_wdata(s_axi_ext_wdata[1*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .m_axi_wstrb(s_axi_ext_wstrb[1*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]), .m_axi_wlast(s_axi_ext_wlast[1]),
        .m_axi_wvalid(s_axi_ext_wvalid[1]), .m_axi_wready(s_axi_ext_wready[1]),
        .m_axi_bid(s_axi_ext_bid[1*AXI_ID_WIDTH +: AXI_ID_WIDTH]), .m_axi_bresp(s_axi_ext_bresp[1*2 +: 2]),
        .m_axi_bvalid(s_axi_ext_bvalid[1]), .m_axi_bready(s_axi_ext_bready[1]),
        .m_axi_arid(s_axi_ext_arid[1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_araddr(s_axi_ext_araddr[1*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]),
        .m_axi_arlen(s_axi_ext_arlen[1*8 +: 8]), .m_axi_arsize(s_axi_ext_arsize[1*3 +: 3]),
        .m_axi_arburst(s_axi_ext_arburst[1*2 +: 2]), .m_axi_arlock(s_axi_ext_arlock[1]),
        .m_axi_arcache(s_axi_ext_arcache[1*4 +: 4]), .m_axi_arprot(s_axi_ext_arprot[1*3 +: 3]),
        .m_axi_arregion(), .m_axi_arqos(), .m_axi_arvalid(s_axi_ext_arvalid[1]),
        .m_axi_arready(s_axi_ext_arready[1]), .m_axi_rid(s_axi_ext_rid[1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_rdata(s_axi_ext_rdata[1*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]), .m_axi_rresp(s_axi_ext_rresp[1*2 +: 2]),
        .m_axi_rlast(s_axi_ext_rlast[1]), .m_axi_rvalid(s_axi_ext_rvalid[1]), .m_axi_rready(s_axi_ext_rready[1])
    );

    mem0_vip u_mem0_vip (
        .aclk(clk), .aresetn(aresetn),
        .s_axi_awid(m_axi_mem_awid[0*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(m_axi_mem_awaddr[0*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]), .s_axi_awlen(m_axi_mem_awlen[0*8 +: 8]),
        .s_axi_awsize(m_axi_mem_awsize[0*3 +: 3]), .s_axi_awburst(m_axi_mem_awburst[0*2 +: 2]),
        .s_axi_awlock(m_axi_mem_awlock[0]), .s_axi_awcache(m_axi_mem_awcache[0*4 +: 4]),
        .s_axi_awprot(m_axi_mem_awprot[0*3 +: 3]), .s_axi_awregion(4'd0), .s_axi_awqos(4'd0),
        .s_axi_awvalid(m_axi_mem_awvalid[0]), .s_axi_awready(m_axi_mem_awready[0]),
        .s_axi_wdata(m_axi_mem_wdata[0*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(m_axi_mem_wstrb[0*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]), .s_axi_wlast(m_axi_mem_wlast[0]),
        .s_axi_wvalid(m_axi_mem_wvalid[0]), .s_axi_wready(m_axi_mem_wready[0]),
        .s_axi_bid(m_axi_mem_bid[0*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]), .s_axi_bresp(m_axi_mem_bresp[0*2 +: 2]),
        .s_axi_bvalid(m_axi_mem_bvalid[0]), .s_axi_bready(m_axi_mem_bready[0]),
        .s_axi_arid(m_axi_mem_arid[0*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(m_axi_mem_araddr[0*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]), .s_axi_arlen(m_axi_mem_arlen[0*8 +: 8]),
        .s_axi_arsize(m_axi_mem_arsize[0*3 +: 3]), .s_axi_arburst(m_axi_mem_arburst[0*2 +: 2]),
        .s_axi_arlock(m_axi_mem_arlock[0]), .s_axi_arcache(m_axi_mem_arcache[0*4 +: 4]),
        .s_axi_arprot(m_axi_mem_arprot[0*3 +: 3]), .s_axi_arregion(4'd0), .s_axi_arqos(4'd0),
        .s_axi_arvalid(m_axi_mem_arvalid[0]), .s_axi_arready(m_axi_mem_arready[0]),
        .s_axi_rid(m_axi_mem_rid[0*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(m_axi_mem_rdata[0*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]), .s_axi_rresp(m_axi_mem_rresp[0*2 +: 2]),
        .s_axi_rlast(m_axi_mem_rlast[0]), .s_axi_rvalid(m_axi_mem_rvalid[0]), .s_axi_rready(m_axi_mem_rready[0])
    );

    mem1_vip u_mem1_vip (
        .aclk(clk), .aresetn(aresetn),
        .s_axi_awid(m_axi_mem_awid[1*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_awaddr(m_axi_mem_awaddr[1*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]), .s_axi_awlen(m_axi_mem_awlen[1*8 +: 8]),
        .s_axi_awsize(m_axi_mem_awsize[1*3 +: 3]), .s_axi_awburst(m_axi_mem_awburst[1*2 +: 2]),
        .s_axi_awlock(m_axi_mem_awlock[1]), .s_axi_awcache(m_axi_mem_awcache[1*4 +: 4]),
        .s_axi_awprot(m_axi_mem_awprot[1*3 +: 3]), .s_axi_awregion(4'd0), .s_axi_awqos(4'd0),
        .s_axi_awvalid(m_axi_mem_awvalid[1]), .s_axi_awready(m_axi_mem_awready[1]),
        .s_axi_wdata(m_axi_mem_wdata[1*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]),
        .s_axi_wstrb(m_axi_mem_wstrb[1*AXI_STRB_WIDTH +: AXI_STRB_WIDTH]), .s_axi_wlast(m_axi_mem_wlast[1]),
        .s_axi_wvalid(m_axi_mem_wvalid[1]), .s_axi_wready(m_axi_mem_wready[1]),
        .s_axi_bid(m_axi_mem_bid[1*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]), .s_axi_bresp(m_axi_mem_bresp[1*2 +: 2]),
        .s_axi_bvalid(m_axi_mem_bvalid[1]), .s_axi_bready(m_axi_mem_bready[1]),
        .s_axi_arid(m_axi_mem_arid[1*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_araddr(m_axi_mem_araddr[1*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH]), .s_axi_arlen(m_axi_mem_arlen[1*8 +: 8]),
        .s_axi_arsize(m_axi_mem_arsize[1*3 +: 3]), .s_axi_arburst(m_axi_mem_arburst[1*2 +: 2]),
        .s_axi_arlock(m_axi_mem_arlock[1]), .s_axi_arcache(m_axi_mem_arcache[1*4 +: 4]),
        .s_axi_arprot(m_axi_mem_arprot[1*3 +: 3]), .s_axi_arregion(4'd0), .s_axi_arqos(4'd0),
        .s_axi_arvalid(m_axi_mem_arvalid[1]), .s_axi_arready(m_axi_mem_arready[1]),
        .s_axi_rid(m_axi_mem_rid[1*AXI_XBAR_M_ID_WIDTH +: AXI_XBAR_M_ID_WIDTH]),
        .s_axi_rdata(m_axi_mem_rdata[1*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]), .s_axi_rresp(m_axi_mem_rresp[1*2 +: 2]),
        .s_axi_rlast(m_axi_mem_rlast[1]), .s_axi_rvalid(m_axi_mem_rvalid[1]), .s_axi_rready(m_axi_mem_rready[1])
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst = 1'b1;
        // AMD AXI VIP checks for at least 16 active reset clock cycles.
        // Keep a margin so every one of the five agents starts cleanly.
        repeat (20) @(posedge clk);
        rst = 1'b0;
    end

    // A plain elaboration run resets the DUT and exits.  UVM tests can wait
    // for negedge rst and construct AMD agents through the static instances
    // above (for example u_axil_cpu_vip.inst.IF).
    initial begin
        if ($test$plusargs("UVM_TESTNAME")) begin
            run_test();
        end else begin
            @(negedge rst);
            repeat (2) @(posedge clk);
            $display("[AMD-VIP-ELAB] Core plus five AMD AXI VIP instances elaborated");
            $finish;
        end
    end
endmodule

`default_nettype wire
