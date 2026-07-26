`timescale 1ns/1ps

package axil_agent_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int AXIL_ADDR_WIDTH = 8;
    parameter int AXIL_DATA_WIDTH = 32;
    parameter int AXIL_STRB_WIDTH = AXIL_DATA_WIDTH/8;

    `include "axil_item.sv"
    `include "axil_sequencer.sv"
    `include "axil_driver.sv"
    `include "axil_monitor.sv"
    `include "axil_agent.sv"

endpackage
