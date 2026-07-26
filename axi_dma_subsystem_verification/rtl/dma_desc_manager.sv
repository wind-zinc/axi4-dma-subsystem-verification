`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module dma_desc_manager #(
    parameter bit ENABLE_UNALIGNED_PARAM = ENABLE_UNALIGNED
) (
    input logic clk,
    input logic rst,

    input logic [DMA_CH_COUNT-1:0] cmd_valid,
    input dma_cmd_t cmd_payload [DMA_CH_COUNT-1:0],
    output logic [DMA_CH_COUNT-1:0] cmd_ready,
    output logic [DMA_CH_COUNT-1:0] busy,

    output logic [DMA_CH_COUNT-1:0] route_req_valid,
    output logic [DMA_CH_COUNT-1:0] route_req_src,
    output logic [DMA_CH_COUNT-1:0] route_req_dst,
    input logic [DMA_CH_COUNT-1:0] route_req_ready,
    input logic [DMA_CH_COUNT-1:0] route_dest,
    output logic [DMA_CH_COUNT-1:0] route_release,

    output logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] rd_desc_addr,
    output logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] rd_desc_len,
    output logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] rd_desc_tag,
    output logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] rd_desc_id,
    output logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] rd_desc_dest,
    output logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] rd_desc_user,
    output logic [DMA_CH_COUNT-1:0] rd_desc_valid,
    input logic [DMA_CH_COUNT-1:0] rd_desc_ready,

    input logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] rd_status_tag,
    input logic [DMA_CH_COUNT-1:0][3:0] rd_status_error,
    input logic [DMA_CH_COUNT-1:0] rd_status_valid,

    output logic [DMA_CH_COUNT-1:0][AXI_ADDR_WIDTH-1:0] wr_desc_addr,
    output logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] wr_desc_len,
    output logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] wr_desc_tag,
    output logic [DMA_CH_COUNT-1:0] wr_desc_valid,
    input logic [DMA_CH_COUNT-1:0] wr_desc_ready,

    input logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] wr_status_len,
    input logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] wr_status_tag,
    input logic [DMA_CH_COUNT-1:0][AXIS_ID_WIDTH-1:0] wr_status_id,
    input logic [DMA_CH_COUNT-1:0][AXIS_DEST_WIDTH-1:0] wr_status_dest,
    input logic [DMA_CH_COUNT-1:0][AXIS_USER_WIDTH-1:0] wr_status_user,
    input logic [DMA_CH_COUNT-1:0][3:0] wr_status_error,
    input logic [DMA_CH_COUNT-1:0] wr_status_valid,

    input logic [DMA_CH_COUNT-1:0] abort_req,
    output logic [DMA_CH_COUNT-1:0] completion_valid,
    output dma_completion_t completion [DMA_CH_COUNT-1:0],
    output logic fault_valid,
    output dma_fault_t fault
);

    localparam logic [3:0] ST_IDLE = 4'd0;
    localparam logic [3:0] ST_VALIDATE = 4'd1;
    localparam logic [3:0] ST_WAIT_ROUTE = 4'd2;
    localparam logic [3:0] ST_ISSUE_WR_DESC = 4'd3;
    localparam logic [3:0] ST_ISSUE_RD_DESC = 4'd4;
    localparam logic [3:0] ST_WAIT_STATUS = 4'd5;
    localparam logic [3:0] ST_COMPLETE = 4'd6;
    localparam logic [3:0] ST_ERROR_RECOVERY = 4'd7;

    logic [3:0] state_reg [DMA_CH_COUNT-1:0];
    dma_cmd_t cmd_reg [DMA_CH_COUNT-1:0];
    logic [TAG_WIDTH-1:0] hw_tag_reg [DMA_CH_COUNT-1:0];
    logic [6:0] tag_seq_reg [DMA_CH_COUNT-1:0];
    logic route_granted_reg [DMA_CH_COUNT-1:0];
    logic [AXIS_DEST_WIDTH-1:0] route_dest_reg [DMA_CH_COUNT-1:0];
    logic wr_desc_issued_reg [DMA_CH_COUNT-1:0];
    logic rd_desc_issued_reg [DMA_CH_COUNT-1:0];
    logic rd_done_seen_reg [DMA_CH_COUNT-1:0];
    logic wr_done_seen_reg [DMA_CH_COUNT-1:0];
    dma_error_e base_error_reg [DMA_CH_COUNT-1:0];
    dma_error_e rd_error_reg [DMA_CH_COUNT-1:0];
    dma_error_e wr_error_reg [DMA_CH_COUNT-1:0];
    logic [LEN_WIDTH-1:0] wr_completed_len_reg [DMA_CH_COUNT-1:0];
    logic abort_seen_reg [DMA_CH_COUNT-1:0];

    dma_error_e validate_error [DMA_CH_COUNT-1:0];
    logic rd_status_accept [DMA_CH_COUNT-1:0];
    logic wr_status_accept [DMA_CH_COUNT-1:0];
    logic [DMA_CH_COUNT-1:0] wr_status_accept_dst;
    dma_error_e final_error [DMA_CH_COUNT-1:0];
    dma_error_e wr_error_next [DMA_CH_COUNT-1:0];

    integer validate_index;
    integer output_index;
    integer seq_index;

    function automatic logic channel_bit(input integer channel_index);
        channel_bit = (channel_index == 1);
    endfunction

    always_comb begin
        for (validate_index = 0; validate_index < DMA_CH_COUNT; validate_index = validate_index + 1) begin
            validate_error[validate_index] = DMA_ERR_NONE;
            if (cmd_reg[validate_index].len == '0) begin
                validate_error[validate_index] = DMA_ERR_LEN_ZERO;
            end else if (!ENABLE_UNALIGNED_PARAM && !address_aligned(cmd_reg[validate_index].src_addr)) begin
                validate_error[validate_index] = DMA_ERR_SRC_ALIGN;
            end else if (!ENABLE_UNALIGNED_PARAM && !address_aligned(cmd_reg[validate_index].dst_addr)) begin
                validate_error[validate_index] = DMA_ERR_DST_ALIGN;
            end else if (cmd_reg[validate_index].src_ch != channel_bit(validate_index)) begin
                validate_error[validate_index] = DMA_ERR_ROUTE_CONFLICT;
            end else if (!range_in_single_ram(cmd_reg[validate_index].src_addr, cmd_reg[validate_index].len)) begin
                validate_error[validate_index] = DMA_ERR_SRC_RANGE;
            end else if (!range_in_single_ram(cmd_reg[validate_index].dst_addr, cmd_reg[validate_index].len)) begin
                validate_error[validate_index] = DMA_ERR_DST_RANGE;
            end else if (ranges_overlap(cmd_reg[validate_index].src_addr, cmd_reg[validate_index].dst_addr, cmd_reg[validate_index].len)) begin
                validate_error[validate_index] = DMA_ERR_OVERLAP;
            end

            rd_status_accept[validate_index] = rd_status_valid[validate_index]
                && ((state_reg[validate_index] == ST_WAIT_STATUS)
                    || ((state_reg[validate_index] == ST_ISSUE_RD_DESC) && rd_desc_issued_reg[validate_index]));
            wr_status_accept[validate_index] = wr_status_valid[cmd_reg[validate_index].dst_ch]
                && ((state_reg[validate_index] == ST_ISSUE_RD_DESC) || (state_reg[validate_index] == ST_WAIT_STATUS))
                && wr_desc_issued_reg[validate_index];

            wr_error_next[validate_index] = wr_error_reg[validate_index];
            if (wr_status_accept[validate_index]) begin
                if (wr_status_tag[cmd_reg[validate_index].dst_ch] != hw_tag_reg[validate_index]) begin
                    wr_error_next[validate_index] = merge_dma_error(
                        wr_error_next[validate_index], DMA_ERR_TAG_MISMATCH);
                end else begin
                    wr_error_next[validate_index] = merge_dma_error(
                        wr_error_next[validate_index],
                        vendor_error_to_dma(wr_status_error[cmd_reg[validate_index].dst_ch], 1'b1));
                    if (wr_status_len[cmd_reg[validate_index].dst_ch] != cmd_reg[validate_index].len) begin
                        wr_error_next[validate_index] = merge_dma_error(
                            wr_error_next[validate_index], DMA_ERR_LEN_MISMATCH);
                    end
                end
            end

            final_error[validate_index] = base_error_reg[validate_index];
            final_error[validate_index] = merge_dma_error(final_error[validate_index], rd_error_reg[validate_index]);
            final_error[validate_index] = merge_dma_error(final_error[validate_index], wr_error_reg[validate_index]);
            if (abort_seen_reg[validate_index] && (base_error_reg[validate_index] == DMA_ERR_NONE)) begin
                final_error[validate_index] = merge_dma_error(final_error[validate_index], DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED);
            end
        end

        wr_status_accept_dst = '0;
        for (validate_index = 0; validate_index < DMA_CH_COUNT; validate_index = validate_index + 1) begin
            if (wr_status_accept[validate_index]) begin
                wr_status_accept_dst[cmd_reg[validate_index].dst_ch] = 1'b1;
            end
        end
    end

    always_comb begin
        route_req_valid = '0;
        route_req_src = '0;
        route_req_dst = '0;
        route_release = '0;
        rd_desc_addr = '0;
        rd_desc_len = '0;
        rd_desc_tag = '0;
        rd_desc_id = '0;
        rd_desc_dest = '0;
        rd_desc_user = '0;
        rd_desc_valid = '0;
        wr_desc_addr = '0;
        wr_desc_len = '0;
        wr_desc_tag = '0;
        wr_desc_valid = '0;

        for (output_index = 0; output_index < DMA_CH_COUNT; output_index = output_index + 1) begin
            route_req_src[output_index] = channel_bit(output_index);
            route_req_dst[output_index] = cmd_reg[output_index].dst_ch;

            rd_desc_addr[output_index] = cmd_reg[output_index].src_addr;
            rd_desc_len[output_index] = cmd_reg[output_index].len;
            rd_desc_tag[output_index] = hw_tag_reg[output_index];
            rd_desc_id[output_index] = '0;
            rd_desc_id[output_index][0] = channel_bit(output_index);
            rd_desc_dest[output_index] = route_dest_reg[output_index];
            rd_desc_user[output_index] = '0;

            cmd_ready[output_index] = (state_reg[output_index] == ST_IDLE);
            busy[output_index] = (state_reg[output_index] != ST_IDLE);

            if (state_reg[output_index] == ST_WAIT_ROUTE) begin
                route_req_valid[output_index] = 1'b1;
            end
            if (state_reg[output_index] == ST_ISSUE_WR_DESC) begin
                wr_desc_addr[cmd_reg[output_index].dst_ch] = cmd_reg[output_index].dst_addr;
                wr_desc_len[cmd_reg[output_index].dst_ch] = cmd_reg[output_index].len;
                wr_desc_tag[cmd_reg[output_index].dst_ch] = hw_tag_reg[output_index];
                wr_desc_valid[cmd_reg[output_index].dst_ch] = 1'b1;
            end
            if (state_reg[output_index] == ST_ISSUE_RD_DESC) begin
                rd_desc_valid[output_index] = 1'b1;
            end
            if ((state_reg[output_index] == ST_COMPLETE) && route_granted_reg[output_index]) begin
                route_release[output_index] = 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            fault_valid <= 1'b0;
            fault.error <= DMA_ERR_NONE;
            fault.source <= '0;
            completion_valid <= '0;
            for (seq_index = 0; seq_index < DMA_CH_COUNT; seq_index = seq_index + 1) begin
                state_reg[seq_index] <= ST_IDLE;
                cmd_reg[seq_index] <= '0;
                hw_tag_reg[seq_index] <= '0;
                tag_seq_reg[seq_index] <= '0;
                route_granted_reg[seq_index] <= 1'b0;
                route_dest_reg[seq_index] <= '0;
                wr_desc_issued_reg[seq_index] <= 1'b0;
                rd_desc_issued_reg[seq_index] <= 1'b0;
                rd_done_seen_reg[seq_index] <= 1'b0;
                wr_done_seen_reg[seq_index] <= 1'b0;
                base_error_reg[seq_index] <= DMA_ERR_NONE;
                rd_error_reg[seq_index] <= DMA_ERR_NONE;
                wr_error_reg[seq_index] <= DMA_ERR_NONE;
                wr_completed_len_reg[seq_index] <= '0;
                abort_seen_reg[seq_index] <= 1'b0;
                completion[seq_index] <= '0;
            end
        end else begin
            fault_valid <= 1'b0;
            completion_valid <= '0;

            for (seq_index = 0; seq_index < DMA_CH_COUNT; seq_index = seq_index + 1) begin
                if (rd_status_valid[seq_index] && !rd_status_accept[seq_index]) begin
                    fault_valid <= 1'b1;
                    fault.error <= DMA_ERR_UNEXPECTED_STATUS;
                    fault.source <= (seq_index == 0) ? DMA_FAULT_SRC_RD0 : DMA_FAULT_SRC_RD1;
                end else if (wr_status_valid[seq_index] && !wr_status_accept_dst[seq_index]) begin
                    fault_valid <= 1'b1;
                    fault.error <= DMA_ERR_UNEXPECTED_STATUS;
                    fault.source <= (seq_index == 0) ? DMA_FAULT_SRC_WR0 : DMA_FAULT_SRC_WR1;
                end

                if (cmd_valid[seq_index] && cmd_ready[seq_index]) begin
                    cmd_reg[seq_index] <= cmd_payload[seq_index];
                    hw_tag_reg[seq_index] <= {channel_bit(seq_index), tag_seq_reg[seq_index]};
                    tag_seq_reg[seq_index] <= tag_seq_reg[seq_index] + 7'd1;
                    route_granted_reg[seq_index] <= 1'b0;
                    route_dest_reg[seq_index] <= '0;
                    wr_desc_issued_reg[seq_index] <= 1'b0;
                    rd_desc_issued_reg[seq_index] <= 1'b0;
                    rd_done_seen_reg[seq_index] <= 1'b0;
                    wr_done_seen_reg[seq_index] <= 1'b0;
                    base_error_reg[seq_index] <= DMA_ERR_NONE;
                    rd_error_reg[seq_index] <= DMA_ERR_NONE;
                    wr_error_reg[seq_index] <= DMA_ERR_NONE;
                    wr_completed_len_reg[seq_index] <= '0;
                    abort_seen_reg[seq_index] <= 1'b0;
                    state_reg[seq_index] <= ST_VALIDATE;
                end

                if (rd_status_accept[seq_index]) begin
                    rd_done_seen_reg[seq_index] <= 1'b1;
                    if (rd_status_tag[seq_index] != hw_tag_reg[seq_index]) begin
                        rd_error_reg[seq_index] <= merge_dma_error(rd_error_reg[seq_index], DMA_ERR_TAG_MISMATCH);
                    end else begin
                        rd_error_reg[seq_index] <= merge_dma_error(
                            rd_error_reg[seq_index], vendor_error_to_dma(rd_status_error[seq_index], 1'b0));
                    end
                end

                if (wr_status_accept[seq_index]) begin
                    wr_done_seen_reg[seq_index] <= 1'b1;
                    wr_completed_len_reg[seq_index] <= wr_status_len[cmd_reg[seq_index].dst_ch];
                    wr_error_reg[seq_index] <= wr_error_next[seq_index];
                end

                case (state_reg[seq_index])
                    ST_IDLE: begin end

                    ST_VALIDATE: begin
                        if (abort_req[seq_index]) begin
                            base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;
                            abort_seen_reg[seq_index] <= 1'b1;
                            state_reg[seq_index] <= ST_COMPLETE;
                        end else if (validate_error[seq_index] != DMA_ERR_NONE) begin
                            base_error_reg[seq_index] <= validate_error[seq_index];
                            state_reg[seq_index] <= ST_COMPLETE;
                        end else begin
                            state_reg[seq_index] <= ST_WAIT_ROUTE;
                        end
                    end

                    ST_WAIT_ROUTE: begin
                        if (route_req_valid[seq_index] && route_req_ready[seq_index]) begin
                            route_granted_reg[seq_index] <= 1'b1;
                            route_dest_reg[seq_index] <= route_dest[seq_index];
                            if (abort_req[seq_index]) begin
                                base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;
                                abort_seen_reg[seq_index] <= 1'b1;
                                state_reg[seq_index] <= ST_COMPLETE;
                            end else begin
                                state_reg[seq_index] <= ST_ISSUE_WR_DESC;
                            end
                        end else if (abort_req[seq_index]) begin
                            base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;
                            abort_seen_reg[seq_index] <= 1'b1;
                            state_reg[seq_index] <= ST_COMPLETE;
                        end
                    end

                    ST_ISSUE_WR_DESC: begin
                        if (wr_desc_valid[cmd_reg[seq_index].dst_ch]
                                && wr_desc_ready[cmd_reg[seq_index].dst_ch]) begin
                            wr_desc_issued_reg[seq_index] <= 1'b1;
                            if (abort_req[seq_index]) begin
                                abort_seen_reg[seq_index] <= 1'b1;
                            end
                            state_reg[seq_index] <= ST_ISSUE_RD_DESC;
                        end else if (abort_req[seq_index]) begin
                            base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;
                            abort_seen_reg[seq_index] <= 1'b1;
                            state_reg[seq_index] <= ST_COMPLETE;
                        end
                    end

                    ST_ISSUE_RD_DESC: begin
                        if (rd_desc_valid[seq_index] && rd_desc_ready[seq_index]) begin
                            rd_desc_issued_reg[seq_index] <= 1'b1;
                            if (abort_req[seq_index]) begin
                                abort_seen_reg[seq_index] <= 1'b1;
                            end
                            if ((wr_done_seen_reg[seq_index] || wr_status_accept[seq_index])
                                    && (rd_status_accept[seq_index])) begin
                                state_reg[seq_index] <= ST_COMPLETE;
                            end else begin
                                state_reg[seq_index] <= ST_WAIT_STATUS;
                            end
                        end else if (abort_req[seq_index]) begin
                            abort_seen_reg[seq_index] <= 1'b1;
                        end
                    end

                    ST_WAIT_STATUS: begin
                        if ((rd_done_seen_reg[seq_index] || rd_status_accept[seq_index])
                                && (wr_done_seen_reg[seq_index] || wr_status_accept[seq_index])) begin
                            state_reg[seq_index] <= ST_COMPLETE;
                        end
                    end

                    ST_COMPLETE: begin
                        completion_valid[seq_index] <= 1'b1;
                        completion[seq_index].owner_ch <= channel_bit(seq_index);
                        completion[seq_index].hw_tag <= hw_tag_reg[seq_index];
                        completion[seq_index].sw_tag <= cmd_reg[seq_index].sw_tag;
                        completion[seq_index].completed_len <= wr_completed_len_reg[seq_index];
                        completion[seq_index].error <= final_error[seq_index];
                        completion[seq_index].aborted <= abort_seen_reg[seq_index];
                        route_granted_reg[seq_index] <= 1'b0;
                        state_reg[seq_index] <= ST_IDLE;
                    end

                    ST_ERROR_RECOVERY: begin
                        fault_valid <= 1'b1;
                        fault.error <= DMA_ERR_INTERNAL;
                        fault.source <= DMA_FAULT_SRC_MANAGER;
                        base_error_reg[seq_index] <= DMA_ERR_INTERNAL;
                        state_reg[seq_index] <= ST_COMPLETE;
                    end

                    default: begin
                        fault_valid <= 1'b1;
                        fault.error <= DMA_ERR_INTERNAL;
                        fault.source <= DMA_FAULT_SRC_MANAGER;
                        state_reg[seq_index] <= ST_ERROR_RECOVERY;
                    end
                endcase

                if ((state_reg[seq_index] == ST_WAIT_STATUS) && abort_req[seq_index]) begin
                    abort_seen_reg[seq_index] <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
