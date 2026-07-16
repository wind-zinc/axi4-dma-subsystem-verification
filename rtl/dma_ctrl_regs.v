/*
 * AXI-Lite register block and single-transfer controller for axi_dma
 *
 * Register map (byte addresses):
 *   0x00 CONTROL
 *        bit 0: START        (write one to pulse, ignored while BUSY)
 *        bit 1: CLEAR_STATUS (write one to clear DONE/ERROR)
 *        bit 2: IRQ_ENABLE   (read/write)
 *   0x04 STATUS
 *        bit 0: BUSY
 *        bit 1: DONE         (sticky)
 *        bit 2: ERROR        (sticky)
 *        bit 3: IRQ
 *        bit 4: CONFIG_ERROR (length was zero when START was written)
 *        bit 5: TAG_ERROR    (returned status tag did not match active TAG)
 *   0x08 SRC_ADDR
 *   0x0c DST_ADDR
 *   0x10 LENGTH       (bytes)
 *   0x14 TAG
 *   0x18 READ_ERROR   (DMA read status error code)
 *   0x1c WRITE_ERROR  (DMA write status error code)
 *
 * This first version accepts one transfer at a time.  It sends the write
 * descriptor first, then the read descriptor, and waits for both statuses.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module dma_ctrl_regs #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 8,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter AXI_ADDR_WIDTH = 16,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8
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

    /* Read descriptor output */
    output reg  [AXI_ADDR_WIDTH-1:0]    read_desc_addr,
    output reg  [LEN_WIDTH-1:0]         read_desc_len,
    output reg  [TAG_WIDTH-1:0]         read_desc_tag,
    output reg                          read_desc_valid,
    input  wire                         read_desc_ready,

    /* Write descriptor output */
    output reg  [AXI_ADDR_WIDTH-1:0]    write_desc_addr,
    output reg  [LEN_WIDTH-1:0]         write_desc_len,
    output reg  [TAG_WIDTH-1:0]         write_desc_tag,
    output reg                          write_desc_valid,
    input  wire                         write_desc_ready,

    /* Read descriptor status input */
    input  wire [TAG_WIDTH-1:0]         read_status_tag,
    input  wire [3:0]                   read_status_error,
    input  wire                         read_status_valid,

    /* Write descriptor status input */
    input  wire [TAG_WIDTH-1:0]         write_status_tag,
    input  wire [3:0]                   write_status_error,
    input  wire                         write_status_valid,

    output wire                         irq
);

localparam [7:0] REG_CONTROL     = 8'h00;
localparam [7:0] REG_STATUS      = 8'h04;
localparam [7:0] REG_SRC_ADDR    = 8'h08;
localparam [7:0] REG_DST_ADDR    = 8'h0c;
localparam [7:0] REG_LENGTH      = 8'h10;
localparam [7:0] REG_TAG         = 8'h14;
localparam [7:0] REG_READ_ERROR  = 8'h18;
localparam [7:0] REG_WRITE_ERROR = 8'h1c;

localparam [1:0] STATE_IDLE        = 2'd0;
localparam [1:0] STATE_SEND_WRITE  = 2'd1;
localparam [1:0] STATE_SEND_READ   = 2'd2;
localparam [1:0] STATE_WAIT_STATUS = 2'd3;

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

reg [31:0] src_addr_cfg_reg = 32'd0;
reg [31:0] dst_addr_cfg_reg = 32'd0;
reg [31:0] length_cfg_reg = 32'd0;
reg [31:0] tag_cfg_reg = 32'd0;

