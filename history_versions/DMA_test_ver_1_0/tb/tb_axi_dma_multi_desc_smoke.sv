`timescale 1ns/1ps

module tb_axi_dma_multi_desc_smoke;

localparam AXIL_ADDR_WIDTH = 8;
localparam AXI_ADDR_WIDTH = 16;
localparam AXI_DATA_WIDTH = 32;
localparam AXI_ID_WIDTH = 8;
localparam AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;

localparam [7:0] REG_CONTROL         = 8'h00;
localparam [7:0] REG_STATUS          = 8'h04;
localparam [7:0] REG_SRC_ADDR        = 8'h08;
localparam [7:0] REG_DST_ADDR        = 8'h0c;
localparam [7:0] REG_LENGTH          = 8'h10;
localparam [7:0] REG_TAG             = 8'h14;
localparam [7:0] REG_SUBMIT          = 8'h18;
localparam [7:0] REG_COMP_TAG        = 8'h1c;
localparam [7:0] REG_COMP_LENGTH     = 8'h20;
localparam [7:0] REG_COMP_STATUS     = 8'h24;
localparam [7:0] REG_COMP_POP        = 8'h28;
localparam [7:0] REG_QUEUE_LEVELS    = 8'h2c;
localparam [7:0] REG_SUBMITTED_COUNT = 8'h30;
localparam [7:0] REG_COMPLETED_COUNT = 8'h34;

localparam [AXI_ADDR_WIDTH-1:0] SRC0 = 16'h1000;
localparam [AXI_ADDR_WIDTH-1:0] DST0 = 16'h3000;
localparam integer WORDS0 = 128;
localparam integer BYTES0 = WORDS0 * AXI_STRB_WIDTH;
localparam [7:0] TAG0 = 8'h11;

localparam [AXI_ADDR_WIDTH-1:0] SRC1 = 16'h1800;
localparam [AXI_ADDR_WIDTH-1:0] DST1 = 16'h3800;
localparam integer WORDS1 = 16;
localparam integer BYTES1 = WORDS1 * AXI_STRB_WIDTH;
localparam [7:0] TAG1 = 8'h22;

localparam [AXI_ADDR_WIDTH-1:0] SRC2 = 16'h1c00;
localparam [AXI_ADDR_WIDTH-1:0] DST2 = 16'h3c00;
localparam integer WORDS2 = 24;
localparam integer BYTES2 = WORDS2 * AXI_STRB_WIDTH;
localparam [7:0] TAG2 = 8'h33;

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

reg  [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr = 0;
reg  [2:0]                 s_axil_awprot = 0;
reg                        s_axil_awvalid = 0;
wire                       s_axil_awready;
reg  [31:0]                s_axil_wdata = 0;
reg  [3:0]                 s_axil_wstrb = 0;
reg                        s_axil_wvalid = 0;
wire                       s_axil_wready;
wire [1:0]                 s_axil_bresp;
wire                       s_axil_bvalid;
reg                        s_axil_bready = 0;
reg  [AXIL_ADDR_WIDTH-1:0] s_axil_araddr = 0;
reg  [2:0]                 s_axil_arprot = 0;
reg                        s_axil_arvalid = 0;
wire                       s_axil_arready;
wire [31:0]                s_axil_rdata;
wire [1:0]                 s_axil_rresp;
wire                       s_axil_rvalid;
reg                        s_axil_rready = 0;

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
wire                      irq;

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
    .ENABLE_UNALIGNED(0)
)
dut (
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

axi_ram #(
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(AXI_ID_WIDTH),
    .PIPELINE_OUTPUT(0)
)
ram_inst (
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

/* AW and W are independent AXI-Lite channels and are waited independently. */
task automatic axil_write;
    input [AXIL_ADDR_WIDTH-1:0] addr;
    input [31:0] data;
    integer aw_timeout;
    integer w_timeout;
    integer b_timeout;
    begin
        @(negedge clk);
        s_axil_awaddr = addr;
        s_axil_awvalid = 1'b1;
        s_axil_wdata = data;
        s_axil_wstrb = 4'hf;
        s_axil_wvalid = 1'b1;
        s_axil_bready = 1'b1;

        fork
            begin
                aw_timeout = 0;
                while (!s_axil_awready && aw_timeout < 2000) begin
                    @(posedge clk);
                    aw_timeout = aw_timeout + 1;
                end
                if (!s_axil_awready)
                    $fatal(1, "AXI-Lite AW timeout");
                @(negedge clk);
                s_axil_awvalid = 1'b0;
            end
            begin
                w_timeout = 0;
                while (!s_axil_wready && w_timeout < 2000) begin
                    @(posedge clk);
                    w_timeout = w_timeout + 1;
                end
                if (!s_axil_wready)
                    $fatal(1, "AXI-Lite W timeout");
                @(negedge clk);
                s_axil_wvalid = 1'b0;
            end
        join

        b_timeout = 0;
        while (!s_axil_bvalid && b_timeout < 2000) begin
            @(negedge clk);
            b_timeout = b_timeout + 1;
        end
        if (!s_axil_bvalid)
            $fatal(1, "AXI-Lite B timeout");
        if (s_axil_bresp != 2'b00)
            $fatal(1, "AXI-Lite write response error");

        @(posedge clk);
        @(negedge clk);
        s_axil_bready = 1'b0;
    end
endtask

task automatic axil_read;
    input [AXIL_ADDR_WIDTH-1:0] addr;
    output [31:0] data;
    integer ar_timeout;
    integer r_timeout;
    begin
        @(negedge clk);
        s_axil_araddr = addr;
        s_axil_arvalid = 1'b1;
        s_axil_rready = 1'b1;

        ar_timeout = 0;
        while (!s_axil_arready && ar_timeout < 2000) begin
            @(posedge clk);
            ar_timeout = ar_timeout + 1;
        end
        if (!s_axil_arready)
            $fatal(1, "AXI-Lite AR timeout");

        @(negedge clk);
        s_axil_arvalid = 1'b0;

        r_timeout = 0;
        while (!s_axil_rvalid && r_timeout < 2000) begin
            @(negedge clk);
            r_timeout = r_timeout + 1;
        end
        if (!s_axil_rvalid)
            $fatal(1, "AXI-Lite R timeout");
        if (s_axil_rresp != 2'b00)
            $fatal(1, "AXI-Lite read response error");

        data = s_axil_rdata;
        @(posedge clk);
        @(negedge clk);
        s_axil_rready = 1'b0;
    end
endtask

task automatic submit_descriptor;
    input [AXI_ADDR_WIDTH-1:0] src_addr;
    input [AXI_ADDR_WIDTH-1:0] dst_addr;
    input [31:0] byte_length;
    input [7:0] tag;
    begin
        axil_write(REG_SRC_ADDR, src_addr);
        axil_write(REG_DST_ADDR, dst_addr);
        axil_write(REG_LENGTH, byte_length);
        axil_write(REG_TAG, tag);
        axil_write(REG_SUBMIT, 32'h0000_0001);
    end
endtask

task automatic check_and_pop_completion;
    input [7:0] expected_tag;
    input [31:0] expected_length;
    integer irq_timeout;
    reg [31:0] value;
    begin
        irq_timeout = 0;
        while (!irq && irq_timeout < 10000) begin
            @(posedge clk);
            irq_timeout = irq_timeout + 1;
        end
        if (!irq)
            $fatal(1, "DMA completion timeout for tag %0h", expected_tag);

        axil_read(REG_STATUS, value);
        if (!value[4] || !value[6] || value[10:7] != 0)
            $fatal(1, "Unexpected manager status 0x%08x", value);

        axil_read(REG_COMP_TAG, value);
        if (value[7:0] != expected_tag)
            $fatal(1, "Completion tag mismatch: got %0h expected %0h",
                   value[7:0], expected_tag);

        axil_read(REG_COMP_LENGTH, value);
        if (value != expected_length)
            $fatal(1, "Completion length mismatch: got %0d expected %0d",
                   value, expected_length);

        axil_read(REG_COMP_STATUS, value);
        if (value[10:0] != 0)
            $fatal(1, "DMA completion reported status 0x%08x", value);

        axil_write(REG_COMP_POP, 32'h0000_0001);
    end
endtask

integer i;
reg [31:0] value;

initial begin
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);

    for (i = 0; i < WORDS0; i = i + 1) begin
        ram_inst.mem[(SRC0 >> 2) + i] = 32'hA100_0000 + i;
        ram_inst.mem[(DST0 >> 2) + i] = 32'd0;
    end
    for (i = 0; i < WORDS1; i = i + 1) begin
        ram_inst.mem[(SRC1 >> 2) + i] = 32'hB200_0000 + i;
        ram_inst.mem[(DST1 >> 2) + i] = 32'd0;
    end
    for (i = 0; i < WORDS2; i = i + 1) begin
        ram_inst.mem[(SRC2 >> 2) + i] = 32'hC300_0000 + i;
        ram_inst.mem[(DST2 >> 2) + i] = 32'd0;
    end

    axil_write(REG_CONTROL, 32'h0000_0001);

    submit_descriptor(SRC0, DST0, BYTES0, TAG0);
    submit_descriptor(SRC1, DST1, BYTES1, TAG1);
    submit_descriptor(SRC2, DST2, BYTES2, TAG2);

    axil_read(REG_SUBMITTED_COUNT, value);
    if (value != 3)
        $fatal(1, "Expected three accepted descriptors, got %0d", value);

    axil_read(REG_QUEUE_LEVELS, value);
    if (value[15:0] == 0)
        $fatal(1, "Smoke test did not observe queued descriptors");

    check_and_pop_completion(TAG0, BYTES0);
    check_and_pop_completion(TAG1, BYTES1);
    check_and_pop_completion(TAG2, BYTES2);

    axil_read(REG_COMPLETED_COUNT, value);
    if (value != 3)
        $fatal(1, "Expected three completed descriptors, got %0d", value);

    for (i = 0; i < WORDS0; i = i + 1)
        if (ram_inst.mem[(DST0 >> 2) + i] !== 32'hA100_0000 + i)
            $fatal(1, "Descriptor 0 data mismatch at word %0d", i);

    for (i = 0; i < WORDS1; i = i + 1)
        if (ram_inst.mem[(DST1 >> 2) + i] !== 32'hB200_0000 + i)
            $fatal(1, "Descriptor 1 data mismatch at word %0d", i);

    for (i = 0; i < WORDS2; i = i + 1)
        if (ram_inst.mem[(DST2 >> 2) + i] !== 32'hC300_0000 + i)
            $fatal(1, "Descriptor 2 data mismatch at word %0d", i);

    repeat (2) @(posedge clk);
    if (irq)
        $fatal(1, "IRQ remained asserted after all completions were popped");

    $display("AXI DMA multi-descriptor smoke test PASS");
    $finish;
end

initial begin
    $fsdbDumpfile("axi_dma_multi_desc_smoke.fsdb");
    $fsdbDumpvars(0, tb_axi_dma_multi_desc_smoke);
end

endmodule
