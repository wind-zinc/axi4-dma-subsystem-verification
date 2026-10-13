`timescale 1ns / 1ps
`default_nettype none

module tb_dma_irq_model;
    import dma_subsystem_pkg::*;
    import dma_subsys_irq_model_pkg::*;
    import dma_irq_model_rules_pkg::*;

    logic clk = 1'b0;
    dma_irq_bus_sample_t bus;
    dma_irq_input_sample_t inputs;
    dma_irq_observed_t observed;
    dma_irq_model_state_t expected_state;
    dma_completion_t completion [DMA_CH_COUNT-1:0];
    logic initialized = 1'b0;
    longint unsigned checked_cycles = 0;
    int seed = 17;
    bit background_enabled;
    string mutation;

    always #5 clk = !clk;

    assign observed.done_pending = dut.done_pending_reg;
    assign observed.error_pending = dut.error_pending_reg;
    assign observed.done_enable = dut.done_enable_reg;
    assign observed.error_enable = dut.error_enable_reg;
    assign observed.fault_pending = dut.fault_pending_reg;
    assign observed.fault_enable = dut.fault_enable_reg;
    assign observed.fault_code = dut.fault_code_reg;
    assign observed.fault_source = dut.fault_source_reg;
    assign observed.combined_fault_valid =
        inputs.manager_fault_valid || inputs.route_fault_valid;
    assign observed.combined_fault = inputs.manager_fault_valid
        ? inputs.manager_fault : inputs.route_fault;

    for (genvar channel = 0; channel < DMA_CH_COUNT; channel++) begin : g_samples
        assign completion[channel] = {
            1'b0, {TAG_WIDTH{1'b0}}, 8'd0, {LEN_WIDTH{1'b0}},
            inputs.completion_error[channel], 1'b0};
        assign observed.last_error[channel] = dut.last_error_reg[channel];
        assign observed.done_count[channel] = dut.done_count_reg[channel];
        assign observed.error_count[channel] = dut.error_count_reg[channel];
    end

    dma_irq_status_ctrl dut (
        .clk(clk), .rst(!inputs.reset_n),
        .s_axil_awaddr(bus.awaddr), .s_axil_awprot(3'd0),
        .s_axil_awvalid(bus.awvalid), .s_axil_awready(bus.awready),
        .s_axil_wdata(bus.wdata), .s_axil_wstrb(bus.wstrb),
        .s_axil_wvalid(bus.wvalid), .s_axil_wready(bus.wready),
        .s_axil_bresp(bus.bresp), .s_axil_bvalid(bus.bvalid),
        .s_axil_bready(bus.bready),
        .s_axil_araddr(bus.araddr), .s_axil_arprot(3'd0),
        .s_axil_arvalid(bus.arvalid), .s_axil_arready(bus.arready),
        .s_axil_rdata(bus.rdata), .s_axil_rresp(bus.rresp),
        .s_axil_rvalid(bus.rvalid), .s_axil_rready(bus.rready),
        .completion_valid(inputs.completion_valid), .completion(completion),
        .busy(inputs.busy), .route_matrix(inputs.route_matrix),
        .route_active(inputs.route_active),
        .fault_valid(observed.combined_fault_valid),
        .fault(observed.combined_fault),
        .irq_ch(observed.irq_ch), .irq(observed.global_irq)
    );

    always @(posedge clk) begin : check_cycle
        logic [16:0] mismatches;

        if (!initialized) begin
            if (inputs.reset_n === 1'b0) begin
                initialized = 1'b1;
                expected_state = dma_irq_model_reset();
            end
        end else begin
            mismatches = dma_irq_model_mismatches(
                expected_state, bus, inputs, observed);
            if (mismatches != '0) begin
                $fatal(1,
                    "[IRQ_MODEL_MISMATCH] cycle=%0d mask=0x%05h expected=%p observed=%p bus=%p",
                    checked_cycles, mismatches, expected_state, observed, bus);
            end
            checked_cycles++;
            expected_state = dma_irq_model_step(expected_state, bus, inputs);
        end
    end

    task automatic wait_cycles(input int unsigned count);
        repeat (count) @(negedge clk);
    endtask

    task automatic reset_controller();
        @(negedge clk);
        inputs = '0;
        bus.awvalid = 1'b0;
        bus.wvalid = 1'b0;
        bus.arvalid = 1'b0;
        bus.bready = 1'b1;
        bus.rready = 1'b1;
        wait_cycles(3);
        inputs.reset_n = 1'b1;
        wait_cycles(2);
    endtask

    task automatic send_aw(input logic [11:0] address);
        @(negedge clk);
        bus.awaddr = address;
        bus.awvalid = 1'b1;
        do @(posedge clk); while (!bus.awready);
        @(negedge clk);
        bus.awvalid = 1'b0;
    endtask

    task automatic send_w(input logic [31:0] data, input logic [3:0] strobe);
        @(negedge clk);
        bus.wdata = data;
        bus.wstrb = strobe;
        bus.wvalid = 1'b1;
        do @(posedge clk); while (!bus.wready);
        @(negedge clk);
        bus.wvalid = 1'b0;
    endtask

    task automatic send_ar(input logic [11:0] address);
        @(negedge clk);
        bus.araddr = address;
        bus.arvalid = 1'b1;
        do @(posedge clk); while (!bus.arready);
        @(negedge clk);
        bus.arvalid = 1'b0;
    endtask

    task automatic write_register(
        input logic [11:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input int unsigned order = 0,
        input int unsigned response_stall = 0
    );
        @(negedge clk);
        bus.bready = 1'b0;
        fork
            begin
                if (order == 2) wait_cycles(3);
                send_aw(address);
            end
            begin
                if (order == 1) wait_cycles(3);
                send_w(data, strobe);
            end
        join
        while (!bus.bvalid) @(negedge clk);
        wait_cycles(response_stall);
        bus.bready = 1'b1;
        @(negedge clk);
    endtask

    task automatic read_register(
        input logic [11:0] address,
        input int unsigned response_stall = 0
    );
        @(negedge clk);
        bus.rready = 1'b0;
        send_ar(address);
        while (!bus.rvalid) @(negedge clk);
        wait_cycles(response_stall);
        bus.rready = 1'b1;
        @(negedge clk);
    endtask

    task automatic pulse_events(
        input logic [1:0] valid,
        input dma_error_e error0,
        input dma_error_e error1,
        input bit raise_fault = 1'b0
    );
        @(negedge clk);
        inputs.completion_valid = valid;
        inputs.completion_error[0] = error0;
        inputs.completion_error[1] = error1;
        inputs.manager_fault_valid = raise_fault;
        inputs.manager_fault.error = DMA_ERR_INTERNAL;
        inputs.manager_fault.source = DMA_FAULT_SRC_MANAGER;
        @(negedge clk);
        inputs.completion_valid = '0;
        inputs.manager_fault_valid = 1'b0;
        wait_cycles(1);
    endtask

    task automatic expect_pending(
        input logic [1:0] done,
        input logic [1:0] error,
        input bit fault_pending
    );
        if ({observed.done_pending, observed.error_pending, observed.fault_pending}
                !== {done, error, fault_pending}) begin
            $fatal(1, "[IRQ_TEST_EXPECT] incorrect pending state");
        end
    endtask

    task automatic simultaneous_clear_and_events();
        fork
            send_aw(REG_IRQ_CLEAR);
            send_w(32'h4000_0303, 4'hF);
        join
        inputs.completion_valid = 2'b11;
        inputs.completion_error[0] = DMA_ERR_NONE;
        inputs.completion_error[1] = DMA_ERR_AXI_WR_DECERR;
        inputs.manager_fault_valid = 1'b1;
        inputs.manager_fault.error = DMA_ERR_INTERNAL;
        inputs.manager_fault.source = DMA_FAULT_SRC_MANAGER;
        inputs.route_fault_valid = 1'b1;
        inputs.route_fault.error = DMA_ERR_ROUTE_CONFLICT;
        inputs.route_fault.source = DMA_FAULT_SRC_ROUTE;
        @(negedge clk);
        inputs.completion_valid = '0;
        inputs.manager_fault_valid = 1'b0;
        inputs.route_fault_valid = 1'b0;
        wait_cycles(2);
        expect_pending(2'b11, 2'b10, 1'b1);
        if ({observed.fault_code, observed.fault_source}
                !== {DMA_ERR_INTERNAL, DMA_FAULT_SRC_MANAGER}) begin
            $fatal(1, "[IRQ_TEST_EXPECT] manager fault priority was lost");
        end
    endtask

    task automatic random_events();
        while (background_enabled) begin
            @(negedge clk);
            if (!background_enabled) break;
            inputs.completion_valid = 2'($urandom_range(0, 3));
            inputs.completion_error[0] = ($urandom_range(0, 1) != 0)
                ? DMA_ERR_NONE : DMA_ERR_AXI_RD_SLVERR;
            inputs.completion_error[1] = ($urandom_range(0, 1) != 0)
                ? DMA_ERR_NONE : DMA_ERR_AXI_WR_DECERR;
            inputs.manager_fault_valid = ($urandom_range(0, 7) == 0);
            inputs.manager_fault.error = DMA_ERR_UNEXPECTED_STATUS;
            inputs.manager_fault.source = 3'($urandom_range(0, 3));
            inputs.route_fault_valid = ($urandom_range(0, 7) == 0);
            inputs.route_fault.error = DMA_ERR_ROUTE_CONFLICT;
            inputs.route_fault.source = DMA_FAULT_SRC_ROUTE;
            inputs.busy = 2'($urandom_range(0, 3));
            inputs.route_active = 2'($urandom_range(0, 3));
            inputs.route_matrix = 4'($urandom_range(0, 15));
        end
    endtask

    task automatic inject_mutation();
        case (mutation)
            "drop_done": begin
                pulse_events(2'b01, DMA_ERR_NONE, DMA_ERR_NONE);
                force dut.done_pending_reg = 2'b00;
            end
            "drop_enable": begin
                write_register(REG_IRQ_ENABLE, 32'h4000_0303, 4'hF);
                force dut.done_enable_reg = 2'b00;
            end
            "fault_code": begin
                pulse_events(2'b00, DMA_ERR_NONE, DMA_ERR_NONE, 1'b1);
                force dut.fault_code_reg = DMA_ERR_NONE;
            end
            "read_data": begin
                bus.rready = 1'b0;
                send_ar(REG_GLOBAL_VERSION);
                while (!bus.rvalid) @(negedge clk);
                force dut.s_axil_rdata = 32'd0;
            end
            "write_response": begin
                bus.bready = 1'b0;
                fork
                    send_aw(REG_IRQ_STATUS);
                    send_w(32'hFFFF_FFFF, 4'hF);
                join
                while (!bus.bvalid) @(negedge clk);
                force dut.s_axil_bresp = 2'b00;
            end
            default: $fatal(1, "[IRQ_TEST_CONFIG] unknown mutation %s", mutation);
        endcase
        wait_cycles(4);
        $fatal(1, "[IRQ_MUTATION_MISSED] %s", mutation);
    endtask

    initial begin : stimulus
        if (RULE_FAILURES != 0) $fatal(1, "[IRQ_RULE_FAILURE] count=%0d", RULE_FAILURES);
        void'($value$plusargs("SEED=%d", seed));
        void'($value$plusargs("MUTATION=%s", mutation));
        void'($urandom(seed));
        inputs = '0;
        bus.awaddr = '0;
        bus.awvalid = 1'b0;
        bus.wdata = '0;
        bus.wstrb = '0;
        bus.wvalid = 1'b0;
        bus.bready = 1'b1;
        bus.araddr = '0;
        bus.arvalid = 1'b0;
        bus.rready = 1'b1;
        reset_controller();

        write_register(REG_IRQ_ENABLE, 32'h4000_0303, 4'hF, 1, 3);
        write_register(REG_IRQ_ENABLE, 32'd0, 4'h0, 2, 2);
        pulse_events(2'b11, DMA_ERR_NONE, DMA_ERR_AXI_RD_SLVERR, 1'b1);
        expect_pending(2'b11, 2'b10, 1'b1);
        write_register(REG_IRQ_ENABLE, 32'd0, 4'hF);
        expect_pending(2'b11, 2'b10, 1'b1);
        if (observed.global_irq !== 1'b0) $fatal(1, "[IRQ_TEST_EXPECT] masked IRQ");
        write_register(REG_IRQ_CLEAR, 32'h4000_0303, 4'h0);
        expect_pending(2'b11, 2'b10, 1'b1);
        write_register(REG_IRQ_CLEAR, 32'h4000_0303, 4'h1);
        expect_pending(2'b00, 2'b10, 1'b1);
        write_register(REG_IRQ_CLEAR, 32'h4000_0303, 4'h2);
        expect_pending(2'b00, 2'b00, 1'b1);
        write_register(REG_IRQ_CLEAR, 32'h4000_0303, 4'h8);
        expect_pending(2'b00, 2'b00, 1'b0);
        simultaneous_clear_and_events();
        read_register(REG_FAULT_STATUS, 4);
        read_register(REG_IRQ_CLEAR, 2);
        read_register(12'hFFC, 2);
        write_register(REG_GLOBAL_VERSION, 32'd0, 4'hF);
        write_register(12'hFFC, 32'hFFFF_FFFF, 4'hF);

        reset_controller();
        bus.rready = 1'b0;
        send_ar(REG_IRQ_STATUS);
        pulse_events(2'b01, DMA_ERR_NONE, DMA_ERR_NONE);
        wait_cycles(3);
        bus.rready = 1'b1;
        wait_cycles(2);
        read_register(REG_IRQ_STATUS);
        send_aw(REG_IRQ_ENABLE);
        reset_controller();
        write_register(REG_IRQ_ENABLE, 32'h4000_0303, 4'hF);

        @(negedge clk);
        force dut.done_count_reg[0] = 32'hFFFF_FFFE;
        force dut.error_count_reg[0] = 32'hFFFF_FFFE;
        #1;
        release dut.done_count_reg[0];
        release dut.error_count_reg[0];
        expected_state.done_count[0] = 32'hFFFF_FFFE;
        expected_state.error_count[0] = 32'hFFFF_FFFE;
        pulse_events(2'b01, DMA_ERR_AXI_RD_SLVERR, DMA_ERR_NONE);
        pulse_events(2'b01, DMA_ERR_AXI_RD_SLVERR, DMA_ERR_NONE);
        if ({observed.done_count[0], observed.error_count[0]}
                !== {32'hFFFF_FFFF, 32'hFFFF_FFFF}) begin
            $fatal(1, "[IRQ_TEST_EXPECT] counters did not saturate");
        end
        reset_controller();

        background_enabled = 1'b1;
        fork
            random_events();
            begin
                for (int index = 0; index < 200; index++) begin
                    if ($urandom_range(0, 1) != 0) begin
                        write_register(($urandom_range(0, 1) != 0)
                            ? REG_IRQ_ENABLE : REG_IRQ_CLEAR,
                            $urandom(), 4'($urandom_range(0, 15)),
                            $urandom_range(0, 2), $urandom_range(0, 5));
                    end else begin
                        read_register(12'(4 * $urandom_range(0, 11)),
                            $urandom_range(0, 5));
                    end
                end
                background_enabled = 1'b0;
            end
        join
        inputs.completion_valid = '0;
        inputs.manager_fault_valid = 1'b0;
        inputs.route_fault_valid = 1'b0;
        wait_cycles(3);
        for (int unsigned index = 0; index <= 10; index++) begin
            read_register(12'(4 * index));
        end

        if (mutation != "") inject_mutation();
        wait_cycles(3);
        $display("[IRQ_MODEL_PASS] checked_cycles=%0d", checked_cycles);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "[IRQ_TEST_TIMEOUT]");
    end

endmodule

`default_nettype wire
