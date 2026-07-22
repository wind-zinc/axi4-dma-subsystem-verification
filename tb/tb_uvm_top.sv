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
    logic por_rst = 1'b1;
    wire  rst;
    wire  irq;

    always #5ns clk = ~clk;

    dma_reset_if reset_bus (
        .clk(clk)
    );

    assign rst = por_rst | reset_bus.request;

    axil_if #(
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(32)
    ) axil_bus (
        .clk(clk),
        .rst(rst)
    );

    dma_sva_ctrl_if sva_ctrl_bus (
        .clk(clk),
        .rst(rst)
    );

    irq_if irq_bus (
        .clk(clk),
        .rst(rst)
    );

    dma_mem_ctrl_if #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) mem_ctrl_bus (
        .clk(clk),
        .rst(rst)
    );

    dma_observer_if #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .TAG_WIDTH(TAG_WIDTH)
    ) observer_bus (
        .clk(clk),
        .rst(rst)
    );

    assign irq_bus.irq = irq;

    /* DUT-side AXI wires. */
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

    /* RAM-side AXI wires after fault injection and channel gating. */
    wire [AXI_ID_WIDTH-1:0]   ram_axi_awid;
    wire [AXI_ADDR_WIDTH-1:0] ram_axi_awaddr;
    wire [7:0]                ram_axi_awlen;
    wire [2:0]                ram_axi_awsize;
    wire [1:0]                ram_axi_awburst;
    wire                      ram_axi_awlock;
    wire [3:0]                ram_axi_awcache;
    wire [2:0]                ram_axi_awprot;
    wire                      ram_axi_awvalid;
    wire                      ram_axi_awready;
    wire [AXI_DATA_WIDTH-1:0] ram_axi_wdata;
    wire [AXI_STRB_WIDTH-1:0] ram_axi_wstrb;
    wire                      ram_axi_wlast;
    wire                      ram_axi_wvalid;
    wire                      ram_axi_wready;
    wire [AXI_ID_WIDTH-1:0]   ram_axi_bid;
    wire [1:0]                ram_axi_bresp;
    wire                      ram_axi_bvalid;
    wire                      ram_axi_bready;
    wire [AXI_ID_WIDTH-1:0]   ram_axi_arid;
    wire [AXI_ADDR_WIDTH-1:0] ram_axi_araddr;
    wire [7:0]                ram_axi_arlen;
    wire [2:0]                ram_axi_arsize;
    wire [1:0]                ram_axi_arburst;
    wire                      ram_axi_arlock;
    wire [3:0]                ram_axi_arcache;
    wire [2:0]                ram_axi_arprot;
    wire                      ram_axi_arvalid;
    wire                      ram_axi_arready;
    wire [AXI_ID_WIDTH-1:0]   ram_axi_rid;
    wire [AXI_DATA_WIDTH-1:0] ram_axi_rdata;
    wire [1:0]                ram_axi_rresp;
    wire                      ram_axi_rlast;
    wire                      ram_axi_rvalid;
    wire                      ram_axi_rready;

    /*
     * AXI-Lite request-channel verification gate.
     *
     * Both sides of each handshake are gated.  The UVM driver therefore
     * observes READY low while the DUT observes VALID low, so no transfer is
     * lost behind the verification stall.  Payload remains visible on the
     * master-facing axil_bus for the stability checker.
     */
    wire dut_axil_awvalid;
    wire dut_axil_awready;
    wire dut_axil_wvalid;
    wire dut_axil_wready;
    wire dut_axil_arvalid;
    wire dut_axil_arready;

    assign dut_axil_awvalid =
        axil_bus.awvalid && !sva_ctrl_bus.stall_axil_aw;
    assign axil_bus.awready =
        dut_axil_awready && !sva_ctrl_bus.stall_axil_aw;
    assign dut_axil_wvalid =
        axil_bus.wvalid && !sva_ctrl_bus.stall_axil_w;
    assign axil_bus.wready =
        dut_axil_wready && !sva_ctrl_bus.stall_axil_w;
    assign dut_axil_arvalid =
        axil_bus.arvalid && !sva_ctrl_bus.stall_axil_ar;
    assign axil_bus.arready =
        dut_axil_arready && !sva_ctrl_bus.stall_axil_ar;

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
        .s_axil_awvalid(dut_axil_awvalid),
        .s_axil_awready(dut_axil_awready),
        .s_axil_wdata(axil_bus.wdata),
        .s_axil_wstrb(axil_bus.wstrb),
        .s_axil_wvalid(dut_axil_wvalid),
        .s_axil_wready(dut_axil_wready),
        .s_axil_bresp(axil_bus.bresp),
        .s_axil_bvalid(axil_bus.bvalid),
        .s_axil_bready(axil_bus.bready),
        .s_axil_araddr(axil_bus.araddr),
        .s_axil_arprot(axil_bus.arprot),
        .s_axil_arvalid(dut_axil_arvalid),
        .s_axil_arready(dut_axil_arready),
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

    /*
     * AXI-Lite assertions are checked on the UVM-master side of the request
     * gate.  This is the interface contract the agent actually drives and
     * makes request-channel backpressure observable without changing RTL.
     */
    axi_dma_axil_sva #(
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(32)
    ) axi_dma_axil_sva_inst (
        .clk(clk),
        .rst(rst),
        .awaddr(axil_bus.awaddr),
        .awprot(axil_bus.awprot),
        .awvalid(axil_bus.awvalid),
        .awready(axil_bus.awready),
        .wdata(axil_bus.wdata),
        .wstrb(axil_bus.wstrb),
        .wvalid(axil_bus.wvalid),
        .wready(axil_bus.wready),
        .bresp(axil_bus.bresp),
        .bvalid(axil_bus.bvalid),
        .bready(axil_bus.bready),
        .araddr(axil_bus.araddr),
        .arprot(axil_bus.arprot),
        .arvalid(axil_bus.arvalid),
        .arready(axil_bus.arready),
        .rdata(axil_bus.rdata),
        .rresp(axil_bus.rresp),
        .rvalid(axil_bus.rvalid),
        .rready(axil_bus.rready)
    );

    /* Passive checker taps: no signal below is driven back into the DUT. */
    assign observer_bus.desc_src_addr = dut.read_desc_addr;
    assign observer_bus.desc_dst_addr = dut.write_desc_addr;
    assign observer_bus.desc_length   = dut.read_desc_len;
    assign observer_bus.desc_tag      = dut.read_desc_tag;
    assign observer_bus.desc_valid    = dut.write_desc_valid;
    assign observer_bus.desc_ready    = dut.write_desc_ready;

    assign observer_bus.araddr  = axi_araddr;
    assign observer_bus.arlen   = axi_arlen;
    assign observer_bus.arsize  = axi_arsize;
    assign observer_bus.arburst = axi_arburst;
    assign observer_bus.arvalid = axi_arvalid;
    assign observer_bus.arready = axi_arready;

    assign observer_bus.awaddr  = axi_awaddr;
    assign observer_bus.awlen   = axi_awlen;
    assign observer_bus.awsize  = axi_awsize;
    assign observer_bus.awburst = axi_awburst;
    assign observer_bus.awvalid = axi_awvalid;
    assign observer_bus.awready = axi_awready;
    assign observer_bus.wdata   = axi_wdata;
    assign observer_bus.wstrb   = axi_wstrb;
    assign observer_bus.wlast   = axi_wlast;
    assign observer_bus.wvalid  = axi_wvalid;
    assign observer_bus.wready  = axi_wready;
    assign observer_bus.bresp   = axi_bresp;
    assign observer_bus.bvalid  = axi_bvalid;
    assign observer_bus.bready  = axi_bready;

    assign observer_bus.rdata   = axi_rdata;
    assign observer_bus.rresp   = axi_rresp;
    assign observer_bus.rlast   = axi_rlast;
    assign observer_bus.rvalid  = axi_rvalid;
    assign observer_bus.rready  = axi_rready;

    assign observer_bus.completion_tag =
        dut.dma_desc_manager_inst.pending_tag_reg;
    assign observer_bus.completion_length =
        dut.dma_desc_manager_inst.pending_length_reg;
    assign observer_bus.completion_flags =
        dut.dma_desc_manager_inst.pending_flags_reg;
    assign observer_bus.completion_write_error =
        dut.dma_desc_manager_inst.pending_write_error_reg;
    assign observer_bus.completion_read_error =
        dut.dma_desc_manager_inst.pending_read_error_reg;
    assign observer_bus.completion_valid =
        dut.dma_desc_manager_inst.comp_fifo_s_valid;
    assign observer_bus.completion_ready =
        dut.dma_desc_manager_inst.comp_fifo_s_ready;

    axi_mem_proxy #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_ID_WIDTH)
    ) mem_proxy_inst (
        .clk(clk),
        .rst(rst),
        .ctrl(mem_ctrl_bus),
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
        .s_axi_rready(axi_rready),
        .m_axi_awid(ram_axi_awid),
        .m_axi_awaddr(ram_axi_awaddr),
        .m_axi_awlen(ram_axi_awlen),
        .m_axi_awsize(ram_axi_awsize),
        .m_axi_awburst(ram_axi_awburst),
        .m_axi_awlock(ram_axi_awlock),
        .m_axi_awcache(ram_axi_awcache),
        .m_axi_awprot(ram_axi_awprot),
        .m_axi_awvalid(ram_axi_awvalid),
        .m_axi_awready(ram_axi_awready),
        .m_axi_wdata(ram_axi_wdata),
        .m_axi_wstrb(ram_axi_wstrb),
        .m_axi_wlast(ram_axi_wlast),
        .m_axi_wvalid(ram_axi_wvalid),
        .m_axi_wready(ram_axi_wready),
        .m_axi_bid(ram_axi_bid),
        .m_axi_bresp(ram_axi_bresp),
        .m_axi_bvalid(ram_axi_bvalid),
        .m_axi_bready(ram_axi_bready),
        .m_axi_arid(ram_axi_arid),
        .m_axi_araddr(ram_axi_araddr),
        .m_axi_arlen(ram_axi_arlen),
        .m_axi_arsize(ram_axi_arsize),
        .m_axi_arburst(ram_axi_arburst),
        .m_axi_arlock(ram_axi_arlock),
        .m_axi_arcache(ram_axi_arcache),
        .m_axi_arprot(ram_axi_arprot),
        .m_axi_arvalid(ram_axi_arvalid),
        .m_axi_arready(ram_axi_arready),
        .m_axi_rid(ram_axi_rid),
        .m_axi_rdata(ram_axi_rdata),
        .m_axi_rresp(ram_axi_rresp),
        .m_axi_rlast(ram_axi_rlast),
        .m_axi_rvalid(ram_axi_rvalid),
        .m_axi_rready(ram_axi_rready)
    );

    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .STRB_WIDTH(AXI_STRB_WIDTH),
        .ID_WIDTH(AXI_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .s_axi_awid(ram_axi_awid),
        .s_axi_awaddr(ram_axi_awaddr),
        .s_axi_awlen(ram_axi_awlen),
        .s_axi_awsize(ram_axi_awsize),
        .s_axi_awburst(ram_axi_awburst),
        .s_axi_awlock(ram_axi_awlock),
        .s_axi_awcache(ram_axi_awcache),
        .s_axi_awprot(ram_axi_awprot),
        .s_axi_awvalid(ram_axi_awvalid),
        .s_axi_awready(ram_axi_awready),
        .s_axi_wdata(ram_axi_wdata),
        .s_axi_wstrb(ram_axi_wstrb),
        .s_axi_wlast(ram_axi_wlast),
        .s_axi_wvalid(ram_axi_wvalid),
        .s_axi_wready(ram_axi_wready),
        .s_axi_bid(ram_axi_bid),
        .s_axi_bresp(ram_axi_bresp),
        .s_axi_bvalid(ram_axi_bvalid),
        .s_axi_bready(ram_axi_bready),
        .s_axi_arid(ram_axi_arid),
        .s_axi_araddr(ram_axi_araddr),
        .s_axi_arlen(ram_axi_arlen),
        .s_axi_arsize(ram_axi_arsize),
        .s_axi_arburst(ram_axi_arburst),
        .s_axi_arlock(ram_axi_arlock),
        .s_axi_arcache(ram_axi_arcache),
        .s_axi_arprot(ram_axi_arprot),
        .s_axi_arvalid(ram_axi_arvalid),
        .s_axi_arready(ram_axi_arready),
        .s_axi_rid(ram_axi_rid),
        .s_axi_rdata(ram_axi_rdata),
        .s_axi_rresp(ram_axi_rresp),
        .s_axi_rlast(ram_axi_rlast),
        .s_axi_rvalid(ram_axi_rvalid),
        .s_axi_rready(ram_axi_rready)
    );

    /* High-entropy deterministic contents improve meaningful data toggles. */
    function automatic [31:0] initial_word(input integer index);
        reg [31:0] value;
        begin
            value = 32'h9e37_79b9 ^ index;
            value = value ^ (value << 13);
            value = value ^ (value >> 17);
            value = value ^ (value << 5);
            initial_word = value;
        end
    endfunction

    integer word_index;
    initial begin
        wait (rst == 1'b0);
        for (word_index = 0; word_index < 16384; word_index++)
            ram_inst.mem[word_index] = initial_word(word_index);
    end

    initial begin
        repeat (5) @(posedge clk);
        @(negedge clk);
        por_rst = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual axil_if)::set(
            null, "uvm_test_top.env.axil_agt", "vif", axil_bus);
        uvm_config_db#(virtual irq_if)::set(
            null, "uvm_test_top.env.cov", "irq_vif", irq_bus);
        uvm_config_db#(virtual dma_mem_ctrl_if)::set(
            null, "*", "mem_ctrl_vif", mem_ctrl_bus);
        uvm_config_db#(virtual dma_reset_if)::set(
            null, "*", "reset_vif", reset_bus);
        uvm_config_db#(virtual dma_sva_ctrl_if)::set(
            null, "*", "sva_ctrl_vif", sva_ctrl_bus);
        uvm_config_db#(virtual dma_observer_if)::set(
            null, "uvm_test_top.env.obs_mon", "vif", observer_bus);
        uvm_config_db#(virtual dma_observer_if)::set(
            null, "uvm_test_top.env.outstanding_mon", "vif",
            observer_bus);
        run_test("dma_ral_smoke_test");
    end

    initial begin
        #2ms;
        $fatal(1, "Global UVM testbench timeout");
    end

`ifdef FSDB
    initial begin
        $fsdbDumpfile("axi_dma_uvm_stage10.fsdb");
        $fsdbDumpvars(0, tb_uvm_top);
    end
`endif

endmodule
