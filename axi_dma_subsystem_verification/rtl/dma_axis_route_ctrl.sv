`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module dma_axis_route_ctrl (
    input  wire clk,
    input  wire rst,

    input  logic [DMA_CH_COUNT-1:0] route_req_valid,
    input  logic [DMA_CH_COUNT-1:0] route_req_src,
    input  logic [DMA_CH_COUNT-1:0] route_req_dst,
    output logic [DMA_CH_COUNT-1:0] route_req_ready,
    output logic [DMA_CH_COUNT-1:0] route_dest,
    input  logic [DMA_CH_COUNT-1:0] route_release,
    output logic [DMA_CH_COUNT-1:0] route_active,
    output logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0] route_matrix,
    output logic route_fault_valid,
    output dma_error_e route_fault_code,
    output logic [2:0] route_fault_source
);

    logic [DMA_CH_COUNT-1:0] owner_valid_reg;
    logic [DMA_CH_COUNT-1:0] owner_src_reg;
    logic [DMA_CH_COUNT-1:0] active_reg;
    logic [DMA_CH_COUNT-1:0] active_dest_reg;
    logic [DMA_CH_COUNT-1:0] rr_ptr_reg;

    logic [DMA_CH_COUNT-1:0] grant;
    logic [DMA_CH_COUNT-1:0] idempotent_grant;
    logic [DMA_CH_COUNT-1:0] candidate_valid;
    logic [DMA_CH_COUNT-1:0] invalid_request;

    integer req_src_index;
    integer req_dst_index;
    integer matrix_src_index;
    integer seq_src_index;

    always_comb begin
        route_req_ready = '0;
        route_dest = active_dest_reg;
        grant = '0;
        idempotent_grant = '0;
        candidate_valid = '0;
        invalid_request = '0;

        for (req_src_index = 0; req_src_index < DMA_CH_COUNT; req_src_index = req_src_index + 1) begin
            if (route_req_src[req_src_index] != (req_src_index == 1)) begin
                invalid_request[req_src_index] = route_req_valid[req_src_index];
            end

            if (active_reg[req_src_index] && route_req_valid[req_src_index]
                    && !route_release[req_src_index]
                    && (route_req_dst[req_src_index] == active_dest_reg[req_src_index])) begin
                idempotent_grant[req_src_index] = 1'b1;
                route_req_ready[req_src_index] = 1'b1;
                route_dest[req_src_index] = active_dest_reg[req_src_index];
            end
        end

        for (req_dst_index = 0; req_dst_index < DMA_CH_COUNT; req_dst_index = req_dst_index + 1) begin
            if (!owner_valid_reg[req_dst_index]) begin
                if (route_req_valid[rr_ptr_reg[req_dst_index]]
                        && !active_reg[rr_ptr_reg[req_dst_index]]
                        && !invalid_request[rr_ptr_reg[req_dst_index]]
                        && !idempotent_grant[rr_ptr_reg[req_dst_index]]
                        && route_req_dst[rr_ptr_reg[req_dst_index]] == (req_dst_index == 1)) begin
                    candidate_valid[rr_ptr_reg[req_dst_index]] = 1'b1;
                end else if (route_req_valid[~rr_ptr_reg[req_dst_index]]
                        && !active_reg[~rr_ptr_reg[req_dst_index]]
                        && !invalid_request[~rr_ptr_reg[req_dst_index]]
                        && !idempotent_grant[~rr_ptr_reg[req_dst_index]]
                        && route_req_dst[~rr_ptr_reg[req_dst_index]] == (req_dst_index == 1)) begin
                    candidate_valid[~rr_ptr_reg[req_dst_index]] = 1'b1;
                end
            end
        end

        for (req_src_index = 0; req_src_index < DMA_CH_COUNT; req_src_index = req_src_index + 1) begin
            if (candidate_valid[req_src_index]) begin
                grant[req_src_index] = 1'b1;
                route_req_ready[req_src_index] = 1'b1;
                route_dest[req_src_index] = route_req_dst[req_src_index];
            end
        end
    end

    assign route_active = active_reg;

    always_comb begin
        route_matrix = '0;
        for (matrix_src_index = 0; matrix_src_index < DMA_CH_COUNT; matrix_src_index = matrix_src_index + 1) begin
            if (active_reg[matrix_src_index]) begin
                route_matrix[matrix_src_index*DMA_CH_COUNT + active_dest_reg[matrix_src_index]] = 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            owner_valid_reg <= '0;
            owner_src_reg <= '0;
            active_reg <= '0;
            active_dest_reg <= '0;
            rr_ptr_reg <= '0;
            route_fault_valid <= 1'b0;
            route_fault_code <= DMA_ERR_NONE;
            route_fault_source <= '0;
        end else begin
            route_fault_valid <= 1'b0;

            for (seq_src_index = 0; seq_src_index < DMA_CH_COUNT; seq_src_index = seq_src_index + 1) begin
                if (invalid_request[seq_src_index] && !route_fault_valid) begin
                    route_fault_valid <= 1'b1;
                    route_fault_code <= DMA_ERR_ROUTE_CONFLICT;
                    route_fault_source <= DMA_FAULT_SRC_ROUTE;
                end

                if (route_release[seq_src_index]) begin
                    if (active_reg[seq_src_index]
                            && owner_valid_reg[active_dest_reg[seq_src_index]]
                            && owner_src_reg[active_dest_reg[seq_src_index]] == (seq_src_index == 1)) begin
                        owner_valid_reg[active_dest_reg[seq_src_index]] <= 1'b0;
                        active_reg[seq_src_index] <= 1'b0;
                    end else if (!route_fault_valid) begin
                        route_fault_valid <= 1'b1;
                        route_fault_code <= DMA_ERR_ROUTE_CONFLICT;
                        route_fault_source <= DMA_FAULT_SRC_ROUTE;
                    end
                end
            end

            for (seq_src_index = 0; seq_src_index < DMA_CH_COUNT; seq_src_index = seq_src_index + 1) begin
                if (grant[seq_src_index] && route_req_valid[seq_src_index]
                        && !idempotent_grant[seq_src_index]) begin
                    active_reg[seq_src_index] <= 1'b1;
                    active_dest_reg[seq_src_index] <= route_req_dst[seq_src_index];
                    owner_valid_reg[route_req_dst[seq_src_index]] <= 1'b1;
                    owner_src_reg[route_req_dst[seq_src_index]] <= (seq_src_index == 1);
                    rr_ptr_reg[route_req_dst[seq_src_index]] <= ~(seq_src_index == 1);
                end
            end
        end
    end

endmodule

`default_nettype wire