reg [TAG_WIDTH-1:0] active_tag_reg = {TAG_WIDTH{1'b0}};
reg [1:0] state_reg = STATE_IDLE;
reg busy_reg = 1'b0;
reg done_reg = 1'b0;
reg error_reg = 1'b0;
reg config_error_reg = 1'b0;
reg tag_error_reg = 1'b0;
reg irq_enable_reg = 1'b0;
reg read_status_seen_reg = 1'b0;
reg write_status_seen_reg = 1'b0;
reg [3:0] read_error_reg = 4'd0;
reg [3:0] write_error_reg = 4'd0;

wire read_complete_now;
wire write_complete_now;
wire [3:0] effective_read_error;
wire [3:0] effective_write_error;
wire read_tag_mismatch;
wire write_tag_mismatch;

assign reg_wr_wait = 1'b0;
assign reg_wr_ack  = reg_wr_en;
assign reg_rd_wait = 1'b0;
assign reg_rd_ack  = reg_rd_en;

assign irq = irq_enable_reg && done_reg;

assign read_complete_now  = read_status_seen_reg  || read_status_valid;
assign write_complete_now = write_status_seen_reg || write_status_valid;
assign effective_read_error  = read_status_valid  ? read_status_error  : read_error_reg;
assign effective_write_error = write_status_valid ? write_status_error : write_error_reg;
assign read_tag_mismatch  = read_status_valid  && (read_status_tag  != active_tag_reg);
assign write_tag_mismatch = write_status_valid && (write_status_tag != active_tag_reg);

function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  write_strobe;
    integer i;
    begin
        apply_wstrb = old_value;
        for (i = 0; i < 4; i = i + 1) begin
            if (write_strobe[i])
                apply_wstrb[i*8 +: 8] = new_value[i*8 +: 8];
        end
    end
endfunction

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

always @* begin
    reg_rd_data = {AXIL_DATA_WIDTH{1'b0}};

    case (reg_rd_addr[7:0])
        REG_CONTROL: begin
            reg_rd_data[2] = irq_enable_reg;
        end
        REG_STATUS: begin
            reg_rd_data[0] = busy_reg;
            reg_rd_data[1] = done_reg;
            reg_rd_data[2] = error_reg;
            reg_rd_data[3] = irq;
            reg_rd_data[4] = config_error_reg;
            reg_rd_data[5] = tag_error_reg;
        end
        REG_SRC_ADDR: begin
            reg_rd_data = src_addr_cfg_reg;
        end
        REG_DST_ADDR: begin
            reg_rd_data = dst_addr_cfg_reg;
        end
        REG_LENGTH: begin
            reg_rd_data = length_cfg_reg;
        end
        REG_TAG: begin
            reg_rd_data = tag_cfg_reg;
        end
        REG_READ_ERROR: begin
            reg_rd_data[3:0] = read_error_reg;
        end
        REG_WRITE_ERROR: begin
            reg_rd_data[3:0] = write_error_reg;
        end
        default: begin
            reg_rd_data = {AXIL_DATA_WIDTH{1'b0}};
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        src_addr_cfg_reg <= 32'd0;
        dst_addr_cfg_reg <= 32'd0;
        length_cfg_reg <= 32'd0;
        tag_cfg_reg <= 32'd0;

        active_tag_reg <= {TAG_WIDTH{1'b0}};
        state_reg <= STATE_IDLE;
        busy_reg <= 1'b0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
        config_error_reg <= 1'b0;
        tag_error_reg <= 1'b0;
        irq_enable_reg <= 1'b0;
        read_status_seen_reg <= 1'b0;
        write_status_seen_reg <= 1'b0;
        read_error_reg <= 4'd0;
        write_error_reg <= 4'd0;

        read_desc_addr <= {AXI_ADDR_WIDTH{1'b0}};
        read_desc_len <= {LEN_WIDTH{1'b0}};
        read_desc_tag <= {TAG_WIDTH{1'b0}};
        read_desc_valid <= 1'b0;

        write_desc_addr <= {AXI_ADDR_WIDTH{1'b0}};
        write_desc_len <= {LEN_WIDTH{1'b0}};
        write_desc_tag <= {TAG_WIDTH{1'b0}};
        write_desc_valid <= 1'b0;
    end else begin
        /* AXI-Lite register writes */
        if (reg_wr_en) begin
            case (reg_wr_addr[7:0])
                REG_CONTROL: begin
                    if (reg_wr_strb[0]) begin
                        irq_enable_reg <= reg_wr_data[2];

                        if (reg_wr_data[1]) begin
                            done_reg <= 1'b0;
                            error_reg <= 1'b0;
                            config_error_reg <= 1'b0;
                            tag_error_reg <= 1'b0;
                            read_error_reg <= 4'd0;
                            write_error_reg <= 4'd0;
                        end

                        if (reg_wr_data[0] && !busy_reg) begin
                            done_reg <= 1'b0;
                            error_reg <= 1'b0;
                            config_error_reg <= 1'b0;
                            tag_error_reg <= 1'b0;
                            read_error_reg <= 4'd0;
                            write_error_reg <= 4'd0;
                            read_status_seen_reg <= 1'b0;
                            write_status_seen_reg <= 1'b0;

                            if (length_cfg_reg == 0) begin
                                busy_reg <= 1'b0;
                                done_reg <= 1'b1;
                                error_reg <= 1'b1;
                                config_error_reg <= 1'b1;
                                state_reg <= STATE_IDLE;
                            end else begin
                                active_tag_reg <= tag_cfg_reg[TAG_WIDTH-1:0];

                                write_desc_addr <= dst_addr_cfg_reg[AXI_ADDR_WIDTH-1:0];
                                write_desc_len <= length_cfg_reg[LEN_WIDTH-1:0];
                                write_desc_tag <= tag_cfg_reg[TAG_WIDTH-1:0];
                                write_desc_valid <= 1'b1;

                                read_desc_addr <= src_addr_cfg_reg[AXI_ADDR_WIDTH-1:0];
                                read_desc_len <= length_cfg_reg[LEN_WIDTH-1:0];
                                read_desc_tag <= tag_cfg_reg[TAG_WIDTH-1:0];
                                read_desc_valid <= 1'b0;

                                busy_reg <= 1'b1;
                                state_reg <= STATE_SEND_WRITE;
                            end
                        end
                    end
                end
                REG_SRC_ADDR: begin
                    src_addr_cfg_reg <= apply_wstrb(
                        src_addr_cfg_reg,
                        reg_wr_data[31:0],
                        reg_wr_strb[3:0]
                    );
                end
                REG_DST_ADDR: begin
                    dst_addr_cfg_reg <= apply_wstrb(
                        dst_addr_cfg_reg,
                        reg_wr_data[31:0],
                        reg_wr_strb[3:0]
                    );
                end
                REG_LENGTH: begin
                    length_cfg_reg <= apply_wstrb(
                        length_cfg_reg,
                        reg_wr_data[31:0],
                        reg_wr_strb[3:0]
                    );
                end
                REG_TAG: begin
                    tag_cfg_reg <= apply_wstrb(
                        tag_cfg_reg,
                        reg_wr_data[31:0],
                        reg_wr_strb[3:0]
                    );
                end
                default: begin
                end
            endcase
        end

        /* Descriptor handshakes */
        case (state_reg)
            STATE_SEND_WRITE: begin
                if (write_desc_valid && write_desc_ready) begin
                    write_desc_valid <= 1'b0;
                    read_desc_valid <= 1'b1;
                    state_reg <= STATE_SEND_READ;
                end
            end
            STATE_SEND_READ: begin
                if (read_desc_valid && read_desc_ready) begin
                    read_desc_valid <= 1'b0;
                    state_reg <= STATE_WAIT_STATUS;
                end
            end
            default: begin
            end
        endcase

        /* Collect completion status from both halves of the DMA */
        if (busy_reg && read_status_valid) begin
            read_status_seen_reg <= 1'b1;
            read_error_reg <= read_status_error;
            if (read_status_tag != active_tag_reg)
                tag_error_reg <= 1'b1;
        end

        if (busy_reg && write_status_valid) begin
            write_status_seen_reg <= 1'b1;
            write_error_reg <= write_status_error;
            if (write_status_tag != active_tag_reg)
                tag_error_reg <= 1'b1;
        end

        if (state_reg == STATE_WAIT_STATUS &&
                read_complete_now && write_complete_now) begin
            busy_reg <= 1'b0;
            done_reg <= 1'b1;
            error_reg <= (effective_read_error != 0) ||
                         (effective_write_error != 0) ||
                         tag_error_reg ||
                         read_tag_mismatch || write_tag_mismatch;
            read_status_seen_reg <= 1'b0;
            write_status_seen_reg <= 1'b0;
            state_reg <= STATE_IDLE;
        end
    end
end

initial begin
    if (AXIL_DATA_WIDTH != 32) begin
        $error("dma_ctrl_regs currently requires AXIL_DATA_WIDTH = 32");
        $finish;
    end
    if (AXIL_ADDR_WIDTH < 8) begin
        $error("dma_ctrl_regs requires AXIL_ADDR_WIDTH >= 8");
        $finish;
    end
    if (AXI_ADDR_WIDTH > 32 || LEN_WIDTH > 32 || TAG_WIDTH > 32) begin
        $error("dma_ctrl_regs first version supports widths up to 32 bits");
        $finish;
    end
end

endmodule

`resetall
