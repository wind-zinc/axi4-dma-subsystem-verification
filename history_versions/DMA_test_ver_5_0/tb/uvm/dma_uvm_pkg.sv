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
    `include "dma_reg_model.sv"
    `include "dma_axil_reg_adapter.sv"
    `include "dma_base_seq.sv"
    `include "dma_random_smoke_seq.sv"
    `include "dma_ral_base_seq.sv"
    `include "dma_ral_smoke_seq.sv"
    `include "dma_wstrb_seq.sv"
    `include "dma_boundary_matrix_seq.sv"
    `include "dma_irq_mode_seq.sv"
    `include "dma_invalid_desc_seq.sv"
    `include "dma_length_sweep_seq.sv"
    `include "dma_queue_saturation_seq.sv"
    `include "dma_pop_empty_seq.sv"
    `include "dma_sub_beat_tag_seq.sv"
    `include "dma_alignment_reject_seq.sv"
    `include "dma_access_policy_seq.sv"

    /* Stage-5 coverage-convergence sequences. */
    `include "dma_mem_ral_base_seq.sv"
    `include "dma_error_response_seq.sv"
    `include "dma_queue_mid_level_seq.sv"
    `include "dma_empty_completion_read_seq.sv"
    `include "dma_axi_backpressure_seq.sv"
    `include "dma_toggle_stress_seq.sv"
    `include "dma_command_noop_seq.sv"
    `include "dma_address_range_reject_seq.sv"
    `include "dma_ro_write_protection_seq.sv"

    `include "dma_ref_model.sv"
    `include "dma_observer_monitor.sv"
    `include "dma_scoreboard.sv"
    `include "dma_coverage.sv"
    `include "dma_env.sv"
    `include "dma_test_base.sv"
    `include "dma_random_smoke_test.sv"
    `include "dma_ral_smoke_test.sv"
    `include "dma_wstrb_test.sv"
    `include "dma_boundary_matrix_test.sv"
    `include "dma_irq_mode_test.sv"
    `include "dma_invalid_desc_test.sv"
    `include "dma_length_sweep_test.sv"
    `include "dma_queue_saturation_test.sv"
    `include "dma_pop_empty_test.sv"
    `include "dma_sub_beat_tag_test.sv"
    `include "dma_alignment_reject_test.sv"
    `include "dma_access_policy_test.sv"

    /* Stage-5 coverage-convergence tests. */
    `include "dma_mem_test_base.sv"
    `include "dma_error_response_test.sv"
    `include "dma_queue_mid_level_test.sv"
    `include "dma_empty_completion_read_test.sv"
    `include "dma_axi_backpressure_test.sv"
    `include "dma_toggle_stress_test.sv"
    `include "dma_command_noop_test.sv"
    `include "dma_address_range_reject_test.sv"
    `include "dma_ro_write_protection_test.sv"

endpackage
