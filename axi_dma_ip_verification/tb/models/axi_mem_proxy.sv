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

    /*
     * The bundled axi_ram accepts only one address burst at a time.  These
     * verification-only queues let the DMA hand off several AR/AW requests
     * before the RAM consumes them, so accepted outstanding depth can be
     * measured without changing either the DUT or vendor RAM model.
     */
    reg [ID_WIDTH-1:0]   ar_id_fifo    [0:RESPONSE_QUEUE_DEPTH-1];
    reg [ADDR_WIDTH-1:0] ar_addr_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [7:0]            ar_len_fifo   [0:RESPONSE_QUEUE_DEPTH-1];
    reg [2:0]            ar_size_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [1:0]            ar_burst_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg                  ar_lock_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [3:0]            ar_cache_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg [2:0]            ar_prot_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [PTR_WIDTH-1:0]  ar_wr_ptr_reg = 0;
    reg [PTR_WIDTH-1:0]  ar_rd_ptr_reg = 0;
    reg [COUNT_WIDTH-1:0] ar_count_reg = 0;

    reg [ID_WIDTH-1:0]   aw_id_fifo    [0:RESPONSE_QUEUE_DEPTH-1];
    reg [ADDR_WIDTH-1:0] aw_addr_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [7:0]            aw_len_fifo   [0:RESPONSE_QUEUE_DEPTH-1];
    reg [2:0]            aw_size_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [1:0]            aw_burst_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg                  aw_lock_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [3:0]            aw_cache_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg [2:0]            aw_prot_fifo  [0:RESPONSE_QUEUE_DEPTH-1];
    reg [PTR_WIDTH-1:0]  aw_wr_ptr_reg = 0;
    reg [PTR_WIDTH-1:0]  aw_rd_ptr_reg = 0;
    reg [COUNT_WIDTH-1:0] aw_count_reg = 0;

    /* B responses are buffered so a stalled DUT response channel does not
     * make the single-burst RAM stop accepting queued write addresses. */
    reg [ID_WIDTH-1:0]   b_id_fifo   [0:RESPONSE_QUEUE_DEPTH-1];
    reg [1:0]            b_resp_fifo [0:RESPONSE_QUEUE_DEPTH-1];
    reg [PTR_WIDTH-1:0]  b_wr_ptr_reg = 0;
    reg [PTR_WIDTH-1:0]  b_rd_ptr_reg = 0;
    reg [COUNT_WIDTH-1:0] b_count_reg = 0;

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

    wire ar_queue_push = ctrl.outstanding_mode && read_push;
    wire ar_queue_pop = ctrl.outstanding_mode &&
                        m_axi_arvalid && m_axi_arready;
    wire aw_queue_push = ctrl.outstanding_mode && write_push;
    wire aw_queue_pop = ctrl.outstanding_mode &&
                        m_axi_awvalid && m_axi_awready;
    wire b_queue_push = ctrl.outstanding_mode &&
                        m_axi_bvalid && m_axi_bready;
    wire b_queue_pop = ctrl.outstanding_mode && write_pop;

    function automatic [PTR_WIDTH-1:0] increment_ptr(
        input [PTR_WIDTH-1:0] ptr
    );
        if (ptr == RESPONSE_QUEUE_DEPTH-1)
            increment_ptr = {PTR_WIDTH{1'b0}};
        else
            increment_ptr = ptr + 1'b1;
    endfunction

    /* Address channels are pass-through normally and queued in outstanding
     * mode.  The response-metadata queue is also part of the ready limit. */
    assign m_axi_awid = ctrl.outstanding_mode ?
                        aw_id_fifo[aw_rd_ptr_reg] : s_axi_awid;
    assign m_axi_awaddr = ctrl.outstanding_mode ?
                          aw_addr_fifo[aw_rd_ptr_reg] : s_axi_awaddr;
    assign m_axi_awlen = ctrl.outstanding_mode ?
                         aw_len_fifo[aw_rd_ptr_reg] : s_axi_awlen;
    assign m_axi_awsize = ctrl.outstanding_mode ?
                          aw_size_fifo[aw_rd_ptr_reg] : s_axi_awsize;
    assign m_axi_awburst = ctrl.outstanding_mode ?
                           aw_burst_fifo[aw_rd_ptr_reg] : s_axi_awburst;
    assign m_axi_awlock = ctrl.outstanding_mode ?
                          aw_lock_fifo[aw_rd_ptr_reg] : s_axi_awlock;
    assign m_axi_awcache = ctrl.outstanding_mode ?
                           aw_cache_fifo[aw_rd_ptr_reg] : s_axi_awcache;
    assign m_axi_awprot = ctrl.outstanding_mode ?
                          aw_prot_fifo[aw_rd_ptr_reg] : s_axi_awprot;
    assign m_axi_awvalid = ctrl.outstanding_mode ?
                           (aw_count_reg != 0) :
                           (s_axi_awvalid && !ctrl.stall_aw &&
                            write_count_reg < RESPONSE_QUEUE_DEPTH);
    assign s_axi_awready = ctrl.outstanding_mode ?
                           (!ctrl.stall_aw &&
                            aw_count_reg < RESPONSE_QUEUE_DEPTH &&
                            write_count_reg < RESPONSE_QUEUE_DEPTH) :
                           (m_axi_awready && !ctrl.stall_aw &&
                            write_count_reg < RESPONSE_QUEUE_DEPTH);

    assign m_axi_wdata   = s_axi_wdata;
    assign m_axi_wstrb   = s_axi_wstrb;
    assign m_axi_wlast   = s_axi_wlast;
    assign m_axi_wvalid  = s_axi_wvalid && !ctrl.stall_w;
    assign s_axi_wready  = m_axi_wready && !ctrl.stall_w;

    assign m_axi_arid = ctrl.outstanding_mode ?
                        ar_id_fifo[ar_rd_ptr_reg] : s_axi_arid;
    assign m_axi_araddr = ctrl.outstanding_mode ?
                          ar_addr_fifo[ar_rd_ptr_reg] : s_axi_araddr;
    assign m_axi_arlen = ctrl.outstanding_mode ?
                         ar_len_fifo[ar_rd_ptr_reg] : s_axi_arlen;
    assign m_axi_arsize = ctrl.outstanding_mode ?
                          ar_size_fifo[ar_rd_ptr_reg] : s_axi_arsize;
    assign m_axi_arburst = ctrl.outstanding_mode ?
                           ar_burst_fifo[ar_rd_ptr_reg] : s_axi_arburst;
    assign m_axi_arlock = ctrl.outstanding_mode ?
                          ar_lock_fifo[ar_rd_ptr_reg] : s_axi_arlock;
    assign m_axi_arcache = ctrl.outstanding_mode ?
                           ar_cache_fifo[ar_rd_ptr_reg] : s_axi_arcache;
    assign m_axi_arprot = ctrl.outstanding_mode ?
                          ar_prot_fifo[ar_rd_ptr_reg] : s_axi_arprot;
    assign m_axi_arvalid = ctrl.outstanding_mode ?
                           (ar_count_reg != 0) :
                           (s_axi_arvalid && !ctrl.stall_ar &&
                            read_count_reg < RESPONSE_QUEUE_DEPTH);
    assign s_axi_arready = ctrl.outstanding_mode ?
                           (!ctrl.stall_ar &&
                            ar_count_reg < RESPONSE_QUEUE_DEPTH &&
                            read_count_reg < RESPONSE_QUEUE_DEPTH) :
                           (m_axi_arready && !ctrl.stall_ar &&
                            read_count_reg < RESPONSE_QUEUE_DEPTH);

    /* Response channels can be delayed without changing payload stability. */
    assign s_axi_bid = ctrl.outstanding_mode ?
                       b_id_fifo[b_rd_ptr_reg] : m_axi_bid;
    assign s_axi_bresp  = write_count_reg != 0 &&
                          write_inject_fifo[write_rd_ptr_reg] ?
                          write_resp_fifo[write_rd_ptr_reg] :
                          (ctrl.outstanding_mode ?
                           b_resp_fifo[b_rd_ptr_reg] : m_axi_bresp);
    assign s_axi_bvalid = ctrl.outstanding_mode ?
                          (b_count_reg != 0 && !ctrl.stall_b) :
                          (m_axi_bvalid && !ctrl.stall_b);
    assign m_axi_bready = ctrl.outstanding_mode ?
                          (b_count_reg < RESPONSE_QUEUE_DEPTH) :
                          (s_axi_bready && !ctrl.stall_b);

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
            ar_wr_ptr_reg    <= 0;
            ar_rd_ptr_reg    <= 0;
            ar_count_reg     <= 0;
            aw_wr_ptr_reg    <= 0;
            aw_rd_ptr_reg    <= 0;
            aw_count_reg     <= 0;
            b_wr_ptr_reg     <= 0;
            b_rd_ptr_reg     <= 0;
            b_count_reg      <= 0;
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

            if (ar_queue_push) begin
                ar_id_fifo[ar_wr_ptr_reg]    <= s_axi_arid;
                ar_addr_fifo[ar_wr_ptr_reg]  <= s_axi_araddr;
                ar_len_fifo[ar_wr_ptr_reg]   <= s_axi_arlen;
                ar_size_fifo[ar_wr_ptr_reg]  <= s_axi_arsize;
                ar_burst_fifo[ar_wr_ptr_reg] <= s_axi_arburst;
                ar_lock_fifo[ar_wr_ptr_reg]  <= s_axi_arlock;
                ar_cache_fifo[ar_wr_ptr_reg] <= s_axi_arcache;
                ar_prot_fifo[ar_wr_ptr_reg]  <= s_axi_arprot;
                ar_wr_ptr_reg <= increment_ptr(ar_wr_ptr_reg);
            end
            if (ar_queue_pop)
                ar_rd_ptr_reg <= increment_ptr(ar_rd_ptr_reg);
            case ({ar_queue_push, ar_queue_pop})
                2'b10: ar_count_reg <= ar_count_reg + 1'b1;
                2'b01: ar_count_reg <= ar_count_reg - 1'b1;
                default: ar_count_reg <= ar_count_reg;
            endcase

            if (aw_queue_push) begin
                aw_id_fifo[aw_wr_ptr_reg]    <= s_axi_awid;
                aw_addr_fifo[aw_wr_ptr_reg]  <= s_axi_awaddr;
                aw_len_fifo[aw_wr_ptr_reg]   <= s_axi_awlen;
                aw_size_fifo[aw_wr_ptr_reg]  <= s_axi_awsize;
                aw_burst_fifo[aw_wr_ptr_reg] <= s_axi_awburst;
                aw_lock_fifo[aw_wr_ptr_reg]  <= s_axi_awlock;
                aw_cache_fifo[aw_wr_ptr_reg] <= s_axi_awcache;
                aw_prot_fifo[aw_wr_ptr_reg]  <= s_axi_awprot;
                aw_wr_ptr_reg <= increment_ptr(aw_wr_ptr_reg);
            end
            if (aw_queue_pop)
                aw_rd_ptr_reg <= increment_ptr(aw_rd_ptr_reg);
            case ({aw_queue_push, aw_queue_pop})
                2'b10: aw_count_reg <= aw_count_reg + 1'b1;
                2'b01: aw_count_reg <= aw_count_reg - 1'b1;
                default: aw_count_reg <= aw_count_reg;
            endcase

            if (b_queue_push) begin
                b_id_fifo[b_wr_ptr_reg]   <= m_axi_bid;
                b_resp_fifo[b_wr_ptr_reg] <= m_axi_bresp;
                b_wr_ptr_reg <= increment_ptr(b_wr_ptr_reg);
            end
            if (b_queue_pop)
                b_rd_ptr_reg <= increment_ptr(b_rd_ptr_reg);
            case ({b_queue_push, b_queue_pop})
                2'b10: b_count_reg <= b_count_reg + 1'b1;
                2'b01: b_count_reg <= b_count_reg - 1'b1;
                default: b_count_reg <= b_count_reg;
            endcase
        end
    end

endmodule
