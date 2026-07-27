`default_nettype none
`timescale 1ns / 1ps

import dma_subsystem_pkg::*;

module dma_irq_status_ctrl (
    input wire clk,
    input wire rst,

    input logic [AXIL_BLOCK_ADDR_WIDTH-1:0] s_axil_awaddr,
    input logic [2:0]                       s_axil_awprot,
    input logic                             s_axil_awvalid,
    output logic                             s_axil_awready,
    input logic [AXIL_DATA_WIDTH-1:0]       s_axil_wdata,
    input logic [AXIL_STRB_WIDTH-1:0]       s_axil_wstrb,
    input logic                             s_axil_wvalid,
    output logic                             s_axil_wready,
    output logic [1:0]                       s_axil_bresp,
    output logic                             s_axil_bvalid,
    input logic                             s_axil_bready,
    input logic [AXIL_BLOCK_ADDR_WIDTH-1:0] s_axil_araddr,
    input logic [2:0]                       s_axil_arprot,
    input logic                             s_axil_arvalid,
    output logic                             s_axil_arready,
    output logic [AXIL_DATA_WIDTH-1:0]       s_axil_rdata,
    output logic [1:0]                       s_axil_rresp,
    output logic                             s_axil_rvalid,
    input logic                             s_axil_rready,

    input logic [DMA_CH_COUNT-1:0] completion_valid,
    input dma_completion_t completion [DMA_CH_COUNT-1:0],
    input logic [DMA_CH_COUNT-1:0] busy,
    input logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0] route_matrix,
    input logic [DMA_CH_COUNT-1:0] route_active,
    input logic fault_valid,
    input dma_fault_t fault,
    output logic [DMA_CH_COUNT-1:0] irq_ch,
    output logic irq
);

    logic aw_hold_valid;
    logic [AXIL_BLOCK_ADDR_WIDTH-1:0] aw_hold_addr;
    logic w_hold_valid;
    logic [AXIL_DATA_WIDTH-1:0] w_hold_data;
    logic [AXIL_STRB_WIDTH-1:0] w_hold_strb;
    logic [AXIL_DATA_WIDTH-1:0] read_data_next;
    logic [1:0] read_resp_next;
    logic write_commit;
    logic write_valid;
    logic [31:0] merged_enable_word;

    logic [DMA_CH_COUNT-1:0] done_pending_reg;
    logic [DMA_CH_COUNT-1:0] error_pending_reg;
    logic [DMA_CH_COUNT-1:0] done_enable_reg;
    logic [DMA_CH_COUNT-1:0] error_enable_reg;
    logic fault_enable_reg;
    dma_error_e last_error_reg [DMA_CH_COUNT-1:0];
    logic [31:0] done_count_reg [DMA_CH_COUNT-1:0];
    logic [31:0] error_count_reg [DMA_CH_COUNT-1:0];
    logic fault_pending_reg;
    dma_error_e fault_code_reg;
    logic [2:0] fault_source_reg;

    integer seq_index;
    integer irq_index;

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
        read_data_next = '0;
        read_resp_next = 2'b00;
        case (s_axil_araddr)
            REG_IRQ_STATUS: begin
                read_data_next[1:0] = done_pending_reg;
                read_data_next[9:8] = error_pending_reg;
                read_data_next[17:16] = busy;
                read_data_next[30] = fault_pending_reg;
                read_data_next[31] = (|done_pending_reg)
                    || (|error_pending_reg) || (|busy) || fault_pending_reg;
            end
            REG_IRQ_ENABLE: begin
                read_data_next[1:0] = done_enable_reg;
                read_data_next[9:8] = error_enable_reg;
                read_data_next[30] = fault_enable_reg;
            end
            REG_IRQ_LAST_ERROR: begin
                read_data_next[7:0] = last_error_reg[0];
                read_data_next[15:8] = last_error_reg[1];
            end
            REG_CH0_DONE_COUNT: read_data_next = done_count_reg[0];
            REG_CH1_DONE_COUNT: read_data_next = done_count_reg[1];
            REG_CH0_ERROR_COUNT: read_data_next = error_count_reg[0];
            REG_CH1_ERROR_COUNT: read_data_next = error_count_reg[1];
            REG_ROUTE_STATUS: begin
                read_data_next[DMA_CH_COUNT*DMA_CH_COUNT-1:0] = route_matrix;
                read_data_next[5:4] = route_active;
            end
            REG_GLOBAL_VERSION: read_data_next = VERSION_VALUE;
            REG_FAULT_STATUS: begin
                read_data_next[7:0] = fault_code_reg;
                read_data_next[10:8] = fault_source_reg;
            end
            default: begin
                read_data_next = '0;
                read_resp_next = 2'b10;
            end
        endcase
    end

    always_comb begin
        merged_enable_word = 32'd0;
        merged_enable_word[1:0] = done_enable_reg;
        merged_enable_word[9:8] = error_enable_reg;
        merged_enable_word[30] = fault_enable_reg;
        merged_enable_word = merge_wstrb(merged_enable_word, w_hold_data, w_hold_strb);

        write_valid = aw_hold_valid && w_hold_valid
            && ((aw_hold_addr == REG_IRQ_ENABLE) || (aw_hold_addr == REG_IRQ_CLEAR));
    end

    assign s_axil_awready = !aw_hold_valid && !s_axil_bvalid;
    assign s_axil_wready = !w_hold_valid && !s_axil_bvalid;
    assign s_axil_arready = !s_axil_rvalid;
    assign write_commit = aw_hold_valid && w_hold_valid && !s_axil_bvalid;

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
            done_pending_reg <= '0;
            error_pending_reg <= '0;
            done_enable_reg <= '0;
            error_enable_reg <= '0;
            fault_enable_reg <= 1'b0;
            fault_pending_reg <= 1'b0;
            fault_code_reg <= DMA_ERR_NONE;
            fault_source_reg <= '0;
            for (seq_index = 0; seq_index < DMA_CH_COUNT; seq_index = seq_index + 1) begin
                last_error_reg[seq_index] <= DMA_ERR_NONE;
                done_count_reg[seq_index] <= '0;
                error_count_reg[seq_index] <= '0;
            end
        end else begin
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

            if (write_commit) begin
                s_axil_bvalid <= 1'b1;
                s_axil_bresp <= write_valid ? 2'b00 : 2'b10;
                aw_hold_valid <= 1'b0;
                w_hold_valid <= 1'b0;
                if (write_valid && (aw_hold_addr == REG_IRQ_ENABLE)) begin
                    done_enable_reg <= merged_enable_word[1:0];
                    error_enable_reg <= merged_enable_word[9:8];
                    fault_enable_reg <= merged_enable_word[30];
                end
            end

            if (write_commit && write_valid && (aw_hold_addr == REG_IRQ_CLEAR)) begin
                if (w_hold_strb[0]) begin
                    done_pending_reg <= done_pending_reg & ~w_hold_data[1:0];
                end
                if (w_hold_strb[1]) begin
                    error_pending_reg <= error_pending_reg & ~w_hold_data[9:8];
                end
                if (w_hold_strb[3] && w_hold_data[30]) begin
                    fault_pending_reg <= 1'b0;
                end
            end

            for (seq_index = 0; seq_index < DMA_CH_COUNT; seq_index = seq_index + 1) begin
                if (completion_valid[seq_index]) begin
                    done_pending_reg[seq_index] <= 1'b1;
                    done_count_reg[seq_index] <= saturating_inc32(done_count_reg[seq_index]);
                    if (completion[seq_index].error != DMA_ERR_NONE) begin
                        error_pending_reg[seq_index] <= 1'b1;
                        last_error_reg[seq_index] <= completion[seq_index].error;
                        error_count_reg[seq_index] <= saturating_inc32(error_count_reg[seq_index]);
                    end
                end
            end

            if (fault_valid) begin
                fault_pending_reg <= 1'b1;
                fault_code_reg <= fault.error;
                fault_source_reg <= fault.source;
            end
        end
    end

    always_comb begin
        for (irq_index = 0; irq_index < DMA_CH_COUNT; irq_index = irq_index + 1) begin
            irq_ch[irq_index] = (done_pending_reg[irq_index] && done_enable_reg[irq_index])
                || (error_pending_reg[irq_index] && error_enable_reg[irq_index]);
        end
        irq = (|irq_ch) || (fault_pending_reg && fault_enable_reg);
    end

    logic unused_prot;
    always_comb begin
        unused_prot = ^{s_axil_awprot, s_axil_arprot};
    end

endmodule

`default_nettype wire
