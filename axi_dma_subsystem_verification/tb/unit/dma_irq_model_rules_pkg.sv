`timescale 1ns / 1ps
`default_nettype none

package dma_irq_model_rules_pkg;
    import dma_subsystem_pkg::*;
    import dma_subsys_irq_model_pkg::*;

    function automatic dma_irq_model_state_t commit_write(
        input dma_irq_model_state_t state,
        input logic [11:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input dma_irq_input_sample_t inputs
    );
        dma_irq_model_state_t prepared;
        dma_irq_bus_sample_t bus;

        prepared = state;
        prepared.aw_pending = 1'b1;
        prepared.w_pending = 1'b1;
        prepared.bvalid = 1'b0;
        prepared.awaddr = address;
        prepared.wdata = data;
        prepared.wstrb = strobe;
        bus = '0;
        return dma_irq_model_step(prepared, bus, inputs);
    endfunction

    function automatic dma_irq_observed_t make_observation(
        input dma_irq_model_state_t state
    );
        dma_irq_observed_t observed;
        observed = '0;
        observed.done_pending = state.done_pending;
        observed.error_pending = state.error_pending;
        observed.done_enable = state.done_enable;
        observed.error_enable = state.error_enable;
        observed.fault_pending = state.fault_pending;
        observed.fault_enable = state.fault_enable;
        observed.fault_code = state.fault_code;
        observed.fault_source = state.fault_source;
        observed.last_error = state.last_error;
        observed.done_count = state.done_count;
        observed.error_count = state.error_count;
        observed.irq_ch = dma_irq_model_channel_irq(state);
        observed.global_irq = dma_irq_model_global_irq(state);
        return observed;
    endfunction

    function automatic int run_rules();
        dma_irq_model_state_t state;
        dma_irq_model_state_t result;
        dma_irq_input_sample_t inputs;
        dma_irq_bus_sample_t bus;
        dma_irq_observed_t observed;
        logic [16:0] mismatches;
        int failures;

        failures = 0;
        inputs = '0;
        inputs.reset_n = 1'b1;
        bus = '0;
        state = dma_irq_model_reset();
        if (state !== '0) failures++;
        if (dma_irq_model_increment(32'd0) !== 32'd1) failures++;
        if (dma_irq_model_increment(32'hFFFF_FFFE) !== 32'hFFFF_FFFF) failures++;
        if (dma_irq_model_increment(32'hFFFF_FFFF) !== 32'hFFFF_FFFF) failures++;

        bus.awvalid = 1'b1;
        bus.awready = 1'b1;
        bus.awaddr = REG_IRQ_ENABLE;
        state = dma_irq_model_step(state, bus, inputs);
        if (!state.aw_pending || state.w_pending || state.bvalid) failures++;
        bus.awvalid = 1'b0;
        bus.wvalid = 1'b1;
        bus.wready = 1'b1;
        bus.wdata = 32'h4000_0303;
        bus.wstrb = 4'hF;
        state = dma_irq_model_step(state, bus, inputs);
        if (!state.w_pending || state.done_enable != 0 || state.bvalid) failures++;
        bus.wvalid = 1'b0;
        state = dma_irq_model_step(state, bus, inputs);
        if ({state.done_enable, state.error_enable, state.fault_enable}
                !== {2'b11, 2'b11, 1'b1}) failures++;
        if (!state.bvalid || state.bresp != 0 || state.aw_pending || state.w_pending) failures++;
        result = dma_irq_model_step(state, bus, inputs);
        if (result !== state) failures++;
        bus.bready = 1'b1;
        state = dma_irq_model_step(state, bus, inputs);
        if (state.bvalid) failures++;

        for (int unsigned strobe = 0; strobe < 16; strobe++) begin
            state = dma_irq_model_reset();
            state.done_pending = 2'b11;
            state.error_pending = 2'b11;
            state.fault_pending = 1'b1;
            state.fault_code = DMA_ERR_INTERNAL;
            state.fault_source = DMA_FAULT_SRC_MANAGER;
            result = commit_write(state, REG_IRQ_CLEAR, 32'h4000_0101, 4'(strobe), inputs);
            if (result.done_pending !== (strobe[0] ? 2'b10 : 2'b11)) failures++;
            if (result.error_pending !== (strobe[1] ? 2'b10 : 2'b11)) failures++;
            if (result.fault_pending !== !strobe[3]) failures++;
            if ({result.fault_code, result.fault_source}
                    !== {DMA_ERR_INTERNAL, DMA_FAULT_SRC_MANAGER}) failures++;
            result = commit_write(state, REG_IRQ_ENABLE, 32'h4000_0201, 4'(strobe), inputs);
            if (result.done_enable !== (strobe[0] ? 2'b01 : 2'b00)) failures++;
            if (result.error_enable !== (strobe[1] ? 2'b10 : 2'b00)) failures++;
            if (result.fault_enable !== strobe[3]) failures++;
            if ({result.done_pending, result.error_pending, result.fault_pending}
                    !== {2'b11, 2'b11, 1'b1}) failures++;
        end

        state = dma_irq_model_reset();
        state.done_pending = 2'b11;
        state.error_pending = 2'b11;
        state.fault_pending = 1'b1;
        inputs.completion_valid = 2'b01;
        result = commit_write(state, REG_IRQ_CLEAR, 32'h4000_0303, 4'hF, inputs);
        if ({result.done_pending, result.error_pending, result.fault_pending}
                !== {2'b01, 2'b00, 1'b0}) failures++;
        if (result.done_count[0] !== 32'd1 || result.done_count[1] !== 32'd0) failures++;
        inputs.completion_error[0] = DMA_ERR_AXI_RD_SLVERR;
        inputs.completion_valid = 2'b11;
        inputs.completion_error[1] = DMA_ERR_AXI_WR_DECERR;
        inputs.manager_fault_valid = 1'b1;
        inputs.manager_fault.error = DMA_ERR_INTERNAL;
        inputs.manager_fault.source = DMA_FAULT_SRC_MANAGER;
        inputs.route_fault_valid = 1'b1;
        inputs.route_fault.error = DMA_ERR_ROUTE_CONFLICT;
        inputs.route_fault.source = DMA_FAULT_SRC_ROUTE;
        result = commit_write(state, REG_IRQ_CLEAR, 32'h4000_0303, 4'hF, inputs);
        if ({result.done_pending, result.error_pending, result.fault_pending}
                !== {2'b11, 2'b11, 1'b1}) failures++;
        if ({result.fault_code, result.fault_source}
                !== {DMA_ERR_INTERNAL, DMA_FAULT_SRC_MANAGER}) failures++;
        if (result.error_count[0] != 1 || result.error_count[1] != 1) failures++;
        inputs.manager_fault_valid = 1'b0;
        result = commit_write(state, REG_IRQ_CLEAR, 32'h4000_0303, 4'hF, inputs);
        if ({result.fault_code, result.fault_source}
                !== {DMA_ERR_ROUTE_CONFLICT, DMA_FAULT_SRC_ROUTE}) failures++;

        inputs = '0;
        inputs.reset_n = 1'b1;
        bus = '0;
        state = dma_irq_model_reset();
        inputs.completion_valid = 2'b01;
        inputs.completion_error[0] = DMA_ERR_AXI_RD_SLVERR;
        state.done_count[0] = 32'hFFFF_FFFE;
        state.error_count[0] = 32'hFFFF_FFFE;
        state = dma_irq_model_step(state, bus, inputs);
        state = dma_irq_model_step(state, bus, inputs);
        if (state.done_count[0] !== 32'hFFFF_FFFF || state.error_count[0] !== 32'hFFFF_FFFF) failures++;
        inputs.completion_error[0] = DMA_ERR_NONE;
        state = dma_irq_model_step(state, bus, inputs);
        if (!state.error_pending[0] || state.last_error[0] != DMA_ERR_AXI_RD_SLVERR) failures++;

        state = dma_irq_model_reset();
        inputs = '0;
        inputs.reset_n = 1'b1;
        inputs.completion_valid = 2'b01;
        bus.arvalid = 1'b1;
        bus.arready = 1'b1;
        bus.araddr = REG_IRQ_STATUS;
        state = dma_irq_model_step(state, bus, inputs);
        if (!state.rvalid || state.rdata != 0 || state.rresp != 0 || state.done_pending != 1) failures++;
        bus.arvalid = 1'b0;
        inputs.completion_valid = 2'b10;
        result = dma_irq_model_step(state, bus, inputs);
        if (result.rdata !== 32'd0 || !result.rvalid || result.done_pending != 3) failures++;
        bus.rready = 1'b1;
        result = dma_irq_model_step(result, bus, inputs);
        if (result.rvalid) failures++;

        inputs = '0;
        inputs.reset_n = 1'b1;
        state = dma_irq_model_reset();
        state.done_pending = 2'b01;
        state.error_pending = 2'b10;
        state.fault_pending = 1'b1;
        inputs.busy = 2'b11;
        inputs.route_active = 2'b10;
        inputs.route_matrix = 4'hA;
        if (dma_irq_model_read_data(state, inputs, REG_IRQ_STATUS) !== 32'hC003_0201) failures++;
        if (dma_irq_model_global_irq(state) !== 1'b0) failures++;
        if (dma_irq_model_read_data(state, inputs, REG_ROUTE_STATUS) !== 32'h0000_002A) failures++;
        if (dma_irq_model_read_data(state, inputs, REG_GLOBAL_VERSION) !== VERSION_VALUE) failures++;
        if (dma_irq_model_read_response(REG_IRQ_CLEAR) !== 2'b10) failures++;
        if (dma_irq_model_read_response(12'hFFC) !== 2'b10) failures++;
        result = commit_write(state, REG_GLOBAL_VERSION, 32'hFFFF_FFFF, 4'hF, inputs);
        if (!result.bvalid || result.bresp != 2'b10 || result.done_pending != 1) failures++;

        state = dma_irq_model_reset();
        inputs = '0;
        inputs.reset_n = 1'b1;
        bus = '0;
        bus.awready = 1'b1;
        bus.wready = 1'b1;
        bus.arready = 1'b1;
        observed = make_observation(state);
        mismatches = dma_irq_model_mismatches(state, bus, inputs, observed);
        if (mismatches !== '0) failures++;
        for (int unsigned bit_index = 0; bit_index < 9; bit_index++) begin
            observed = make_observation(state);
            case (bit_index)
                0: observed.done_pending[0] = 1'b1;
                1: observed.error_pending[1] = 1'b1;
                2: observed.done_enable[0] = 1'b1;
                3: observed.fault_pending = 1'b1;
                4: observed.fault_code = DMA_ERR_INTERNAL;
                5: observed.last_error[1] = DMA_ERR_AXI_WR_SLVERR;
                6: observed.done_count[0] = 32'd1;
                7: observed.error_count[1] = 32'd1;
                8: observed.global_irq = 1'b1;
                default: begin end
            endcase
            mismatches = dma_irq_model_mismatches(state, bus, inputs, observed);
            if (mismatches !== (17'd1 << bit_index)) failures++;
        end
        observed = make_observation(state);
        observed.done_pending[0] = 1'bx;
        mismatches = dma_irq_model_mismatches(state, bus, inputs, observed);
        if (mismatches !== 17'h00001) failures++;
        observed = make_observation(state);
        inputs.manager_fault_valid = 1'b1;
        inputs.manager_fault.error = DMA_ERR_INTERNAL;
        inputs.manager_fault.source = DMA_FAULT_SRC_MANAGER;
        mismatches = dma_irq_model_mismatches(state, bus, inputs, observed);
        if (mismatches !== 17'h10000) failures++;
        observed.combined_fault_valid = 1'b1;
        observed.combined_fault = inputs.manager_fault;
        mismatches = dma_irq_model_mismatches(state, bus, inputs, observed);
        if (mismatches !== '0) failures++;

        inputs.reset_n = 1'b0;
        result = dma_irq_model_step(state, bus, inputs);
        if (result !== '0) failures++;
        return failures;
    endfunction

    localparam int RULE_FAILURES = run_rules();

endpackage

`default_nettype wire
