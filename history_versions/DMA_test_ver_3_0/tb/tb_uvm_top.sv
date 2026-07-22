`timescale 1ns/1ps

module tb_uvm_top;

    import uvm_pkg::*;
    import axil_agent_pkg::*;
    import dma_uvm_pkg::*;

    localparam int AXIL_ADDR_WIDTH = 8;
    localparam int AXI_ADDR_WIDTH  = 16;
    localparam int AXI_DATA_WIDTH  = 32;
    localparam int AXI_ID_WIDTH    = 8;
    localparam int AXI_STRB_WIDTH  = AXI_DATA_WIDTH/8;
    localparam int LEN_WIDTH       = 20;
    localparam int TAG_WIDTH       = 8;

    logic clk = 1'b0;
    logic rst = 1'b1;
    wire  irq;

    always #5ns clk = ~clk;

    axil_if #(
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(32)
    ) axil_bus (
        .clk(clk),
        .rst(rst)
    );

    irq_if irq_bus (
        .clk(clk),
        .rst(rst)
    );

    dma_observer_if #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH), .DATA_WIDTH(AXI_DATA_WIDTH),
        .LEN_WIDTH(LEN_WIDTH), .TAG_WIDTH(TAG_WIDTH)
    ) observer_bus (.clk(clk), .rst(rst));

    assign irq_bus.irq = irq;

    wire [AXI_ID_WIDTH-1:0]   axi_awid;
    wire [AXI_ADDR_WIDTH-1:0] axi_awaddr;
    wire [7:0]                axi_awlen;
    wire [2:0]                axi_awsize;
    wire [1:0]                axi_awburst;
    wire                      axi_awlock;
    wire [3:0]                axi_awcache;
    wire [2:0]                axi_awprot;
    wire                      axi_awvalid;
    wire                      axi_awready;
    wire [AXI_DATA_WIDTH-1:0] axi_wdata;
    wire [AXI_STRB_WIDTH-1:0] axi_wstrb;
    wire                      axi_wlast;
    wire                      axi_wvalid;
    wire                      axi_wready;
    wire [AXI_ID_WIDTH-1:0]   axi_bid;
    wire [1:0]                axi_bresp;
    wire                      axi_bvalid;
    wire                      axi_bready;
    wire [AXI_ID_WIDTH-1:0]   axi_arid;
    wire [AXI_ADDR_WIDTH-1:0] axi_araddr;
    wire [7:0]                axi_arlen;
    wire [2:0]                axi_arsize;
    wire [1:0]                axi_arburst;
    wire                      axi_arlock;
    wire [3:0]                axi_arcache;
    wire [2:0]                axi_arprot;
    wire                      axi_arvalid;
    wire                      axi_arready;
    wire [AXI_ID_WIDTH-1:0]   axi_rid;
    wire [AXI_DATA_WIDTH-1:0] axi_rdata;
    wire [1:0]                axi_rresp;
    wire                      axi_rlast;
    wire                      axi_rvalid;
    wire                      axi_rready;

    axi_dma_subsystem #(
        .AXIL_DATA_WIDTH(32),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_MAX_BURST_LEN(16),
        .AXIS_FIFO_DEPTH(16),
        .DESC_FIFO_DEPTH(4),
        .COMP_FIFO_DEPTH(4),
        .LEN_WIDTH(LEN_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .ENABLE_UNALIGNED(0)
    ) dut (
        .clk(clk),
        .rst(rst),
        .s_axil_awaddr(axil_bus.awaddr),
        .s_axil_awprot(axil_bus.awprot),
        .s_axil_awvalid(axil_bus.awvalid),
        .s_axil_awready(axil_bus.awready),
        .s_axil_wdata(axil_bus.wdata),
        .s_axil_wstrb(axil_bus.wstrb),
        .s_axil_wvalid(axil_bus.wvalid),
        .s_axil_wready(axil_bus.wready),
        .s_axil_bresp(axil_bus.bresp),
        .s_axil_bvalid(axil_bus.bvalid),
        .s_axil_bready(axil_bus.bready),
        .s_axil_araddr(axil_bus.araddr),
        .s_axil_arprot(axil_bus.arprot),
        .s_axil_arvalid(axil_bus.arvalid),
        .s_axil_arready(axil_bus.arready),
        .s_axil_rdata(axil_bus.rdata),
        .s_axil_rresp(axil_bus.rresp),
        .s_axil_rvalid(axil_bus.rvalid),
        .s_axil_rready(axil_bus.rready),
        .m_axi_awid(axi_awid),
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize),
        .m_axi_awburst(axi_awburst),
        .m_axi_awlock(axi_awlock),
        .m_axi_awcache(axi_awcache),
        .m_axi_awprot(axi_awprot),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wlast(axi_wlast),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        .m_axi_bid(axi_bid),
        .m_axi_bresp(axi_bresp),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready),
        .m_axi_arid(axi_arid),
        .m_axi_araddr(axi_araddr),
        .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize),
        .m_axi_arburst(axi_arburst),
        .m_axi_arlock(axi_arlock),
        .m_axi_arcache(axi_arcache),
        .m_axi_arprot(axi_arprot),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_rid(axi_rid),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rlast(axi_rlast),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready),
        .irq(irq)
    );

    assign observer_bus.desc_src_addr = dut.read_desc_addr;
    assign observer_bus.desc_dst_addr = dut.write_desc_addr;
    assign observer_bus.desc_length = dut.read_desc_len;
    assign observer_bus.desc_tag = dut.read_desc_tag;
    assign observer_bus.desc_valid = dut.write_desc_valid;
    assign observer_bus.desc_ready = dut.write_desc_ready;
    assign observer_bus.araddr = axi_araddr;
    assign observer_bus.arlen = axi_arlen;
    assign observer_bus.arsize = axi_arsize;
    assign observer_bus.arburst = axi_arburst;
    assign observer_bus.arvalid = axi_arvalid;
    assign observer_bus.arready = axi_arready;
    assign observer_bus.awaddr = axi_awaddr;
    assign observer_bus.awlen = axi_awlen;
    assign observer_bus.awsize = axi_awsize;
    assign observer_bus.awburst = axi_awburst;
    assign observer_bus.awvalid = axi_awvalid;
    assign observer_bus.awready = axi_awready;
    assign observer_bus.wdata = axi_wdata;
    assign observer_bus.wstrb = axi_wstrb;
    assign observer_bus.wlast = axi_wlast;
    assign observer_bus.wvalid = axi_wvalid;
    assign observer_bus.wready = axi_wready;
    assign observer_bus.completion_tag = dut.dma_desc_manager_inst.pending_tag_reg;
    assign observer_bus.completion_length = dut.dma_desc_manager_inst.pending_length_reg;
    assign observer_bus.completion_flags = dut.dma_desc_manager_inst.pending_flags_reg;
    assign observer_bus.completion_write_error = dut.dma_desc_manager_inst.pending_write_error_reg;
    assign observer_bus.completion_read_error = dut.dma_desc_manager_inst.pending_read_error_reg;
    assign observer_bus.completion_valid = dut.dma_desc_manager_inst.comp_fifo_s_valid;
    assign observer_bus.completion_ready = dut.dma_desc_manager_inst.comp_fifo_s_ready;

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .s_axi_awid(axi_awid),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awlen(axi_awlen),
        .s_axi_awsize(axi_awsize),
        .s_axi_awburst(axi_awburst),
        .s_axi_awlock(axi_awlock),
        .s_axi_awcache(axi_awcache),
        .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wlast(axi_wlast),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bid(axi_bid),
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_arid(axi_arid),
        .s_axi_araddr(axi_araddr),
        .s_axi_arlen(axi_arlen),
        .s_axi_arsize(axi_arsize),
        .s_axi_arburst(axi_arburst),
        .s_axi_arlock(axi_arlock),
        .s_axi_arcache(axi_arcache),
        .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rid(axi_rid),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rlast(axi_rlast),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready)
    );

    /* Deterministic contents make every legal random source address usable. */
    integer word_index;
    initial begin
        /* axi_ram also clears mem[] at time zero; initialize after reset. */
        wait (rst == 1'b0);
        for (word_index = 0; word_index < 16384; word_index++)
            ram_inst.mem[word_index] = 32'h5a00_0000 ^ word_index;
    end

    initial begin
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual axil_if)::set(
            null, "uvm_test_top.env.axil_agt", "vif", axil_bus);
        uvm_config_db#(virtual irq_if)::set(
            null, "uvm_test_top.env.cov", "irq_vif", irq_bus);
        uvm_config_db#(virtual dma_observer_if)::set(
            null, "uvm_test_top.env.obs_mon", "vif", observer_bus);
        uvm_config_db#(int)::set(
            null, "uvm_test_top.env.scb", "ref_init_mode", 1);
        run_test("dma_ral_smoke_test");
    end

    initial begin
        #2ms;
        $fatal(1, "Global UVM testbench timeout");
    end

`ifdef FSDB
    initial begin
        $fsdbDumpfile("axi_dma_uvm_random_smoke.fsdb");
        $fsdbDumpvars(0, tb_uvm_top);
    end
`endif

endmodule
