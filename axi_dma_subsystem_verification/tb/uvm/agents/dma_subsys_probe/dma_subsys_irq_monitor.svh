class dma_subsys_irq_monitor extends dma_subsys_probe_monitor_base;
    `uvm_component_utils(dma_subsys_irq_monitor)

    uvm_analysis_port #(dma_subsys_completion_tr) completion_ap;
    uvm_analysis_port #(dma_subsys_irq_tr)        irq_ap;
    uvm_analysis_port #(dma_subsys_fault_tr)      fault_ap;
    uvm_analysis_port #(dma_subsys_reset_tr)      reset_ap;

    protected bit initialized;
    protected bit previous_reset_n;
    protected int unsigned reset_epoch;
    protected logic [DMA_CH_COUNT-1:0] previous_irq_ch;
    protected bit previous_global_irq;
    protected logic [DMA_CH_COUNT-1:0] previous_done_pending;
    protected logic [DMA_CH_COUNT-1:0] previous_error_pending;
    protected logic [DMA_CH_COUNT-1:0] previous_busy;
    protected logic [DMA_CH_COUNT-1:0] previous_done_enable;
    protected logic [DMA_CH_COUNT-1:0] previous_error_enable;
    protected bit previous_fault_pending;
    protected bit previous_fault_enable;
    protected dma_error_e previous_fault_code;
    protected logic [2:0] previous_fault_source;

    function new(
        string        name   = "dma_subsys_irq_monitor",
        uvm_component parent = null
    );
        super.new(name, parent);
        completion_ap = new("completion_ap", this);
        irq_ap = new("irq_ap", this);
        fault_ap = new("fault_ap", this);
        reset_ap = new("reset_ap", this);
        initialized = 1'b0;
        previous_reset_n = 1'b0;
        reset_epoch = 0;
    endfunction

    protected function void publish_reset(input bit reset_n);
        dma_subsys_reset_tr tr;

        if (!reset_n) begin
            reset_epoch++;
        end
        tr = dma_subsys_reset_tr::type_id::create("reset_event");
        tr.record_kind = DMA_RECORD_OBSERVED;
        tr.event_kind = reset_n
            ? DMA_RESET_DEASSERTED : DMA_RESET_ASSERTED;
        tr.reset_n = reset_n;
        tr.reset_epoch = reset_epoch;
        tr.reason = reset_n ? "subsystem reset released"
                            : "subsystem reset asserted";
        tr.stamp(get_full_name(), cycle_count);
        reset_ap.write(tr);
    endfunction

    protected function void publish_irq_snapshot(
        input dma_irq_event_e event_kind
    );
        dma_subsys_irq_tr tr;

        tr = dma_subsys_irq_tr::type_id::create("irq_snapshot");
        tr.record_kind = DMA_RECORD_OBSERVED;
        tr.event_kind = event_kind;
        tr.irq_ch = probe_vif.mon_cb.irq_ch;
        tr.global_irq = probe_vif.mon_cb.global_irq;
        tr.done_pending = probe_vif.mon_cb.done_pending;
        tr.error_pending = probe_vif.mon_cb.error_pending;
        tr.busy = probe_vif.mon_cb.busy;
        tr.done_enable = probe_vif.mon_cb.done_enable;
        tr.error_enable = probe_vif.mon_cb.error_enable;
        tr.fault_pending = probe_vif.mon_cb.fault_pending;
        tr.fault_enable = probe_vif.mon_cb.fault_enable;
        tr.fault_code = probe_vif.mon_cb.fault_code;
        tr.fault_source = dma_fault_source_e'(
            probe_vif.mon_cb.fault_source);
        tr.stamp(get_full_name(), cycle_count);
        irq_ap.write(tr);
    endfunction

    protected function bit irq_state_changed();
        return (previous_irq_ch       != probe_vif.mon_cb.irq_ch)
            || (previous_global_irq   != probe_vif.mon_cb.global_irq)
            || (previous_done_pending != probe_vif.mon_cb.done_pending)
            || (previous_error_pending != probe_vif.mon_cb.error_pending)
            || (previous_busy         != probe_vif.mon_cb.busy)
            || (previous_done_enable  != probe_vif.mon_cb.done_enable)
            || (previous_error_enable != probe_vif.mon_cb.error_enable)
            || (previous_fault_pending != probe_vif.mon_cb.fault_pending)
            || (previous_fault_enable != probe_vif.mon_cb.fault_enable)
            || (previous_fault_code   != probe_vif.mon_cb.fault_code)
            || (previous_fault_source != probe_vif.mon_cb.fault_source);
    endfunction

    protected function void remember_irq_state();
        previous_irq_ch = probe_vif.mon_cb.irq_ch;
        previous_global_irq = probe_vif.mon_cb.global_irq;
        previous_done_pending = probe_vif.mon_cb.done_pending;
        previous_error_pending = probe_vif.mon_cb.error_pending;
        previous_busy = probe_vif.mon_cb.busy;
        previous_done_enable = probe_vif.mon_cb.done_enable;
        previous_error_enable = probe_vif.mon_cb.error_enable;
        previous_fault_pending = probe_vif.mon_cb.fault_pending;
        previous_fault_enable = probe_vif.mon_cb.fault_enable;
        previous_fault_code = probe_vif.mon_cb.fault_code;
        previous_fault_source = probe_vif.mon_cb.fault_source;
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_completion_tr completion_tr;
        dma_subsys_fault_tr fault_tr;
        dma_irq_event_e irq_event;
        bit reset_released;

        forever begin
            sample_tick();

            reset_released = initialized
                && !previous_reset_n
                && probe_vif.mon_cb.reset_n;
            if (!initialized || (previous_reset_n
                    != probe_vif.mon_cb.reset_n)) begin
                publish_reset(probe_vif.mon_cb.reset_n);
            end
            initialized = 1'b1;
            previous_reset_n = probe_vif.mon_cb.reset_n;

            if (!probe_vif.mon_cb.reset_n) begin
                remember_irq_state();
                continue;
            end

            for (int channel = 0; channel < DMA_CH_COUNT; channel++) begin
                if (probe_vif.mon_cb.completion_valid[channel]) begin
                    completion_tr =
                        dma_subsys_completion_tr::type_id::create(
                            $sformatf("completion_ch%0d", channel));
                    completion_tr.record_kind = DMA_RECORD_OBSERVED;
                    completion_tr.from_rtl_completion(
                        probe_vif.mon_cb.completion[channel]);
                    completion_tr.stamp(get_full_name(), cycle_count);
                    completion_ap.write(completion_tr);
                end
            end

            if (probe_vif.mon_cb.combined_fault_valid) begin
                fault_tr = dma_subsys_fault_tr::type_id::create(
                    "combined_fault");
                fault_tr.record_kind = DMA_RECORD_OBSERVED;
                fault_tr.from_rtl_fault(probe_vif.mon_cb.combined_fault);
                fault_tr.event_kind = DMA_FAULT_RAISED;
                fault_tr.enabled = probe_vif.mon_cb.fault_enable;
                fault_tr.stamp(get_full_name(), cycle_count);
                fault_ap.write(fault_tr);
            end

            if (reset_released || irq_state_changed()) begin
                if (!previous_global_irq
                        && probe_vif.mon_cb.global_irq) begin
                    irq_event = DMA_IRQ_ASSERTED;
                end else if (previous_global_irq
                        && !probe_vif.mon_cb.global_irq) begin
                    irq_event = DMA_IRQ_DEASSERTED;
                end else begin
                    irq_event = DMA_IRQ_STATUS_SAMPLED;
                end
                publish_irq_snapshot(irq_event);
            end

            remember_irq_state();
        end
    endtask

endclass
