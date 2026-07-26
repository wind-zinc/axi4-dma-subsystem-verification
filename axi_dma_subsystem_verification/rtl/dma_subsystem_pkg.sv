`default_nettype none
`timescale 1ns / 1ps

package dma_subsystem_pkg;

    localparam int unsigned DMA_CH_COUNT = 2;
    localparam int unsigned EXT_AXI_MASTER_COUNT = 2;
    localparam int unsigned AXI_MASTER_COUNT = 4;
    localparam int unsigned AXI_SLAVE_COUNT = 2;

    localparam int unsigned AXI_DATA_WIDTH = 32;
    localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int unsigned AXI_ADDR_WIDTH = 32;
    localparam int unsigned AXI_ID_WIDTH = 4;
    localparam int unsigned AXI_XBAR_M_ID_WIDTH = AXI_ID_WIDTH + $clog2(AXI_MASTER_COUNT);
    localparam int unsigned AXI_RAM_ADDR_WIDTH = 16;
    localparam int unsigned AXI_MAX_BURST_LEN = 16;

    localparam int unsigned AXIL_ADDR_WIDTH = 32;
    localparam int unsigned AXIL_BLOCK_ADDR_WIDTH = 12;
    localparam int unsigned AXIL_DATA_WIDTH = 32;
    localparam int unsigned AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;

    localparam int unsigned AXIS_DATA_WIDTH = 32;
    localparam int unsigned AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8;
    localparam int unsigned AXIS_ID_WIDTH = 2;
    localparam int unsigned AXIS_DEST_WIDTH = 1;
    localparam int unsigned AXIS_USER_WIDTH = 1;
    localparam int unsigned LEN_WIDTH = 20;
    localparam int unsigned TAG_WIDTH = 8;

    localparam int unsigned AXIS_FIFO_DEPTH_BEATS = 32;
    localparam int unsigned AXIS_FIFO_VENDOR_DEPTH = AXIS_FIFO_DEPTH_BEATS * AXIS_KEEP_WIDTH;

    localparam bit ENABLE_SG = 1'b0;
    localparam bit ENABLE_UNALIGNED = 1'b0;

    localparam logic [31:0] RAM0_BASE_ADDR = 32'h0000_0000;
    localparam logic [31:0] RAM0_END_ADDR  = 32'h0000_FFFF;
    localparam logic [31:0] RAM1_BASE_ADDR = 32'h1000_0000;
    localparam logic [31:0] RAM1_END_ADDR  = 32'h1000_FFFF;

    localparam logic [31:0] CH0_CTRL_BASE_ADDR = 32'h0000_0000;
    localparam logic [31:0] CH1_CTRL_BASE_ADDR = 32'h0000_1000;
    localparam logic [31:0] GLOBAL_IRQ_BASE_ADDR = 32'h0000_2000;

    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CTRL = 12'h000;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_STATUS = 12'h004;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_SRC_ADDR = 12'h008;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_DST_ADDR = 12'h00C;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_LENGTH = 12'h010;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_ROUTE = 12'h014;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_SW_TAG = 12'h018;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_LAST_HW_TAG = 12'h01C;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_COMPLETED_LEN = 12'h020;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_LAST_ERROR = 12'h024;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CMD_COUNT = 12'h028;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_DONE_COUNT = 12'h02C;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_VERSION = 12'h030;

    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_IRQ_STATUS = 12'h000;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_IRQ_ENABLE = 12'h004;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_IRQ_CLEAR = 12'h008;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_IRQ_LAST_ERROR = 12'h00C;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CH0_DONE_COUNT = 12'h010;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CH1_DONE_COUNT = 12'h014;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CH0_ERROR_COUNT = 12'h018;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_CH1_ERROR_COUNT = 12'h01C;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_ROUTE_STATUS = 12'h020;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_GLOBAL_VERSION = 12'h024;
    localparam logic [AXIL_BLOCK_ADDR_WIDTH-1:0] REG_FAULT_STATUS = 12'h028;

    localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

    typedef enum logic [7:0] {
        DMA_ERR_NONE = 8'h00,
        DMA_ERR_DISABLED = 8'h01,
        DMA_ERR_LEN_ZERO = 8'h02,
        DMA_ERR_SRC_ALIGN = 8'h03,
        DMA_ERR_DST_ALIGN = 8'h04,
        DMA_ERR_SRC_RANGE = 8'h05,
        DMA_ERR_DST_RANGE = 8'h06,
        DMA_ERR_OVERLAP = 8'h07,
        DMA_ERR_BUSY = 8'h08,
        DMA_ERR_AXI_RD_SLVERR = 8'h10,
        DMA_ERR_AXI_RD_DECERR = 8'h11,
        DMA_ERR_AXI_WR_SLVERR = 8'h12,
        DMA_ERR_AXI_WR_DECERR = 8'h13,
        DMA_ERR_ROUTE_CONFLICT = 8'h20,
        DMA_ERR_TAG_MISMATCH = 8'h21,
        DMA_ERR_UNEXPECTED_STATUS = 8'h22,
        DMA_ERR_LEN_MISMATCH = 8'h23,
        DMA_ERR_ABORT_PENDING = 8'h30,
        DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED = 8'h31,
        DMA_ERR_INTERNAL = 8'hFF
    } dma_error_e;

    typedef enum logic [2:0] {
        DMA_FAULT_SRC_RD0 = 3'd0,
        DMA_FAULT_SRC_RD1 = 3'd1,
        DMA_FAULT_SRC_WR0 = 3'd2,
        DMA_FAULT_SRC_WR1 = 3'd3,
        DMA_FAULT_SRC_ROUTE = 3'd4,
        DMA_FAULT_SRC_MANAGER = 3'd5
    } dma_fault_source_e;

    typedef struct packed {
        logic [AXI_ADDR_WIDTH-1:0] src_addr;
        logic [AXI_ADDR_WIDTH-1:0] dst_addr;
        logic [LEN_WIDTH-1:0]      len;
        logic                      src_ch;
        logic                      dst_ch;
        logic [7:0]                sw_tag;
    } dma_cmd_t;

    typedef struct packed {
        logic                     owner_ch;
        logic [TAG_WIDTH-1:0]     hw_tag;
        logic [7:0]               sw_tag;
        logic [LEN_WIDTH-1:0]     completed_len;
        dma_error_e               error;
        logic                     aborted;
    } dma_completion_t;

    typedef struct packed {
        dma_error_e               error;
        logic [2:0]               source;
    } dma_fault_t;

    function automatic logic [31:0] saturating_inc32(input logic [31:0] value);
        begin
            if (value == 32'hFFFF_FFFF) begin
                saturating_inc32 = value;
            end else begin
                saturating_inc32 = value + 32'd1;
            end
        end
    endfunction

    function automatic logic [31:0] saturating_add_one32(input logic [31:0] value);
        saturating_add_one32 = saturating_inc32(value);
    endfunction

    function automatic logic range_overflow32(
        input logic [31:0] addr,
        input logic [LEN_WIDTH-1:0] len
    );
        logic [32:0] end_ext;
        begin
            end_ext = {1'b0, addr} + {{(33-LEN_WIDTH){1'b0}}, len} - 33'd1;
            range_overflow32 = (len == '0) ? 1'b0 : end_ext[32];
        end
    endfunction

    function automatic logic addr_in_ram0(input logic [31:0] addr);
        addr_in_ram0 = (addr >= RAM0_BASE_ADDR) && (addr <= RAM0_END_ADDR);
    endfunction

    function automatic logic addr_in_ram1(input logic [31:0] addr);
        addr_in_ram1 = (addr >= RAM1_BASE_ADDR) && (addr <= RAM1_END_ADDR);
    endfunction

    function automatic logic range_in_ram0(
        input logic [31:0] addr,
        input logic [LEN_WIDTH-1:0] len
    );
        logic [32:0] end_ext;
        begin
            end_ext = {1'b0, addr} + {{(33-LEN_WIDTH){1'b0}}, len} - 33'd1;
            range_in_ram0 = (len != '0) && !end_ext[32]
                && ({1'b0, addr} >= {1'b0, RAM0_BASE_ADDR})
                && (end_ext <= {1'b0, RAM0_END_ADDR});
        end
    endfunction

    function automatic logic range_in_ram1(
        input logic [31:0] addr,
        input logic [LEN_WIDTH-1:0] len
    );
        logic [32:0] end_ext;
        begin
            end_ext = {1'b0, addr} + {{(33-LEN_WIDTH){1'b0}}, len} - 33'd1;
            range_in_ram1 = (len != '0) && !end_ext[32]
                && ({1'b0, addr} >= {1'b0, RAM1_BASE_ADDR})
                && (end_ext <= {1'b0, RAM1_END_ADDR});
        end
    endfunction

    function automatic logic range_in_single_ram(
        input logic [31:0] addr,
        input logic [LEN_WIDTH-1:0] len
    );
        range_in_single_ram = range_in_ram0(addr, len) || range_in_ram1(addr, len);
    endfunction

    function automatic logic ranges_overlap(
        input logic [31:0] src_addr,
        input logic [31:0] dst_addr,
        input logic [LEN_WIDTH-1:0] len
    );
        logic [32:0] src_end;
        logic [32:0] dst_end;
        begin
            src_end = {1'b0, src_addr} + {{(33-LEN_WIDTH){1'b0}}, len} - 33'd1;
            dst_end = {1'b0, dst_addr} + {{(33-LEN_WIDTH){1'b0}}, len} - 33'd1;
            ranges_overlap = (len != '0) && !src_end[32] && !dst_end[32]
                && ({1'b0, src_addr} <= dst_end)
                && ({1'b0, dst_addr} <= src_end);
        end
    endfunction

    function automatic logic address_aligned(input logic [31:0] addr);
        address_aligned = (addr[1:0] == 2'b00);
    endfunction

    function automatic dma_error_e vendor_error_to_dma(
        input logic [3:0] vendor_error,
        input logic       write_side
    );
        begin
            if (vendor_error == 4'd0) begin
                vendor_error_to_dma = DMA_ERR_NONE;
            end else if (!write_side && vendor_error == 4'd4) begin
                vendor_error_to_dma = DMA_ERR_AXI_RD_SLVERR;
            end else if (!write_side && vendor_error == 4'd5) begin
                vendor_error_to_dma = DMA_ERR_AXI_RD_DECERR;
            end else if (write_side && vendor_error == 4'd6) begin
                vendor_error_to_dma = DMA_ERR_AXI_WR_SLVERR;
            end else if (write_side && vendor_error == 4'd7) begin
                vendor_error_to_dma = DMA_ERR_AXI_WR_DECERR;
            end else begin
                vendor_error_to_dma = DMA_ERR_INTERNAL;
            end
        end
    endfunction

    function automatic int unsigned dma_error_rank(input dma_error_e error_code);
        begin
            case (error_code)
                DMA_ERR_INTERNAL: dma_error_rank = 100;
                DMA_ERR_TAG_MISMATCH: dma_error_rank = 90;
                DMA_ERR_LEN_MISMATCH: dma_error_rank = 80;
                DMA_ERR_AXI_WR_SLVERR,
                DMA_ERR_AXI_WR_DECERR: dma_error_rank = 70;
                DMA_ERR_AXI_RD_SLVERR,
                DMA_ERR_AXI_RD_DECERR: dma_error_rank = 60;
                DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED: dma_error_rank = 50;
                DMA_ERR_ABORT_PENDING: dma_error_rank = 40;
                DMA_ERR_NONE: dma_error_rank = 0;
                default: dma_error_rank = 30;
            endcase
        end
    endfunction

    function automatic dma_error_e merge_dma_error(
        input dma_error_e current_error,
        input dma_error_e new_error
    );
        begin
            if (dma_error_rank(new_error) > dma_error_rank(current_error)) begin
                merge_dma_error = new_error;
            end else begin
                merge_dma_error = current_error;
            end
        end
    endfunction

endpackage

`default_nettype wire
