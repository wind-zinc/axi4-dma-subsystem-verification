/*
 * AXI-Lite controlled multi-descriptor DMA manager.
 *
 * Software writes one descriptor into the staging registers, then writes 1
 * to SUBMIT.  Accepted descriptors are copied atomically into a request FIFO,
 * so software may prepare later descriptors while the DMA is busy.
 *
 * Descriptors execute in order, one at a time.  The manager sends the write
 * descriptor first, then the read descriptor, and waits for both status
 * pulses before starting the next request.  Every completed request produces
 * one entry in a completion FIFO.  The IRQ is level-sensitive while that FIFO
 * is non-empty.
 *
 * Register map (32-bit AXI-Lite data bus):
 *   0x00 CONTROL          bit 0 IRQ_ENABLE, bit 1 CLEAR_STICKY (W1P)
 *   0x04 STATUS           queue, active, IRQ, and sticky status bits
 *   0x08 SRC_ADDR         descriptor staging source address
 *   0x0c DST_ADDR         descriptor staging destination address
 *   0x10 LENGTH           descriptor staging byte length
 *   0x14 TAG              descriptor staging tag
 *   0x18 SUBMIT           bit 0 submits the staged descriptor (W1P)
 *   0x1c COMP_TAG         tag at the completion FIFO head
 *   0x20 COMP_LENGTH      actual write length at the completion FIFO head
 *   0x24 COMP_STATUS      read/write errors and mismatch flags
 *   0x28 COMP_POP         bit 0 removes the completion FIFO head (W1P)
 *   0x2c QUEUE_LEVELS     [15:0] request level, [31:16] completion level
 *   0x30 SUBMITTED_COUNT  number of accepted descriptors
 *   0x34 COMPLETED_COUNT  cumulative number of completion records produced
 *
 * STATUS bits:
 *   0 ACTIVE, 1 REQ_EMPTY, 2 REQ_FULL, 3 SUBMIT_READY,
 *   4 COMP_VALID, 5 COMP_FULL, 6 IRQ,
 *   7 REJECT_FULL_STICKY, 8 REJECT_INVALID_STICKY,
 *   9 STATUS_MISMATCH_STICKY, 10 POP_EMPTY_STICKY
 *
 * COMP_STATUS bits:
 *   [3:0] read error, [7:4] write error,
 *   8 read-tag mismatch, 9 write-tag mismatch, 10 length mismatch
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module dma_desc_manager #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 8,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXI_ADDR_WIDTH = 16,
    parameter AXI_STRB_WIDTH = 4,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8,
    parameter DESC_FIFO_DEPTH = 4,
    parameter COMP_FIFO_DEPTH = 4,
    parameter ENABLE_UNALIGNED = 0
)(
    input  wire                         clk,
    input  wire                         rst,

    /* AXI-Lite slave interface */
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]   s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,

    /* Descriptor outputs to axi_dma */
    output wire [AXI_ADDR_WIDTH-1:0]    read_desc_addr,
    output wire [LEN_WIDTH-1:0]         read_desc_len,
    output wire [TAG_WIDTH-1:0]         read_desc_tag,
    output wire                         read_desc_valid,
    input  wire                         read_desc_ready,

    output wire [AXI_ADDR_WIDTH-1:0]    write_desc_addr,
    output wire [LEN_WIDTH-1:0]         write_desc_len,
    output wire [TAG_WIDTH-1:0]         write_desc_tag,
    output wire                         write_desc_valid,
    input  wire                         write_desc_ready,

    /* Status inputs from axi_dma; these are one-cycle pulses */
    input  wire [TAG_WIDTH-1:0]         read_status_tag,
    input  wire [3:0]                   read_status_error,
    input  wire                         read_status_valid,

    input  wire [LEN_WIDTH-1:0]         write_status_len,
    input  wire [TAG_WIDTH-1:0]         write_status_tag,
    input  wire [3:0]                   write_status_error,
    input  wire                         write_status_valid,

    output wire                         irq
);

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

localparam [2:0]
    STATE_IDLE            = 3'd0,
    STATE_SEND_WRITE      = 3'd1,
    STATE_SEND_READ       = 3'd2,
    STATE_WAIT_STATUS     = 3'd3,
    STATE_PUSH_COMPLETION = 3'd4;

