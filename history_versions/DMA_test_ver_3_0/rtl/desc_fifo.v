/*
 * Small single-clock ready/valid FIFO.
 *
 * The descriptor manager uses this module for both queued DMA requests and
 * queued completion records.  The memory contents are not reset; count_reg
 * determines which entries are valid after reset.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module desc_fifo #(
    parameter DATA_WIDTH = 104,
    parameter DEPTH = 4
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] s_data,
    input  wire                  s_valid,
    output wire                  s_ready,

    output wire [DATA_WIDTH-1:0] m_data,
    output wire                  m_valid,
    input  wire                  m_ready,

    output wire [$clog2(DEPTH+1)-1:0] level,
    output wire                  full,
    output wire                  empty
);

localparam PTR_WIDTH = DEPTH > 1 ? $clog2(DEPTH) : 1;
localparam COUNT_WIDTH = $clog2(DEPTH+1);
localparam [PTR_WIDTH-1:0] LAST_PTR = DEPTH-1;
localparam [COUNT_WIDTH-1:0] DEPTH_COUNT = DEPTH;

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wr_ptr_reg = {PTR_WIDTH{1'b0}};
reg [PTR_WIDTH-1:0] rd_ptr_reg = {PTR_WIDTH{1'b0}};
reg [COUNT_WIDTH-1:0] count_reg = {COUNT_WIDTH{1'b0}};

wire push = s_valid && s_ready;
wire pop = m_valid && m_ready;

assign full = count_reg == DEPTH_COUNT;
assign empty = count_reg == 0;
assign level = count_reg;

/* A full FIFO accepts a new item on the cycle after a pop.  This costs at
 * most one cycle and keeps the storage behavior easy to understand. */
assign s_ready = !full;
assign m_valid = !empty;
assign m_data = mem[rd_ptr_reg];

always @(posedge clk) begin
    if (rst) begin
        wr_ptr_reg <= {PTR_WIDTH{1'b0}};
        rd_ptr_reg <= {PTR_WIDTH{1'b0}};
        count_reg <= {COUNT_WIDTH{1'b0}};
    end else begin
        if (push) begin
            mem[wr_ptr_reg] <= s_data;

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

initial begin
    if (DATA_WIDTH < 1) begin
        $error("desc_fifo DATA_WIDTH must be at least 1 (instance %m)");
        $finish;
    end

    if (DEPTH < 2) begin
        $error("desc_fifo DEPTH must be at least 2 (instance %m)");
        $finish;
    end
end

endmodule

`resetall
