`timescale 1ns / 1ps

class dma_subsys_irq_state_checker extends dma_subsys_probe_monitor_base;
    `uvm_component_utils(dma_subsys_irq_state_checker)

    protected dma_irq_model_state_t expected_state;
    protected bit initialized;
    protected longint unsigned checked_cycles;

    function new(
        string name = "dma_subsys_irq_state_checker",
        uvm_component parent = null
    );
        super.new(name, parent);
        expected_state = dma_irq_model_reset();
        initialized = 1'b0;
        checked_cycles = 0;
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_irq_bus_sample_t bus;
        dma_irq_input_sample_t inputs;
        dma_irq_observed_t observed;
        logic [16:0] mismatches;
        bit invalid_inputs;

        forever begin
            sample_tick();
            bus = probe_vif.mon_cb.irq_bus;
            inputs = probe_vif.mon_cb.irq_inputs;
            observed = probe_vif.mon_cb.irq_observed;

            if (!initialized) begin
                if (inputs.reset_n === 1'b0) begin
                    expected_state = dma_irq_model_reset();
                    initialized = 1'b1;
                end
                continue;
            end

            if ($isunknown(inputs.reset_n)) begin
                `uvm_error("IRQ_MODEL_RESET", "IRQ model observed an unknown reset")
                continue;
            end

            invalid_inputs = $isunknown({
                    inputs.completion_valid, inputs.manager_fault_valid,
                    inputs.route_fault_valid, inputs.busy,
                    inputs.route_active, inputs.route_matrix,
                    bus.awvalid, bus.wvalid, bus.arvalid,
                    bus.bready, bus.rready});
            foreach (inputs.completion_valid[channel]) begin
                if (inputs.completion_valid[channel]) begin
                    invalid_inputs |= $isunknown(inputs.completion_error[channel]);
                end
            end
            if (inputs.manager_fault_valid) begin
                invalid_inputs |= $isunknown(inputs.manager_fault);
            end
            if (inputs.route_fault_valid) begin
                invalid_inputs |= $isunknown(inputs.route_fault);
            end
            if (bus.awvalid) invalid_inputs |= $isunknown(bus.awaddr);
            if (bus.wvalid) invalid_inputs |= $isunknown({bus.wdata, bus.wstrb});
            if (bus.arvalid) invalid_inputs |= $isunknown(bus.araddr);
            if (inputs.reset_n && invalid_inputs) begin
                `uvm_error("IRQ_MODEL_INPUT", "IRQ model observed unknown controls or active payloads")
            end

            mismatches = dma_irq_model_mismatches(
                expected_state, bus, inputs, observed);
            if (mismatches != '0) begin
                `uvm_error("IRQ_MODEL_MISMATCH",
                    $sformatf(
                        "cycle=%0d mismatch_mask=0x%05h expected=%p observed=%p bus=%p",
                        cycle_count, mismatches, expected_state, observed, bus))
            end
            checked_cycles++;
            expected_state = dma_irq_model_step(expected_state, bus, inputs);
        end
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (!initialized || checked_cycles == 0) begin
            `uvm_error("IRQ_MODEL_INACTIVE", "IRQ state checker did not check any cycles")
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("IRQ_MODEL_SUMMARY",
            $sformatf("checked_cycles=%0d", checked_cycles), UVM_LOW)
    endfunction

endclass