localparam DESC_WIDTH = 2*AXI_ADDR_WIDTH + LEN_WIDTH + TAG_WIDTH;
localparam COMP_FLAGS_WIDTH = 3;
localparam COMP_WIDTH = TAG_WIDTH + LEN_WIDTH + COMP_FLAGS_WIDTH + 8;
localparam REQ_LEVEL_WIDTH = $clog2(DESC_FIFO_DEPTH+1);
localparam COMP_LEVEL_WIDTH = $clog2(COMP_FIFO_DEPTH+1);
localparam [31:0] ALIGNMENT_MASK = AXI_STRB_WIDTH-1;

/* AXI-Lite to simple register interface */
wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr;
wire [AXIL_DATA_WIDTH-1:0] reg_wr_data;
wire [AXIL_STRB_WIDTH-1:0] reg_wr_strb;
wire reg_wr_en;
wire reg_wr_wait;
wire reg_wr_ack;

wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr;
wire reg_rd_en;
reg  [AXIL_DATA_WIDTH-1:0] reg_rd_data;
wire reg_rd_wait;
wire reg_rd_ack;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack = reg_wr_en;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack = reg_rd_en;

axil_reg_if #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_STRB_WIDTH),
    .TIMEOUT(4)
)
axil_reg_if_inst (
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
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(reg_wr_wait),
    .reg_wr_ack(reg_wr_ack),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(reg_rd_data),
    .reg_rd_wait(reg_rd_wait),
    .reg_rd_ack(reg_rd_ack)
);

function [AXIL_DATA_WIDTH-1:0] apply_wstrb;
    input [AXIL_DATA_WIDTH-1:0] old_value;
    input [AXIL_DATA_WIDTH-1:0] new_value;
    input [AXIL_STRB_WIDTH-1:0] write_strobe;
    integer byte_index;
    begin
        apply_wstrb = old_value;
        for (byte_index = 0; byte_index < AXIL_STRB_WIDTH; byte_index = byte_index + 1) begin
            if (write_strobe[byte_index])
                apply_wstrb[byte_index*8 +: 8] = new_value[byte_index*8 +: 8];
        end
    end
endfunction

/* Software-visible staging and sticky state */
reg [31:0] src_addr_cfg_reg = 32'd0;
reg [31:0] dst_addr_cfg_reg = 32'd0;
reg [31:0] length_cfg_reg = 32'd0;
reg [31:0] tag_cfg_reg = 32'd0;
reg irq_enable_reg = 1'b0;

reg reject_full_sticky_reg = 1'b0;
reg reject_invalid_sticky_reg = 1'b0;
reg status_mismatch_sticky_reg = 1'b0;
reg pop_empty_sticky_reg = 1'b0;
reg [31:0] submitted_count_reg = 32'd0;

wire submit_event = reg_wr_en && reg_wr_addr[7:0] == REG_SUBMIT &&
                    reg_wr_strb[0] && reg_wr_data[0];
wire clear_sticky_event = reg_wr_en && reg_wr_addr[7:0] == REG_CONTROL &&
                          reg_wr_strb[0] && reg_wr_data[1];
wire pop_completion_event = reg_wr_en && reg_wr_addr[7:0] == REG_COMP_POP &&
                            reg_wr_strb[0] && reg_wr_data[0];

/* Validate before narrowing the 32-bit staging registers. */
wire src_addr_fits = (src_addr_cfg_reg >> AXI_ADDR_WIDTH) == 0;
wire dst_addr_fits = (dst_addr_cfg_reg >> AXI_ADDR_WIDTH) == 0;
wire length_fits = (length_cfg_reg >> LEN_WIDTH) == 0;
wire tag_fits = (tag_cfg_reg >> TAG_WIDTH) == 0;
wire addresses_aligned = ENABLE_UNALIGNED ||
                         (((src_addr_cfg_reg & ALIGNMENT_MASK) == 0) &&
                          ((dst_addr_cfg_reg & ALIGNMENT_MASK) == 0));
wire staged_desc_valid = length_cfg_reg != 0 && src_addr_fits &&
                         dst_addr_fits && length_fits && tag_fits &&
                         addresses_aligned;

