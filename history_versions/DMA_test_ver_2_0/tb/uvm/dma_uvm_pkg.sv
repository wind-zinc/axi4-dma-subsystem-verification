`timescale 1ns/1ps

package dma_uvm_pkg;

    import uvm_pkg::*;
    import axil_agent_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [7:0] REG_CONTROL         = 8'h00;
    localparam bit [7:0] REG_STATUS          = 8'h04;
    localparam bit [7:0] REG_SRC_ADDR        = 8'h08;
    localparam bit [7:0] REG_DST_ADDR        = 8'h0c;
    localparam bit [7:0] REG_LENGTH          = 8'h10;
    localparam bit [7:0] REG_TAG             = 8'h14;
    localparam bit [7:0] REG_SUBMIT          = 8'h18;
    localparam bit [7:0] REG_COMP_TAG        = 8'h1c;
    localparam bit [7:0] REG_COMP_LENGTH     = 8'h20;
    localparam bit [7:0] REG_COMP_STATUS     = 8'h24;
    localparam bit [7:0] REG_COMP_POP        = 8'h28;
    localparam bit [7:0] REG_QUEUE_LEVELS    = 8'h2c;
    localparam bit [7:0] REG_SUBMITTED_COUNT = 8'h30;
    localparam bit [7:0] REG_COMPLETED_COUNT = 8'h34;

    `include "dma_observed_item.sv"
    `include "dma_base_seq.sv"
    `include "dma_random_smoke_seq.sv"
    `include "dma_ref_model.sv"
    `include "dma_observer_monitor.sv"
    `include "dma_scoreboard.sv"
    `include "dma_coverage.sv"
    `include "dma_env.sv"
    `include "dma_random_smoke_test.sv"

endpackage
