`default_nettype none

interface dma_subsys_probe_if (
    input logic clk
);
    import dma_subsystem_pkg::*;

    logic reset_n;

    logic [DMA_CH_COUNT-1:0] cmd_valid;
    logic [DMA_CH_COUNT-1:0] cmd_ready;
    dma_cmd_t cmd_payload [DMA_CH_COUNT-1:0];
    logic [DMA_CH_COUNT-1:0][TAG_WIDTH-1:0] accepted_hw_tag;

    logic [DMA_CH_COUNT-1:0] route_req_valid;
    logic [DMA_CH_COUNT-1:0] route_req_src;
    logic [DMA_CH_COUNT-1:0] route_req_dst;
    logic [DMA_CH_COUNT-1:0] route_req_ready;
    logic [DMA_CH_COUNT-1:0] route_dest;
    logic [DMA_CH_COUNT-1:0] route_release;
    logic [DMA_CH_COUNT-1:0] route_active;
    logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0] route_matrix;
    logic route_fault_valid;
    dma_error_e route_fault_code;
    logic [2:0] route_fault_source;

    logic [DMA_CH_COUNT-1:0] completion_valid;
    dma_completion_t completion [DMA_CH_COUNT-1:0];
    logic combined_fault_valid;
    dma_fault_t combined_fault;

    logic [DMA_CH_COUNT-1:0] irq_ch;
    logic global_irq;
    logic [DMA_CH_COUNT-1:0] busy;
    logic [DMA_CH_COUNT-1:0] done_pending;
    logic [DMA_CH_COUNT-1:0] error_pending;
    logic [DMA_CH_COUNT-1:0] done_enable;
    logic [DMA_CH_COUNT-1:0] error_enable;
    logic fault_pending;
    logic fault_enable;
    dma_error_e fault_code;
    logic [2:0] fault_source;

    // The clocking block gives every passive monitor one consistent sample of
    // the cycle that just completed, without racing DUT nonblocking updates.
    clocking mon_cb @(posedge clk);
        default input #1step;
        input reset_n;
        input cmd_valid, cmd_ready, cmd_payload, accepted_hw_tag;
        input route_req_valid, route_req_src, route_req_dst;
        input route_req_ready, route_dest, route_release;
        input route_active, route_matrix;
        input route_fault_valid, route_fault_code, route_fault_source;
        input completion_valid, completion;
        input combined_fault_valid, combined_fault;
        input irq_ch, global_irq, busy;
        input done_pending, error_pending, done_enable, error_enable;
        input fault_pending, fault_enable, fault_code, fault_source;
    endclocking

endinterface

`default_nettype wire
