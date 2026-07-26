`timescale 1ns/1ps

/* Passive interface for level-sensitive DMA completion interrupt. */
interface irq_if (
    input logic clk,
    input logic rst
);

    logic irq;

    clocking mon_cb @(posedge clk);
        default input #1step;
        input irq;
    endclocking

    modport MON (
        clocking mon_cb,
        input rst
    );

endinterface
