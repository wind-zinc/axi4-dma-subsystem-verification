`default_nettype none

// Test-only control surface for scenarios that cannot be produced through
// the subsystem's software-visible programming model.  The interface carries
// values only; all static DUT hierarchy remains in the top-level testbench.
interface dma_subsys_test_ctrl_if(input logic clk);
    import dma_subsystem_pkg::*;

    logic reset_request;

    logic [AXI_SLAVE_COUNT-1:0] force_bresp_enable;
    logic [AXI_SLAVE_COUNT-1:0][1:0] forced_bresp;
    logic [AXI_SLAVE_COUNT-1:0] force_rresp_enable;
    logic [AXI_SLAVE_COUNT-1:0][1:0] forced_rresp;

    logic force_axil_wstrb_enable;
    logic [AXIL_STRB_WIDTH-1:0] forced_axil_wstrb;
    logic hold_axil_b_channel;
    logic hold_axil_r_channel;
    logic [EXT_AXI_MASTER_COUNT-1:0] force_ext_wstrb_zero;

    // Read-only AXI-Lite observations used by timing-directed sequences.
    logic axil_awvalid_observed;
    logic axil_awready_observed;
    logic axil_wvalid_observed;
    logic axil_wready_observed;
    logic axil_bvalid_observed;
    logic axil_bready_observed;
    logic [1:0] axil_bresp_observed;
    logic axil_arvalid_observed;
    logic axil_arready_observed;
    logic axil_rvalid_observed;
    logic axil_rready_observed;
    logic [1:0] axil_rresp_observed;

    // Sample immediately before each rising edge so timing checkers observe
    // the handshake that belongs to that edge, not a post-edge VIP update.
    clocking axil_mon_cb @(posedge clk);
        default input #1step;
        input axil_awvalid_observed;
        input axil_awready_observed;
        input axil_wvalid_observed;
        input axil_wready_observed;
        input axil_bvalid_observed;
        input axil_bready_observed;
        input axil_bresp_observed;
        input axil_arvalid_observed;
        input axil_arready_observed;
        input axil_rvalid_observed;
        input axil_rready_observed;
        input axil_rresp_observed;
    endclocking

    logic [DMA_CH_COUNT-1:0] corrupt_rd_tag_enable;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] forced_rd_tag;
    logic [DMA_CH_COUNT-1:0] corrupt_wr_tag_enable;
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] forced_wr_tag;
    logic [DMA_CH_COUNT-1:0] corrupt_wr_len_enable;
    logic [DMA_CH_COUNT-1:0][LEN_WIDTH-1:0] forced_wr_len;

    logic [DMA_CH_COUNT-1:0] force_rd_status_valid;
    logic [DMA_CH_COUNT-1:0] force_wr_status_valid;
    logic [DMA_CH_COUNT-1:0][3:0] forced_status_error;

    logic [DMA_CH_COUNT-1:0] force_cmd_reg_src_enable;
    logic [DMA_CH_COUNT-1:0] forced_cmd_reg_src;
    logic [DMA_CH_COUNT-1:0] force_route_src_enable;
    logic [DMA_CH_COUNT-1:0] forced_route_src;
    logic [DMA_CH_COUNT-1:0] force_route_ready_low;
    logic [DMA_CH_COUNT-1:0] force_manager_state_enable;
    logic [DMA_CH_COUNT-1:0][3:0] forced_manager_state;

    task automatic clear_all();
        reset_request = 1'b0;
        force_bresp_enable = '0;
        forced_bresp = '0;
        force_rresp_enable = '0;
        forced_rresp = '0;
        force_axil_wstrb_enable = 1'b0;
        forced_axil_wstrb = '1;
        hold_axil_b_channel = 1'b0;
        hold_axil_r_channel = 1'b0;
        force_ext_wstrb_zero = '0;
        corrupt_rd_tag_enable = '0;
        forced_rd_tag = '0;
        corrupt_wr_tag_enable = '0;
        forced_wr_tag = '0;
        corrupt_wr_len_enable = '0;
        forced_wr_len = '0;
        force_rd_status_valid = '0;
        force_wr_status_valid = '0;
        forced_status_error = '0;
        force_cmd_reg_src_enable = '0;
        forced_cmd_reg_src = '0;
        force_route_src_enable = '0;
        forced_route_src = '0;
        force_route_ready_low = '0;
        force_manager_state_enable = '0;
        forced_manager_state = '0;
    endtask

    task automatic pulse_reset(input int unsigned cycles = 20);
        reset_request = 1'b1;
        repeat (cycles) @(posedge clk);
        reset_request = 1'b0;
    endtask

    task automatic pulse_unexpected_rd_status(
        input int unsigned channel
    );
        force_rd_status_valid[channel] = 1'b1;
        @(posedge clk);
        force_rd_status_valid[channel] = 1'b0;
    endtask

    task automatic pulse_unexpected_wr_status(
        input int unsigned channel
    );
        force_wr_status_valid[channel] = 1'b1;
        @(posedge clk);
        force_wr_status_valid[channel] = 1'b0;
    endtask

    initial clear_all();

endinterface

`default_nettype wire
