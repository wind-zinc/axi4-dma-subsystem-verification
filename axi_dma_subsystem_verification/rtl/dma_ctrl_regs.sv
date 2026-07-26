`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module dma_ctrl_regs #(
    parameter int unsigned CHANNEL_INDEX = 0
) (
    input  logic clk,
    input  logic rst,

    input  logic [AXIL_BLOCK_ADDR_WIDTH-1:0] s_axil_awaddr,
    input  logic [2:0]                       s_axil_awprot,
    input  logic                             s_axil_awvalid,
    output logic                             s_axil_awready,
    input  logic [AXIL_DATA_WIDTH-1:0]       s_axil_wdata,
    input  logic [AXIL_STRB_WIDTH-1:0]       s_axil_wstrb,
    input  logic                             s_axil_wvalid,
    output logic                             s_axil_wready,
    output logic [1:0]                       s_axil_bresp,
    output logic                             s_axil_bvalid,
    input  logic                             s_axil_bready,
    input  logic [AXIL_BLOCK_ADDR_WIDTH-1:0] s_axil_araddr,
    input  logic [2:0]                       s_axil_arprot,
    input  logic                             s_axil_arvalid,
    output logic                             s_axil_arready,
    output logic [AXIL_DATA_WIDTH-1:0]       s_axil_rdata,
    output logic [1:0]                       s_axil_rresp,
    output logic                             s_axil_rvalid,
    input  logic                             s_axil_rready,

    output logic                             cmd_valid,
    output dma_cmd_t                         cmd_payload,
    input  logic                             cmd_ready,
    output logic                             abort_req,
    input  logic                             busy_i,
    input  logic                             completion_valid_i,
    input dma_completion_t                   completion_i
);

    logic aw_hold_valid;
    logic [AXIL_BLOCK_ADDR_WIDTH-1:0] aw_hold_addr;
    logic w_hold_valid;
    logic [AXIL_DATA_WIDTH-1:0] w_hold_data;
    logic [AXIL_STRB_WIDTH-1:0] w_hold_strb;

    logic [31:0] src_addr_reg;
    logic [31:0] dst_addr_reg;
    logic [LEN_WIDTH-1:0] length_reg;
    logic dst_ch_reg;
    logic [7:0] sw_tag_reg;
    logic enable_reg;

    logic done_pending_reg;
    logic error_pending_reg;
    logic abort_seen_reg;
    dma_error_e last_error_reg;
    logic [TAG_WIDTH-1:0] last_hw_tag_reg;
    logic [LEN_WIDTH-1:0] completed_len_reg;
    logic [31:0] cmd_count_reg;
    logic [31:0] done_count_reg;

    logic [31:0] read_data_next;
    logic [1:0] read_resp_next;
    logic write_commit;
    logic write_valid;
    logic [31:0] merged_ctrl_word;
    logic [31:0] merged_src_word;
    logic [31:0] merged_dst_word;
    logic [31:0] merged_length_word;
    logic [31:0] merged_route_word;
    logic [31:0] merged_tag_word;
    logic pending_cmd_accept;
    logic start_write;
    logic abort_write;
    logic clear_status_write;

    function automatic logic [31:0] merge_wstrb(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [AXIL_STRB_WIDTH-1:0] strb
    );
        integer byte_index;
        begin
            merge_wstrb = old_value;
            for (byte_index = 0; byte_index < AXIL_STRB_WIDTH; byte_index = byte_index + 1) begin
                if (strb[byte_index]) begin
                    merge_wstrb[byte_index*8 +: 8] = new_value[byte_index*8 +: 8];
                end
            end
        end
    endfunction

    always_comb begin
        read_data_next = 32'd0;
        read_resp_next = 2'b00;
        case (s_axil_araddr)
            REG_CTRL: begin
                read_data_next[2] = enable_reg;
            end
            REG_STATUS: begin
                read_data_next[0] = busy_i;
                read_data_next[1] = done_pending_reg;
                read_data_next[2] = error_pending_reg;
                read_data_next[3] = cmd_valid;
                read_data_next[4] = abort_seen_reg;
                read_data_next[15:8] = last_error_reg;
            end
            REG_SRC_ADDR: read_data_next = src_addr_reg;
            REG_DST_ADDR: read_data_next = dst_addr_reg;
            REG_LENGTH: read_data_next[LEN_WIDTH-1:0] = length_reg;
            REG_ROUTE: read_data_next[0] = dst_ch_reg;
            REG_SW_TAG: read_data_next[7:0] = sw_tag_reg;
            REG_LAST_HW_TAG: read_data_next[TAG_WIDTH-1:0] = last_hw_tag_reg;
            REG_COMPLETED_LEN: read_data_next[LEN_WIDTH-1:0] = completed_len_reg;
            REG_LAST_ERROR: read_data_next[7:0] = last_error_reg;
            REG_CMD_COUNT: read_data_next = cmd_count_reg;
            REG_DONE_COUNT: read_data_next = done_count_reg;
            REG_VERSION: read_data_next = VERSION_VALUE;
            default: begin
                read_data_next = 32'd0;
                read_resp_next = 2'b10;
            end
        endcase
    end

    always_comb begin
        merged_ctrl_word = 32'd0;
        merged_ctrl_word[2] = enable_reg;
        merged_ctrl_word = merge_wstrb(merged_ctrl_word, w_hold_data, w_hold_strb);
        merged_src_word = merge_wstrb(src_addr_reg, w_hold_data, w_hold_strb);
        merged_dst_word = merge_wstrb(dst_addr_reg, w_hold_data, w_hold_strb);
        merged_length_word = merge_wstrb({{(32-LEN_WIDTH){1'b0}}, length_reg}, w_hold_data, w_hold_strb);
        merged_route_word = merge_wstrb({31'd0, dst_ch_reg}, w_hold_data, w_hold_strb);
        merged_tag_word = merge_wstrb({24'd0, sw_tag_reg}, w_hold_data, w_hold_strb);

        write_valid = 1'b0;
        if (aw_hold_valid && w_hold_valid) begin
            case (aw_hold_addr)
                REG_CTRL,
                REG_SRC_ADDR,
                REG_DST_ADDR,
                REG_LENGTH,
                REG_ROUTE,
                REG_SW_TAG: write_valid = 1'b1;
                default: write_valid = 1'b0;
            endcase
        end
    end

    assign s_axil_awready = !aw_hold_valid && !s_axil_bvalid;
    assign s_axil_wready = !w_hold_valid && !s_axil_bvalid;
    assign s_axil_arready = !s_axil_rvalid;
    assign write_commit = aw_hold_valid && w_hold_valid && !s_axil_bvalid;
    assign pending_cmd_accept = cmd_valid && cmd_ready;
    assign start_write = write_commit && write_valid
        && (aw_hold_addr == REG_CTRL) && w_hold_strb[0] && w_hold_data[0];
    assign abort_write = write_commit && write_valid
        && (aw_hold_addr == REG_CTRL) && w_hold_strb[0] && w_hold_data[1];
    assign clear_status_write = write_commit && write_valid
        && (aw_hold_addr == REG_CTRL) && w_hold_strb[0] && w_hold_data[4];

    always_ff @(posedge clk) begin
        if (rst) begin
            aw_hold_valid <= 1'b0;
            aw_hold_addr <= '0;
            w_hold_valid <= 1'b0;
            w_hold_data <= '0;
            w_hold_strb <= '0;
            s_axil_bvalid <= 1'b0;
            s_axil_bresp <= 2'b00;
            s_axil_rvalid <= 1'b0;
            s_axil_rdata <= '0;
            s_axil_rresp <= 2'b00;
            src_addr_reg <= '0;
            dst_addr_reg <= '0;
            length_reg <= '0;
            dst_ch_reg <= 1'b0;
            sw_tag_reg <= '0;
            enable_reg <= 1'b0;
            done_pending_reg <= 1'b0;
            error_pending_reg <= 1'b0;
            abort_seen_reg <= 1'b0;
            last_error_reg <= DMA_ERR_NONE;
            last_hw_tag_reg <= '0;
            completed_len_reg <= '0;
            cmd_count_reg <= '0;
            done_count_reg <= '0;
            cmd_valid <= 1'b0;
            cmd_payload <= '0;
            abort_req <= 1'b0;
        end else begin
            abort_req <= 1'b0;

            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end

            if (s_axil_awvalid && s_axil_awready) begin
                aw_hold_valid <= 1'b1;
                aw_hold_addr <= s_axil_awaddr;
            end

            if (s_axil_wvalid && s_axil_wready) begin
                w_hold_valid <= 1'b1;
                w_hold_data <= s_axil_wdata;
                w_hold_strb <= s_axil_wstrb;
            end

            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_rvalid <= 1'b1;
                s_axil_rdata <= read_data_next;
                s_axil_rresp <= read_resp_next;
            end

            if (cmd_valid && cmd_ready) begin
                cmd_valid <= 1'b0;
                cmd_count_reg <= saturating_inc32(cmd_count_reg);
            end

            if (clear_status_write) begin
                done_pending_reg <= 1'b0;
                error_pending_reg <= 1'b0;
                abort_seen_reg <= 1'b0;
                last_error_reg <= DMA_ERR_NONE;
            end

            if (completion_valid_i) begin
                done_pending_reg <= 1'b1;
                if (completion_i.error != DMA_ERR_NONE) begin
                    error_pending_reg <= 1'b1;
                end
                abort_seen_reg <= completion_i.aborted;
                last_error_reg <= completion_i.error;
                last_hw_tag_reg <= completion_i.hw_tag;
                completed_len_reg <= completion_i.completed_len;
                done_count_reg <= saturating_inc32(done_count_reg);
            end

            if (write_commit) begin
                s_axil_bvalid <= 1'b1;
                s_axil_bresp <= write_valid ? 2'b00 : 2'b10;
                aw_hold_valid <= 1'b0;
                w_hold_valid <= 1'b0;

                if (write_valid) begin
                    case (aw_hold_addr)
                        REG_CTRL: begin
                            enable_reg <= merged_ctrl_word[2];

                            if (start_write) begin
                                if (!merged_ctrl_word[2]) begin
                                    error_pending_reg <= 1'b1;
                                    last_error_reg <= DMA_ERR_DISABLED;
                                end else if (busy_i || cmd_valid || pending_cmd_accept) begin
                                    error_pending_reg <= 1'b1;
                                    last_error_reg <= DMA_ERR_BUSY;
                                end else begin
                                    cmd_payload.src_addr <= src_addr_reg;
                                    cmd_payload.dst_addr <= dst_addr_reg;
                                    cmd_payload.len <= length_reg;
                                    cmd_payload.src_ch <= (CHANNEL_INDEX == 1);
                                    cmd_payload.dst_ch <= dst_ch_reg;
                                    cmd_payload.sw_tag <= sw_tag_reg;
                                    cmd_valid <= 1'b1;
                                end
                            end

                            if (abort_write) begin
                                if (cmd_valid && !pending_cmd_accept && !busy_i) begin
                                    cmd_valid <= 1'b0;
                                    abort_seen_reg <= 1'b1;
                                    error_pending_reg <= 1'b1;
                                    last_error_reg <= DMA_ERR_ABORT_PENDING;
                                end else if (busy_i || pending_cmd_accept) begin
                                    abort_req <= 1'b1;
                                    abort_seen_reg <= 1'b1;
                                end
                            end
                        end
                        REG_SRC_ADDR: src_addr_reg <= merged_src_word;
                        REG_DST_ADDR: dst_addr_reg <= merged_dst_word;
                        REG_LENGTH: length_reg <= merged_length_word[LEN_WIDTH-1:0];
                        REG_ROUTE: dst_ch_reg <= merged_route_word[0];
                        REG_SW_TAG: sw_tag_reg <= merged_tag_word[7:0];
                        default: begin end
                    endcase
                end
            end
        end
    end

    logic unused_prot;
    always_comb begin
        unused_prot = ^{s_axil_awprot, s_axil_arprot};
    end

endmodule

`default_nettype wire
