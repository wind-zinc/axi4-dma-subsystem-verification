`timescale 1ns/1ps

/*
 * Verification-only AXI4 proxy placed between the DMA and axi_ram.
 *
 * It can pause any AXI channel and replace RRESP/BRESP for address-matched
 * bursts.  Address requests are queued so the selected response remains
 * associated with the correct read burst or write response.
 */
module axi_mem_proxy #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 16,
    parameter integer STRB_WIDTH = DATA_WIDTH/8,
    parameter integer ID_WIDTH = 8,
    parameter integer RESPONSE_QUEUE_DEPTH = 32
) (
    input  wire                     clk,
    input  wire                     rst,
    dma_mem_ctrl_if                 ctrl,

    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    output wire [ID_WIDTH-1:0]      m_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awlock,
    output wire [3:0]               m_axi_awcache,
    output wire [2:0]               m_axi_awprot,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,
    output wire [ID_WIDTH-1:0]      m_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arlock,
    output wire [3:0]               m_axi_arcache,
    output wire [2:0]               m_axi_arprot,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [ID_WIDTH-1:0]      m_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);

    localparam integer PTR_WIDTH = $clog2(RESPONSE_QUEUE_DEPTH);
    localparam integer COUNT_WIDTH = $clog2(RESPONSE_QUEUE_DEPTH+1);

    reg [1:0] read_resp_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg [1:0] write_resp_fifo[0:RESPONSE_QUEUE_DEPTH-1];
    reg       read_inject_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg       write_inject_fifo[0:RESPONSE_QUEUE_DEPTH-1];
    reg [PTR_WIDTH-1:0] read_wr_ptr_reg = 0;
    reg [PTR_WIDTH-1:0] read_rd_ptr_reg = 0;
    reg [PTR_WIDTH-1:0] write_wr_ptr_reg = 0;
    reg [PTR_WIDTH-1:0] write_rd_ptr_reg = 0;
    reg [COUNT_WIDTH-1:0] read_count_reg = 0;
    reg [COUNT_WIDTH-1:0] write_count_reg = 0;

    wire read_addr_match = ctrl.read_fault_enable &&
        ((s_axi_araddr & ctrl.read_fault_mask) ==
         (ctrl.read_fault_addr & ctrl.read_fault_mask));
    wire write_addr_match = ctrl.write_fault_enable &&
        ((s_axi_awaddr & ctrl.write_fault_mask) ==
         (ctrl.write_fault_addr & ctrl.write_fault_mask));

    wire read_push = s_axi_arvalid && s_axi_arready;
    wire read_pop  = s_axi_rvalid && s_axi_rready && s_axi_rlast;
    wire write_push = s_axi_awvalid && s_axi_awready;
    wire write_pop  = s_axi_bvalid && s_axi_bready;

    function automatic [PTR_WIDTH-1:0] increment_ptr(
        input [PTR_WIDTH-1:0] ptr
    );
        if (ptr == RESPONSE_QUEUE_DEPTH-1)
            increment_ptr = {PTR_WIDTH{1'b0}};
        else
            increment_ptr = ptr + 1'b1;
    endfunction

    /* Address and write-data channels: stable combinational pass-through. */
    assign m_axi_awid    = s_axi_awid;
    assign m_axi_awaddr  = s_axi_awaddr;
    assign m_axi_awlen   = s_axi_awlen;
    assign m_axi_awsize  = s_axi_awsize;
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_awlock  = s_axi_awlock;
    assign m_axi_awcache = s_axi_awcache;
    assign m_axi_awprot  = s_axi_awprot;
    assign m_axi_awvalid = s_axi_awvalid && !ctrl.stall_aw;
    assign s_axi_awready = m_axi_awready && !ctrl.stall_aw;

    assign m_axi_wdata   = s_axi_wdata;
    assign m_axi_wstrb   = s_axi_wstrb;
    assign m_axi_wlast   = s_axi_wlast;
    assign m_axi_wvalid  = s_axi_wvalid && !ctrl.stall_w;
    assign s_axi_wready  = m_axi_wready && !ctrl.stall_w;

    assign m_axi_arid    = s_axi_arid;
    assign m_axi_araddr  = s_axi_araddr;
    assign m_axi_arlen   = s_axi_arlen;
    assign m_axi_arsize  = s_axi_arsize;
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arlock  = s_axi_arlock;
    assign m_axi_arcache = s_axi_arcache;
    assign m_axi_arprot  = s_axi_arprot;
    assign m_axi_arvalid = s_axi_arvalid && !ctrl.stall_ar;
    assign s_axi_arready = m_axi_arready && !ctrl.stall_ar;

    /* Response channels can be delayed without changing payload stability. */
    assign s_axi_bid    = m_axi_bid;
    assign s_axi_bresp  = write_count_reg != 0 &&
                          write_inject_fifo[write_rd_ptr_reg] ?
                          write_resp_fifo[write_rd_ptr_reg] : m_axi_bresp;
    assign s_axi_bvalid = m_axi_bvalid && !ctrl.stall_b;
    assign m_axi_bready = s_axi_bready && !ctrl.stall_b;

    assign s_axi_rid    = m_axi_rid;
    assign s_axi_rdata  = m_axi_rdata;
    assign s_axi_rresp  = read_count_reg != 0 &&
                          read_inject_fifo[read_rd_ptr_reg] ?
                          read_resp_fifo[read_rd_ptr_reg] : m_axi_rresp;
    assign s_axi_rlast  = m_axi_rlast;
    assign s_axi_rvalid = m_axi_rvalid && !ctrl.stall_r;
    assign m_axi_rready = s_axi_rready && !ctrl.stall_r;

    always @(posedge clk) begin
        if (rst) begin
            read_wr_ptr_reg  <= 0;
            read_rd_ptr_reg  <= 0;
            write_wr_ptr_reg <= 0;
            write_rd_ptr_reg <= 0;
            read_count_reg   <= 0;
            write_count_reg  <= 0;
            ctrl.read_fault_hits  <= 0;
            ctrl.write_fault_hits <= 0;
        end else begin
            if (ctrl.clear_stats) begin
                ctrl.read_fault_hits  <= 0;
                ctrl.write_fault_hits <= 0;
            end

            if (read_push) begin
                read_inject_fifo[read_wr_ptr_reg] <= read_addr_match;
                read_resp_fifo[read_wr_ptr_reg] <=
                    read_addr_match ? ctrl.read_fault_resp : 2'b00;
                read_wr_ptr_reg <= increment_ptr(read_wr_ptr_reg);
                if (read_addr_match)
                    ctrl.read_fault_hits <= ctrl.read_fault_hits + 1'b1;
            end

            if (read_pop)
                read_rd_ptr_reg <= increment_ptr(read_rd_ptr_reg);

            case ({read_push, read_pop})
                2'b10: read_count_reg <= read_count_reg + 1'b1;
                2'b01: read_count_reg <= read_count_reg - 1'b1;
                default: read_count_reg <= read_count_reg;
            endcase

            if (write_push) begin
                write_inject_fifo[write_wr_ptr_reg] <= write_addr_match;
                write_resp_fifo[write_wr_ptr_reg] <=
                    write_addr_match ? ctrl.write_fault_resp : 2'b00;
                write_wr_ptr_reg <= increment_ptr(write_wr_ptr_reg);
                if (write_addr_match)
                    ctrl.write_fault_hits <= ctrl.write_fault_hits + 1'b1;
            end

            if (write_pop)
                write_rd_ptr_reg <= increment_ptr(write_rd_ptr_reg);

            case ({write_push, write_pop})
                2'b10: write_count_reg <= write_count_reg + 1'b1;
                2'b01: write_count_reg <= write_count_reg - 1'b1;
                default: write_count_reg <= write_count_reg;
            endcase
        end
    end

endmodule
