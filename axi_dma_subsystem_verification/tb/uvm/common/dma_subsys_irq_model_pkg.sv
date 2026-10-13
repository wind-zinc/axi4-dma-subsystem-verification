`timescale 1ns / 1ps
`default_nettype none

package dma_subsys_irq_model_pkg;

    import dma_subsystem_pkg::*;

    typedef struct packed {
        logic [AXIL_BLOCK_ADDR_WIDTH-1:0] awaddr;
        logic awvalid;
        logic awready;
        logic [31:0] wdata;
        logic [AXIL_STRB_WIDTH-1:0] wstrb;
        logic wvalid;
        logic wready;
        logic bvalid;
        logic bready;
        logic [1:0] bresp;
        logic [AXIL_BLOCK_ADDR_WIDTH-1:0] araddr;
        logic arvalid;
        logic arready;
        logic rvalid;
        logic rready;
        logic [31:0] rdata;
        logic [1:0] rresp;
    } dma_irq_bus_sample_t;

    typedef struct packed {
        logic reset_n;
        logic [DMA_CH_COUNT-1:0] completion_valid;
        logic [DMA_CH_COUNT-1:0][7:0] completion_error;
        logic [DMA_CH_COUNT-1:0] busy;
        logic [DMA_CH_COUNT-1:0] route_active;
        logic [DMA_CH_COUNT*DMA_CH_COUNT-1:0] route_matrix;
        logic manager_fault_valid;
        dma_fault_t manager_fault;
        logic route_fault_valid;
        dma_fault_t route_fault;
    } dma_irq_input_sample_t;

    typedef struct packed {
        logic [DMA_CH_COUNT-1:0] done_pending;
        logic [DMA_CH_COUNT-1:0] error_pending;
        logic [DMA_CH_COUNT-1:0] done_enable;
        logic [DMA_CH_COUNT-1:0] error_enable;
        logic fault_pending;
        logic fault_enable;
        logic [7:0] fault_code;
        logic [2:0] fault_source;
        logic [DMA_CH_COUNT-1:0][7:0] last_error;
        logic [DMA_CH_COUNT-1:0][31:0] done_count;
        logic [DMA_CH_COUNT-1:0][31:0] error_count;
        logic [DMA_CH_COUNT-1:0] irq_ch;
        logic global_irq;
        logic combined_fault_valid;
        dma_fault_t combined_fault;
    } dma_irq_observed_t;

    typedef struct packed {
        logic [DMA_CH_COUNT-1:0] done_pending;
        logic [DMA_CH_COUNT-1:0] error_pending;
        logic [DMA_CH_COUNT-1:0] done_enable;
        logic [DMA_CH_COUNT-1:0] error_enable;
        logic fault_pending;
        logic fault_enable;
        logic [7:0] fault_code;
        logic [2:0] fault_source;
        logic [DMA_CH_COUNT-1:0][7:0] last_error;
        logic [DMA_CH_COUNT-1:0][31:0] done_count;
        logic [DMA_CH_COUNT-1:0][31:0] error_count;
        logic aw_pending;
        logic w_pending;
        logic [AXIL_BLOCK_ADDR_WIDTH-1:0] awaddr;
        logic [31:0] wdata;
        logic [AXIL_STRB_WIDTH-1:0] wstrb;
        logic bvalid;
        logic [1:0] bresp;
        logic rvalid;
        logic [31:0] rdata;
        logic [1:0] rresp;
    } dma_irq_model_state_t;

    function automatic dma_irq_model_state_t dma_irq_model_reset();
        return '0;
    endfunction

    function automatic logic [31:0] dma_irq_model_increment(
        input logic [31:0] value
    );
        return (value == 32'hFFFF_FFFF) ? value : value + 32'd1;
    endfunction

    function automatic logic [DMA_CH_COUNT-1:0] dma_irq_model_channel_irq(
        input dma_irq_model_state_t state
    );
        return (state.done_pending & state.done_enable)
            | (state.error_pending & state.error_enable);
    endfunction

    function automatic logic dma_irq_model_global_irq(
        input dma_irq_model_state_t state
    );
        return (|dma_irq_model_channel_irq(state))
            | (state.fault_pending & state.fault_enable);
    endfunction

    function automatic dma_fault_t dma_irq_model_selected_fault(
        input dma_irq_input_sample_t inputs
    );
        return inputs.manager_fault_valid
            ? inputs.manager_fault : inputs.route_fault;
    endfunction

    function automatic logic [31:0] dma_irq_model_read_data(
        input dma_irq_model_state_t state,
        input dma_irq_input_sample_t inputs,
        input logic [AXIL_BLOCK_ADDR_WIDTH-1:0] address
    );
        logic [31:0] value;

        value = '0;
        case (address)
            REG_IRQ_STATUS: begin
                value[1:0] = state.done_pending;
                value[9:8] = state.error_pending;
                value[17:16] = inputs.busy;
                value[30] = state.fault_pending;
                value[31] = (|state.done_pending)
                    | (|state.error_pending) | (|inputs.busy)
                    | state.fault_pending;
            end
            REG_IRQ_ENABLE: begin
                value[1:0] = state.done_enable;
                value[9:8] = state.error_enable;
                value[30] = state.fault_enable;
            end
            REG_IRQ_LAST_ERROR: begin
                value[7:0] = state.last_error[0];
                value[15:8] = state.last_error[1];
            end
            REG_CH0_DONE_COUNT: value = state.done_count[0];
            REG_CH1_DONE_COUNT: value = state.done_count[1];
            REG_CH0_ERROR_COUNT: value = state.error_count[0];
            REG_CH1_ERROR_COUNT: value = state.error_count[1];
            REG_ROUTE_STATUS: begin
                value[DMA_CH_COUNT*DMA_CH_COUNT-1:0] = inputs.route_matrix;
                value[5:4] = inputs.route_active;
            end
            REG_GLOBAL_VERSION: value = VERSION_VALUE;
            REG_FAULT_STATUS: begin
                value[7:0] = state.fault_code;
                value[10:8] = state.fault_source;
            end
            default: value = '0;
        endcase
        return value;
    endfunction

    function automatic logic [1:0] dma_irq_model_read_response(
        input logic [AXIL_BLOCK_ADDR_WIDTH-1:0] address
    );
        case (address)
            REG_IRQ_STATUS, REG_IRQ_ENABLE, REG_IRQ_LAST_ERROR,
            REG_CH0_DONE_COUNT, REG_CH1_DONE_COUNT,
            REG_CH0_ERROR_COUNT, REG_CH1_ERROR_COUNT,
            REG_ROUTE_STATUS, REG_GLOBAL_VERSION, REG_FAULT_STATUS:
                return 2'b00;
            default: return 2'b10;
        endcase
    endfunction

    function automatic dma_irq_model_state_t dma_irq_model_step(
        input dma_irq_model_state_t state,
        input dma_irq_bus_sample_t bus,
        input dma_irq_input_sample_t inputs
    );
        dma_irq_model_state_t next_state;
        dma_fault_t selected_fault;
        logic write_commit;

        if (!inputs.reset_n) begin
            return dma_irq_model_reset();
        end

        next_state = state;
        write_commit = state.aw_pending && state.w_pending && !state.bvalid;

        if (state.bvalid && bus.bready) begin
            next_state.bvalid = 1'b0;
        end
        if (state.rvalid && bus.rready) begin
            next_state.rvalid = 1'b0;
        end
        if (bus.arvalid && bus.arready) begin
            next_state.rvalid = 1'b1;
            next_state.rdata = dma_irq_model_read_data(state, inputs, bus.araddr);
            next_state.rresp = dma_irq_model_read_response(bus.araddr);
        end
        if (bus.awvalid && bus.awready) begin
            next_state.aw_pending = 1'b1;
            next_state.awaddr = bus.awaddr;
        end
        if (bus.wvalid && bus.wready) begin
            next_state.w_pending = 1'b1;
            next_state.wdata = bus.wdata;
            next_state.wstrb = bus.wstrb;
        end

        if (write_commit) begin
            next_state.aw_pending = 1'b0;
            next_state.w_pending = 1'b0;
            next_state.bvalid = 1'b1;
            next_state.bresp = 2'b10;
            case (state.awaddr)
                REG_IRQ_ENABLE: begin
                    next_state.bresp = 2'b00;
                    if (state.wstrb[0]) begin
                        next_state.done_enable = state.wdata[1:0];
                    end
                    if (state.wstrb[1]) begin
                        next_state.error_enable = state.wdata[9:8];
                    end
                    if (state.wstrb[3]) begin
                        next_state.fault_enable = state.wdata[30];
                    end
                end
                REG_IRQ_CLEAR: begin
                    next_state.bresp = 2'b00;
                    if (state.wstrb[0]) begin
                        next_state.done_pending &= ~state.wdata[1:0];
                    end
                    if (state.wstrb[1]) begin
                        next_state.error_pending &= ~state.wdata[9:8];
                    end
                    if (state.wstrb[3] && state.wdata[30]) begin
                        next_state.fault_pending = 1'b0;
                    end
                end
                default: begin end
            endcase
        end

        for (int unsigned channel = 0; channel < DMA_CH_COUNT; channel++) begin
            if (inputs.completion_valid[channel]) begin
                next_state.done_pending[channel] = 1'b1;
                next_state.done_count[channel] =
                    dma_irq_model_increment(state.done_count[channel]);
                if (inputs.completion_error[channel] != DMA_ERR_NONE) begin
                    next_state.error_pending[channel] = 1'b1;
                    next_state.last_error[channel] = inputs.completion_error[channel];
                    next_state.error_count[channel] =
                        dma_irq_model_increment(state.error_count[channel]);
                end
            end
        end

        if (inputs.manager_fault_valid || inputs.route_fault_valid) begin
            selected_fault = dma_irq_model_selected_fault(inputs);
            next_state.fault_pending = 1'b1;
            next_state.fault_code = selected_fault.error;
            next_state.fault_source = selected_fault.source;
        end
        return next_state;
    endfunction

    function automatic logic [16:0] dma_irq_model_mismatches(
        input dma_irq_model_state_t state,
        input dma_irq_bus_sample_t bus,
        input dma_irq_input_sample_t inputs,
        input dma_irq_observed_t observed
    );
        logic [16:0] mismatches;
        logic expected_fault_valid;
        dma_fault_t expected_fault;

        mismatches = '0;
        mismatches[0] = observed.done_pending !== state.done_pending;
        mismatches[1] = observed.error_pending !== state.error_pending;
        mismatches[2] = {observed.done_enable, observed.error_enable}
            !== {state.done_enable, state.error_enable};
        mismatches[3] = {observed.fault_pending, observed.fault_enable}
            !== {state.fault_pending, state.fault_enable};
        mismatches[4] = {observed.fault_code, observed.fault_source}
            !== {state.fault_code, state.fault_source};
        mismatches[5] = observed.last_error !== state.last_error;
        mismatches[6] = observed.done_count !== state.done_count;
        mismatches[7] = observed.error_count !== state.error_count;
        mismatches[8] = {observed.irq_ch, observed.global_irq}
            !== {dma_irq_model_channel_irq(state), dma_irq_model_global_irq(state)};
        mismatches[9] = bus.awready !== (!state.aw_pending && !state.bvalid);
        mismatches[10] = bus.wready !== (!state.w_pending && !state.bvalid);
        mismatches[11] = bus.arready !== !state.rvalid;
        mismatches[12] = bus.bvalid !== state.bvalid;
        mismatches[13] = (state.bvalid || bus.bvalid)
            && (bus.bresp !== state.bresp);
        mismatches[14] = bus.rvalid !== state.rvalid;
        mismatches[15] = (state.rvalid || bus.rvalid)
            && ({bus.rdata, bus.rresp} !== {state.rdata, state.rresp});

        expected_fault_valid = inputs.manager_fault_valid || inputs.route_fault_valid;
        expected_fault = dma_irq_model_selected_fault(inputs);
        mismatches[16] = (observed.combined_fault_valid !== expected_fault_valid)
            || (expected_fault_valid
                && (observed.combined_fault !== expected_fault));
        return mismatches;
    endfunction

endpackage

`default_nettype wire