wire [AXI_ADDR_WIDTH-1:0] staged_src_addr = src_addr_cfg_reg[AXI_ADDR_WIDTH-1:0];
wire [AXI_ADDR_WIDTH-1:0] staged_dst_addr = dst_addr_cfg_reg[AXI_ADDR_WIDTH-1:0];
wire [LEN_WIDTH-1:0] staged_length = length_cfg_reg[LEN_WIDTH-1:0];
wire [TAG_WIDTH-1:0] staged_tag = tag_cfg_reg[TAG_WIDTH-1:0];

/* Request FIFO */
wire [DESC_WIDTH-1:0] req_fifo_s_data = {
    staged_src_addr, staged_dst_addr, staged_length, staged_tag
};
wire req_fifo_s_valid = submit_event && staged_desc_valid;
wire req_fifo_s_ready;
wire [DESC_WIDTH-1:0] req_fifo_m_data;
wire req_fifo_m_valid;
wire req_fifo_m_ready;
wire [REQ_LEVEL_WIDTH-1:0] req_fifo_level;
wire req_fifo_full;
wire req_fifo_empty;

wire [AXI_ADDR_WIDTH-1:0] req_head_src_addr;
wire [AXI_ADDR_WIDTH-1:0] req_head_dst_addr;
wire [LEN_WIDTH-1:0] req_head_length;
wire [TAG_WIDTH-1:0] req_head_tag;

assign {req_head_src_addr, req_head_dst_addr, req_head_length, req_head_tag} =
       req_fifo_m_data;

desc_fifo #(
    .DATA_WIDTH(DESC_WIDTH),
    .DEPTH(DESC_FIFO_DEPTH)
)
request_fifo_inst (
    .clk(clk),
    .rst(rst),
    .s_data(req_fifo_s_data),
    .s_valid(req_fifo_s_valid),
    .s_ready(req_fifo_s_ready),
    .m_data(req_fifo_m_data),
    .m_valid(req_fifo_m_valid),
    .m_ready(req_fifo_m_ready),
    .level(req_fifo_level),
    .full(req_fifo_full),
    .empty(req_fifo_empty)
);

