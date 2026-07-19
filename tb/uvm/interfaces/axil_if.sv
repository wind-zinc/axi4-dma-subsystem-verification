`timescale 1ns/1ps

/*
 * AXI4-Lite interface used by the UVM control agent.
 *
 * The DUT is an AXI4-Lite slave.  Therefore the UVM driver owns AWADDR,
 * WDATA, ARADDR and the corresponding VALID/READY response inputs.
 *
 * Clocking blocks keep driver and monitor code independent from raw signal
 * sampling details.
 */
interface axil_if #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH/8
) (
    input logic clk,
    input logic rst
);

    logic [ADDR_WIDTH-1:0] awaddr;
    logic [2:0]            awprot;
    logic                  awvalid;
    logic                  awready;

    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    logic [ADDR_WIDTH-1:0] araddr;
    logic [2:0]            arprot;
    logic                  arvalid;
    logic                  arready;

    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    /*
     * Driver outputs are applied immediately after the selected clock edge.
     * Inputs are sampled one simulator time-step before the edge, avoiding
     * races between the DUT and class-based UVM code.
     */
    clocking drv_cb @(posedge clk);
        default input #1step output #0;

        output awaddr;
        output awprot;
        output awvalid;
        input  awready;

        output wdata;
        output wstrb;
        output wvalid;
        input  wready;

        input  bresp;
        input  bvalid;
        output bready;

        output araddr;
        output arprot;
        output arvalid;
        input  arready;

        input  rdata;
        input  rresp;
        input  rvalid;
        output rready;
    endclocking

    /* The monitor samples every AXI4-Lite signal but drives nothing. */
    clocking mon_cb @(posedge clk);
        default input #1step;

        input awaddr;
        input awprot;
        input awvalid;
        input awready;

        input wdata;
        input wstrb;
        input wvalid;
        input wready;

        input bresp;
        input bvalid;
        input bready;

        input araddr;
        input arprot;
        input arvalid;
        input arready;

        input rdata;
        input rresp;
        input rvalid;
        input rready;
    endclocking

    modport DRV (
        clocking drv_cb,
        input rst
    );

    modport MON (
        clocking mon_cb,
        input rst
    );

    modport DUT (
        input  clk,
        input  rst,

        input  awaddr,
        input  awprot,
        input  awvalid,
        output awready,

        input  wdata,
        input  wstrb,
        input  wvalid,
        output wready,

        output bresp,
        output bvalid,
        input  bready,

        input  araddr,
        input  arprot,
        input  arvalid,
        output arready,

        output rdata,
        output rresp,
        output rvalid,
        input  rready
    );

endinterface
