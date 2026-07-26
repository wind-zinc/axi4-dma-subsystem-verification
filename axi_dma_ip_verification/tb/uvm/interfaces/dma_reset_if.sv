`timescale 1ns/1ps

/* Verification-only request that is ORed with the power-on reset in top. */
interface dma_reset_if(input logic clk);

    logic request = 1'b0;

    task automatic pulse(input int unsigned cycles = 4);
        @(negedge clk);
        request = 1'b1;
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        request = 1'b0;
    endtask

endinterface