/* Completion FIFO */
reg [TAG_WIDTH-1:0] pending_tag_reg = {TAG_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0] pending_length_reg = {LEN_WIDTH{1'b0}};
reg [COMP_FLAGS_WIDTH-1:0] pending_flags_reg = {COMP_FLAGS_WIDTH{1'b0}};
reg [3:0] pending_write_error_reg = 4'd0;
reg [3:0] pending_read_error_reg = 4'd0;

wire [COMP_WIDTH-1:0] comp_fifo_s_data = {
    pending_tag_reg,
    pending_length_reg,
    pending_flags_reg,
    pending_write_error_reg,
    pending_read_error_reg
};
wire comp_fifo_s_valid;
wire comp_fifo_s_ready;
wire [COMP_WIDTH-1:0] comp_fifo_m_data;
wire comp_fifo_m_valid;
wire comp_fifo_m_ready;
wire [COMP_LEVEL_WIDTH-1:0] comp_fifo_level;
wire comp_fifo_full;
wire comp_fifo_empty;

wire [TAG_WIDTH-1:0] comp_head_tag;
wire [LEN_WIDTH-1:0] comp_head_length;
wire [COMP_FLAGS_WIDTH-1:0] comp_head_flags;
wire [3:0] comp_head_write_error;
wire [3:0] comp_head_read_error;

assign {comp_head_tag, comp_head_length, comp_head_flags,
        comp_head_write_error, comp_head_read_error} = comp_fifo_m_data;

assign comp_fifo_m_ready = pop_completion_event && comp_fifo_m_valid;

desc_fifo #(
    .DATA_WIDTH(COMP_WIDTH),
    .DEPTH(COMP_FIFO_DEPTH)
)
completion_fifo_inst (
    .clk(clk),
    .rst(rst),
    .s_data(comp_fifo_s_data),
    .s_valid(comp_fifo_s_valid),
    .s_ready(comp_fifo_s_ready),
    .m_data(comp_fifo_m_data),
    .m_valid(comp_fifo_m_valid),
    .m_ready(comp_fifo_m_ready),
    .level(comp_fifo_level),
    .full(comp_fifo_full),
    .empty(comp_fifo_empty)
);

/* One descriptor is active at a time. */
reg [2:0] state_reg = STATE_IDLE;
reg [AXI_ADDR_WIDTH-1:0] active_src_addr_reg = {AXI_ADDR_WIDTH{1'b0}};
reg [AXI_ADDR_WIDTH-1:0] active_dst_addr_reg = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0] active_length_reg = {LEN_WIDTH{1'b0}};
reg [TAG_WIDTH-1:0] active_tag_reg = {TAG_WIDTH{1'b0}};

reg read_status_seen_reg = 1'b0;
reg write_status_seen_reg = 1'b0;
reg [3:0] captured_read_error_reg = 4'd0;
reg [3:0] captured_write_error_reg = 4'd0;
reg [LEN_WIDTH-1:0] captured_write_length_reg = {LEN_WIDTH{1'b0}};
reg read_tag_mismatch_reg = 1'b0;
reg write_tag_mismatch_reg = 1'b0;
reg length_mismatch_reg = 1'b0;
reg [31:0] completed_count_reg = 32'd0;

wire status_capture_enable = state_reg == STATE_SEND_READ ||
                             state_reg == STATE_WAIT_STATUS;
wire all_status_seen_now =
    (read_status_seen_reg || (status_capture_enable && read_status_valid)) &&
    (write_status_seen_reg || (status_capture_enable && write_status_valid));

wire [3:0] final_read_error = read_status_valid ?
                              read_status_error : captured_read_error_reg;
wire [3:0] final_write_error = write_status_valid ?
                               write_status_error : captured_write_error_reg;
wire [LEN_WIDTH-1:0] final_write_length = write_status_valid ?
                                         write_status_len : captured_write_length_reg;
wire final_read_tag_mismatch = read_status_valid ?
                               (read_status_tag != active_tag_reg) :
                               read_tag_mismatch_reg;
wire final_write_tag_mismatch = write_status_valid ?
                                (write_status_tag != active_tag_reg) :
                                write_tag_mismatch_reg;
wire final_length_mismatch = write_status_valid ?
                             (write_status_len != active_length_reg) :
                             length_mismatch_reg;

assign req_fifo_m_ready = state_reg == STATE_IDLE && !comp_fifo_full;
assign comp_fifo_s_valid = state_reg == STATE_PUSH_COMPLETION;

assign read_desc_addr = active_src_addr_reg;
assign read_desc_len = active_length_reg;
assign read_desc_tag = active_tag_reg;
assign read_desc_valid = state_reg == STATE_SEND_READ;

assign write_desc_addr = active_dst_addr_reg;
assign write_desc_len = active_length_reg;
assign write_desc_tag = active_tag_reg;
assign write_desc_valid = state_reg == STATE_SEND_WRITE;

assign irq = irq_enable_reg && comp_fifo_m_valid;

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        active_src_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
        active_dst_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
        active_length_reg <= {LEN_WIDTH{1'b0}};
        active_tag_reg <= {TAG_WIDTH{1'b0}};
        read_status_seen_reg <= 1'b0;
        write_status_seen_reg <= 1'b0;
        captured_read_error_reg <= 4'd0;
        captured_write_error_reg <= 4'd0;
        captured_write_length_reg <= {LEN_WIDTH{1'b0}};
        read_tag_mismatch_reg <= 1'b0;
        write_tag_mismatch_reg <= 1'b0;
        length_mismatch_reg <= 1'b0;
        pending_tag_reg <= {TAG_WIDTH{1'b0}};
        pending_length_reg <= {LEN_WIDTH{1'b0}};
        pending_flags_reg <= {COMP_FLAGS_WIDTH{1'b0}};
        pending_write_error_reg <= 4'd0;
        pending_read_error_reg <= 4'd0;
        completed_count_reg <= 32'd0;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                if (req_fifo_m_valid && req_fifo_m_ready) begin
                    active_src_addr_reg <= req_head_src_addr;
                    active_dst_addr_reg <= req_head_dst_addr;
                    active_length_reg <= req_head_length;
                    active_tag_reg <= req_head_tag;
                    read_status_seen_reg <= 1'b0;
                    write_status_seen_reg <= 1'b0;
                    captured_read_error_reg <= 4'd0;
                    captured_write_error_reg <= 4'd0;
                    captured_write_length_reg <= {LEN_WIDTH{1'b0}};
                    read_tag_mismatch_reg <= 1'b0;
                    write_tag_mismatch_reg <= 1'b0;
                    length_mismatch_reg <= 1'b0;
                    state_reg <= STATE_SEND_WRITE;
                end
            end

            STATE_SEND_WRITE: begin
                if (write_desc_valid && write_desc_ready)
                    state_reg <= STATE_SEND_READ;
            end

            STATE_SEND_READ: begin
                if (read_desc_valid && read_desc_ready)
                    state_reg <= STATE_WAIT_STATUS;
            end

            STATE_WAIT_STATUS: begin
                if (all_status_seen_now) begin
                    pending_tag_reg <= active_tag_reg;
                    pending_length_reg <= final_write_length;
                    pending_flags_reg <= {
                        final_length_mismatch,
                        final_write_tag_mismatch,
                        final_read_tag_mismatch
                    };
                    pending_write_error_reg <= final_write_error;
                    pending_read_error_reg <= final_read_error;
                    state_reg <= STATE_PUSH_COMPLETION;
                end
            end

            STATE_PUSH_COMPLETION: begin
                if (comp_fifo_s_valid && comp_fifo_s_ready) begin
                    completed_count_reg <= completed_count_reg + 1'b1;
                    state_reg <= STATE_IDLE;
                end
            end

            default: state_reg <= STATE_IDLE;
        endcase

        /* Capture the two independent, non-backpressured status pulses. */
        if (status_capture_enable && read_status_valid) begin
            read_status_seen_reg <= 1'b1;
            captured_read_error_reg <= read_status_error;
            read_tag_mismatch_reg <= read_status_tag != active_tag_reg;
        end

        if (status_capture_enable && write_status_valid) begin
            write_status_seen_reg <= 1'b1;
            captured_write_error_reg <= write_status_error;
            captured_write_length_reg <= write_status_len;
            write_tag_mismatch_reg <= write_status_tag != active_tag_reg;
            length_mismatch_reg <= write_status_len != active_length_reg;
        end
    end
end

/* Staging registers, counters, and sticky diagnostics. */
always @(posedge clk) begin
    if (rst) begin
        src_addr_cfg_reg <= 32'd0;
        dst_addr_cfg_reg <= 32'd0;
        length_cfg_reg <= 32'd0;
        tag_cfg_reg <= 32'd0;
        irq_enable_reg <= 1'b0;
        reject_full_sticky_reg <= 1'b0;
        reject_invalid_sticky_reg <= 1'b0;
        status_mismatch_sticky_reg <= 1'b0;
        pop_empty_sticky_reg <= 1'b0;
        submitted_count_reg <= 32'd0;
    end else begin
        if (reg_wr_en) begin
            case (reg_wr_addr[7:0])
                REG_CONTROL: begin
                    if (reg_wr_strb[0])
                        irq_enable_reg <= reg_wr_data[0];
                end
                REG_SRC_ADDR:
                    src_addr_cfg_reg <= apply_wstrb(src_addr_cfg_reg, reg_wr_data, reg_wr_strb);
                REG_DST_ADDR:
                    dst_addr_cfg_reg <= apply_wstrb(dst_addr_cfg_reg, reg_wr_data, reg_wr_strb);
                REG_LENGTH:
                    length_cfg_reg <= apply_wstrb(length_cfg_reg, reg_wr_data, reg_wr_strb);
                REG_TAG:
                    tag_cfg_reg <= apply_wstrb(tag_cfg_reg, reg_wr_data, reg_wr_strb);
                default: begin
                end
            endcase
        end

        if (clear_sticky_event) begin
            reject_full_sticky_reg <= 1'b0;
            reject_invalid_sticky_reg <= 1'b0;
            status_mismatch_sticky_reg <= 1'b0;
            pop_empty_sticky_reg <= 1'b0;
        end

        if (submit_event) begin
            if (!staged_desc_valid)
                reject_invalid_sticky_reg <= 1'b1;
            else if (!req_fifo_s_ready)
                reject_full_sticky_reg <= 1'b1;
        end

        if (req_fifo_s_valid && req_fifo_s_ready)
            submitted_count_reg <= submitted_count_reg + 1'b1;

        if (pop_completion_event && !comp_fifo_m_valid)
            pop_empty_sticky_reg <= 1'b1;

        if (status_capture_enable && read_status_valid &&
                read_status_tag != active_tag_reg)
            status_mismatch_sticky_reg <= 1'b1;

        if (status_capture_enable && write_status_valid &&
                (write_status_tag != active_tag_reg ||
                 write_status_len != active_length_reg))
            status_mismatch_sticky_reg <= 1'b1;
    end
end

/* Register read mux.  Empty completion reads return zero, never stale RAM. */
always @* begin
    reg_rd_data = {AXIL_DATA_WIDTH{1'b0}};

    case (reg_rd_addr[7:0])
        REG_CONTROL: begin
            reg_rd_data[0] = irq_enable_reg;
        end
        REG_STATUS: begin
            reg_rd_data[0] = state_reg != STATE_IDLE;
            reg_rd_data[1] = req_fifo_empty;
            reg_rd_data[2] = req_fifo_full;
            reg_rd_data[3] = req_fifo_s_ready;
            reg_rd_data[4] = comp_fifo_m_valid;
            reg_rd_data[5] = comp_fifo_full;
            reg_rd_data[6] = irq;
            reg_rd_data[7] = reject_full_sticky_reg;
            reg_rd_data[8] = reject_invalid_sticky_reg;
            reg_rd_data[9] = status_mismatch_sticky_reg;
            reg_rd_data[10] = pop_empty_sticky_reg;
        end
        REG_SRC_ADDR: reg_rd_data = src_addr_cfg_reg;
        REG_DST_ADDR: reg_rd_data = dst_addr_cfg_reg;
        REG_LENGTH: reg_rd_data = length_cfg_reg;
        REG_TAG: reg_rd_data = tag_cfg_reg;
        REG_COMP_TAG: begin
            if (comp_fifo_m_valid)
                reg_rd_data[TAG_WIDTH-1:0] = comp_head_tag;
        end
        REG_COMP_LENGTH: begin
            if (comp_fifo_m_valid)
                reg_rd_data[LEN_WIDTH-1:0] = comp_head_length;
        end
        REG_COMP_STATUS: begin
            if (comp_fifo_m_valid) begin
                reg_rd_data[3:0] = comp_head_read_error;
                reg_rd_data[7:4] = comp_head_write_error;
                reg_rd_data[10:8] = comp_head_flags;
            end
        end
        REG_QUEUE_LEVELS: begin
            reg_rd_data[REQ_LEVEL_WIDTH-1:0] = req_fifo_level;
            reg_rd_data[16 +: COMP_LEVEL_WIDTH] = comp_fifo_level;
        end
        REG_SUBMITTED_COUNT: reg_rd_data = submitted_count_reg;
        REG_COMPLETED_COUNT: reg_rd_data = completed_count_reg;
        default: reg_rd_data = {AXIL_DATA_WIDTH{1'b0}};
    endcase
end

initial begin
    if (AXIL_DATA_WIDTH != 32 || AXIL_STRB_WIDTH != 4) begin
        $error("dma_desc_manager requires a 32-bit AXI-Lite data bus (instance %m)");
        $finish;
    end

    if (AXIL_ADDR_WIDTH < 8) begin
        $error("dma_desc_manager AXIL_ADDR_WIDTH must be at least 8 (instance %m)");
        $finish;
    end

    if (AXI_ADDR_WIDTH < 1 || AXI_ADDR_WIDTH > 32 ||
            LEN_WIDTH < 1 || LEN_WIDTH > 32 ||
            TAG_WIDTH < 1 || TAG_WIDTH > 32) begin
        $error("dma_desc_manager address, length, and tag widths must be 1..32 (instance %m)");
        $finish;
    end

    if (AXI_STRB_WIDTH < 1 || (AXI_STRB_WIDTH & (AXI_STRB_WIDTH-1)) != 0) begin
        $error("dma_desc_manager AXI_STRB_WIDTH must be a power of two (instance %m)");
        $finish;
    end

    if (DESC_FIFO_DEPTH < 2 || DESC_FIFO_DEPTH > 65535 ||
            COMP_FIFO_DEPTH < 2 || COMP_FIFO_DEPTH > 65535) begin
        $error("dma_desc_manager FIFO depths must be in the range 2..65535 (instance %m)");
        $finish;
    end
end

endmodule

`resetall
