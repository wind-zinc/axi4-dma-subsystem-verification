`timescale 1ns/1ps

/*
 * Verification-only controls for the AXI memory proxy.
 *
 * Configuration changes are made on a falling clock edge so the proxy sees
 * stable values at the next AXI handshake.  This interface is not DUT RTL.
 */
interface dma_mem_ctrl_if #(
    parameter int ADDR_WIDTH = 16
) (
    input logic clk,
    input logic rst
);

    logic                  read_fault_enable;
    logic [ADDR_WIDTH-1:0] read_fault_addr;
    logic [ADDR_WIDTH-1:0] read_fault_mask;
    logic [1:0]            read_fault_resp;

    logic                  write_fault_enable;
    logic [ADDR_WIDTH-1:0] write_fault_addr;
    logic [ADDR_WIDTH-1:0] write_fault_mask;
    logic [1:0]            write_fault_resp;

    logic stall_aw;
    logic stall_w;
    logic stall_b;
    logic stall_ar;
    logic stall_r;
    /*
     * When enabled, the verification proxy accepts and queues AXI address
     * requests independently of the simple, single-burst axi_ram model.
     * This exposes the DMA engine's real outstanding-request behavior.
     */
    logic outstanding_mode;

    logic clear_stats;
    logic [31:0] read_fault_hits;
    logic [31:0] write_fault_hits;

    initial begin
        read_fault_enable  = 1'b0;
        read_fault_addr    = '0;
        read_fault_mask    = '1;
        read_fault_resp    = 2'b00;
        write_fault_enable = 1'b0;
        write_fault_addr   = '0;
        write_fault_mask   = '1;
        write_fault_resp   = 2'b00;
        stall_aw           = 1'b0;
        stall_w            = 1'b0;
        stall_b            = 1'b0;
        stall_ar           = 1'b0;
        stall_r            = 1'b0;
        outstanding_mode   = 1'b0;
        clear_stats        = 1'b0;
    end

    task automatic clear_faults();
        @(negedge clk);
        read_fault_enable  = 1'b0;
        read_fault_addr    = '0;
        read_fault_mask    = '1;
        read_fault_resp    = 2'b00;
        write_fault_enable = 1'b0;
        write_fault_addr   = '0;
        write_fault_mask   = '1;
        write_fault_resp   = 2'b00;
    endtask

    task automatic clear_stalls();
        @(negedge clk);
        stall_aw = 1'b0;
        stall_w  = 1'b0;
        stall_b  = 1'b0;
        stall_ar = 1'b0;
        stall_r  = 1'b0;
    endtask

    task automatic clear_all();
        @(negedge clk);
        read_fault_enable  = 1'b0;
        read_fault_addr    = '0;
        read_fault_mask    = '1;
        read_fault_resp    = 2'b00;
        write_fault_enable = 1'b0;
        write_fault_addr   = '0;
        write_fault_mask   = '1;
        write_fault_resp   = 2'b00;
        stall_aw           = 1'b0;
        stall_w            = 1'b0;
        stall_b            = 1'b0;
        stall_ar           = 1'b0;
        stall_r            = 1'b0;
        outstanding_mode   = 1'b0;
        clear_stats        = 1'b1;
        @(negedge clk);
        clear_stats        = 1'b0;
    endtask

    /* Change mode only while the DMA and proxy are idle. */
    task automatic set_outstanding_mode(input bit enable);
        @(negedge clk);
        outstanding_mode = enable;
    endtask

    task automatic set_read_fault(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ADDR_WIDTH-1:0] mask,
        input logic [1:0]            resp
    );
        @(negedge clk);
        read_fault_addr   = addr;
        read_fault_mask   = mask;
        read_fault_resp   = resp;
        read_fault_enable = 1'b1;
    endtask

    task automatic set_write_fault(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ADDR_WIDTH-1:0] mask,
        input logic [1:0]            resp
    );
        @(negedge clk);
        write_fault_addr   = addr;
        write_fault_mask   = mask;
        write_fault_resp   = resp;
        write_fault_enable = 1'b1;
    endtask

    task automatic set_stalls(
        input bit aw,
        input bit w,
        input bit b,
        input bit ar,
        input bit r
    );
        @(negedge clk);
        stall_aw = aw;
        stall_w  = w;
        stall_b  = b;
        stall_ar = ar;
        stall_r  = r;
    endtask

    /* Call in a forked process after set_stalls(). */
    task automatic release_stalls_after(input int unsigned cycles);
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        stall_aw = 1'b0;
        stall_w  = 1'b0;
        stall_b  = 1'b0;
        stall_ar = 1'b0;
        stall_r  = 1'b0;
    endtask

endinterface
