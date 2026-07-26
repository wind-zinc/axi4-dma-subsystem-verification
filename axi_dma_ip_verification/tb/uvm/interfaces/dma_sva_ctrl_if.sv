`timescale 1ns/1ps

/*
 * Verification-only AXI-Lite request-channel stall controls.
 *
 * The top-level testbench gates both VALID into the DUT and READY back to
 * the UVM master.  Therefore a forced stall is visible to the agent and the
 * assertion checker, while the DUT cannot silently accept the transfer.
 */
interface dma_sva_ctrl_if (
    input logic clk,
    input logic rst
);

    logic stall_axil_aw;
    logic stall_axil_w;
    logic stall_axil_ar;

    initial begin
        stall_axil_aw = 1'b0;
        stall_axil_w  = 1'b0;
        stall_axil_ar = 1'b0;
    end

    task automatic clear_all();
        @(negedge clk);
        stall_axil_aw = 1'b0;
        stall_axil_w  = 1'b0;
        stall_axil_ar = 1'b0;
    endtask

    task automatic set_request_stalls(
        input bit aw,
        input bit w,
        input bit ar
    );
        @(negedge clk);
        stall_axil_aw = aw;
        stall_axil_w  = w;
        stall_axil_ar = ar;
    endtask

    task automatic release_after(input int unsigned cycles);
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        stall_axil_aw = 1'b0;
        stall_axil_w  = 1'b0;
        stall_axil_ar = 1'b0;
    endtask

endinterface
