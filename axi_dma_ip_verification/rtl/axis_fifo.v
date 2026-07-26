/*
 * Simple single-clock AXI-Stream FIFO.
 *
 * This FIFO decouples axi_dma_rd from axi_dma_wr and stores all stream
 * sideband signals together with each data beat.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module axis_fifo #(
    parameter DATA_WIDTH = 32,
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH = 8,
    parameter DEST_WIDTH = 8,
    parameter USER_WIDTH = 1,
    parameter DEPTH = 16
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0] s_axis_tkeep,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,
    input  wire [ID_WIDTH-1:0]   s_axis_tid,
    input  wire [DEST_WIDTH-1:0] s_axis_tdest,
    input  wire [USER_WIDTH-1:0] s_axis_tuser,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire [KEEP_WIDTH-1:0] m_axis_tkeep,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,
    output wire [ID_WIDTH-1:0]   m_axis_tid,
    output wire [DEST_WIDTH-1:0] m_axis_tdest,
    output wire [USER_WIDTH-1:0] m_axis_tuser
);

localparam PTR_WIDTH = DEPTH > 1 ? $clog2(DEPTH) : 1;
localparam COUNT_WIDTH = $clog2(DEPTH+1);
localparam WORD_WIDTH = DATA_WIDTH + KEEP_WIDTH + 1 +
                        ID_WIDTH + DEST_WIDTH + USER_WIDTH;
localparam [PTR_WIDTH-1:0] LAST_PTR = DEPTH-1;
localparam [COUNT_WIDTH-1:0] DEPTH_COUNT = DEPTH;

reg [WORD_WIDTH-1:0] mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wr_ptr_reg = {PTR_WIDTH{1'b0}};
reg [PTR_WIDTH-1:0] rd_ptr_reg = {PTR_WIDTH{1'b0}};
reg [COUNT_WIDTH-1:0] count_reg = {COUNT_WIDTH{1'b0}};

wire fifo_empty = count_reg == 0;
wire fifo_full = count_reg == DEPTH_COUNT;
wire push = s_axis_tvalid && s_axis_tready;
wire pop = m_axis_tvalid && m_axis_tready;
wire [WORD_WIDTH-1:0] output_word = mem[rd_ptr_reg];

assign s_axis_tready = !fifo_full;
assign m_axis_tvalid = !fifo_empty;
assign {m_axis_tuser, m_axis_tdest, m_axis_tid, m_axis_tlast,
        m_axis_tkeep, m_axis_tdata} = output_word;

always @(posedge clk) begin
    if (rst) begin
        wr_ptr_reg <= {PTR_WIDTH{1'b0}};
        rd_ptr_reg <= {PTR_WIDTH{1'b0}};
        count_reg <= {COUNT_WIDTH{1'b0}};
    end else begin
        if (push) begin
            mem[wr_ptr_reg] <= {
                s_axis_tuser,
                s_axis_tdest,
                s_axis_tid,
                s_axis_tlast,
                s_axis_tkeep,
                s_axis_tdata
            };

            if (wr_ptr_reg == LAST_PTR)
                wr_ptr_reg <= {PTR_WIDTH{1'b0}};
            else
                wr_ptr_reg <= wr_ptr_reg + 1'b1;
        end

        if (pop) begin
            if (rd_ptr_reg == LAST_PTR)
                rd_ptr_reg <= {PTR_WIDTH{1'b0}};
            else
                rd_ptr_reg <= rd_ptr_reg + 1'b1;
        end

        case ({push, pop})
            2'b10: count_reg <= count_reg + 1'b1;
            2'b01: count_reg <= count_reg - 1'b1;
            default: count_reg <= count_reg;
        endcase
    end
end

/* Elaboration-time parameter guard; invalid configurations terminate before
 * functional simulation and are outside the fixed project configuration. */
// VCS coverage off
initial begin
    if (DEPTH < 2) begin
        $error("axis_fifo DEPTH must be at least 2 (instance %m)");
        $finish;
    end
end
// VCS coverage on

endmodule

`resetall
