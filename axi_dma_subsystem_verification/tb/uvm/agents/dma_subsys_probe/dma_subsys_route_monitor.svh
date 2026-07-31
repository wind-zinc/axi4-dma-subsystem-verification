class dma_subsys_route_monitor extends dma_subsys_probe_monitor_base;
    `uvm_component_utils(dma_subsys_route_monitor)

    uvm_analysis_port #(dma_subsys_route_tr) route_ap;

    protected logic [DMA_CH_COUNT-1:0] previous_request;
    protected bit previous_reset_n;
    protected int unsigned wait_cycles [DMA_CH_COUNT];
    protected bit wait_timeout_reported[DMA_CH_COUNT];
    protected dma_subsys_env_cfg cfg;

    function new(
        string        name   = "dma_subsys_route_monitor",
        uvm_component parent = null
    );
        super.new(name, parent);
        route_ap = new("route_ap", this);
        previous_request = '0;
        previous_reset_n = 1'b0;
        foreach (wait_cycles[channel]) begin
            wait_cycles[channel] = 0;
            wait_timeout_reported[channel] = 1'b0;
        end
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(dma_subsys_env_cfg)::get(
                this, "", "dma_subsys_env_cfg", cfg)) begin
            cfg = dma_subsys_env_cfg::type_id::create("cfg");
        end
    endfunction

    protected function dma_subsys_route_tr make_route_event(
        input dma_route_event_e event_kind,
        input dma_channel_e     source_ch,
        input dma_channel_e     dest_ch,
        input int unsigned      waited = 0
    );
        dma_subsys_route_tr tr;

        tr = dma_subsys_route_tr::type_id::create("route_event");
        tr.record_kind = DMA_RECORD_OBSERVED;
        tr.event_kind = event_kind;
        tr.source_ch = source_ch;
        tr.dest_ch = dest_ch;
        tr.route_active = probe_vif.mon_cb.route_active;
        tr.route_matrix = probe_vif.mon_cb.route_matrix;
        tr.wait_cycles = waited;
        tr.stamp(get_full_name(), cycle_count);
        return tr;
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_route_tr tr;

        forever begin
            sample_tick();

            if (!probe_vif.mon_cb.reset_n) begin
                previous_request = '0;
                previous_reset_n = 1'b0;
                foreach (wait_cycles[channel]) begin
                    wait_cycles[channel] = 0;
                    wait_timeout_reported[channel] = 1'b0;
                end
                continue;
            end

            // A reset-release snapshot proves that all route ownership state
            // returned to idle without inventing a protocol-level release.
            if (!previous_reset_n) begin
                tr = make_route_event(
                    DMA_ROUTE_RELEASED,
                    DMA_CH_UNKNOWN,
                    DMA_CH_UNKNOWN);
                route_ap.write(tr);
            end
            previous_reset_n = 1'b1;

            for (int channel = 0; channel < DMA_CH_COUNT; channel++) begin
                if (probe_vif.mon_cb.route_req_valid[channel]
                        && !previous_request[channel]) begin
                    tr = make_route_event(
                        DMA_ROUTE_REQUEST,
                        dma_channel_from_bit(
                            probe_vif.mon_cb.route_req_src[channel]),
                        dma_channel_from_bit(
                            probe_vif.mon_cb.route_req_dst[channel]));
                    route_ap.write(tr);
                end

                if (probe_vif.mon_cb.route_req_valid[channel]
                        && probe_vif.mon_cb.route_req_ready[channel]) begin
                    tr = make_route_event(
                        DMA_ROUTE_GRANTED,
                        dma_channel_e'(channel),
                        dma_channel_from_bit(
                            probe_vif.mon_cb.route_dest[channel]),
                        wait_cycles[channel]);
                    route_ap.write(tr);
                    wait_cycles[channel] = 0;
                    wait_timeout_reported[channel] = 1'b0;
                end else if (probe_vif.mon_cb.route_req_valid[channel]) begin
                    wait_cycles[channel]++;
                    if (cfg.enable_route_wait_check
                            && !wait_timeout_reported[channel]
                            && (wait_cycles[channel]
                                >= cfg.max_route_wait_cycles)) begin
                        `uvm_error(
                            "ROUTE_PROGRESS",
                            $sformatf(
                                "DMA channel %0d route request waited %0d cycles without a grant",
                                channel, wait_cycles[channel]))
                        wait_timeout_reported[channel] = 1'b1;
                    end
                end

                if (probe_vif.mon_cb.route_release[channel]) begin
                    tr = make_route_event(
                        DMA_ROUTE_RELEASED,
                        dma_channel_e'(channel),
                        dma_channel_from_bit(
                            probe_vif.mon_cb.route_dest[channel]));
                    route_ap.write(tr);
                    wait_cycles[channel] = 0;
                    wait_timeout_reported[channel] = 1'b0;
                end
            end

            if (probe_vif.mon_cb.route_fault_valid) begin
                tr = make_route_event(
                    DMA_ROUTE_FAULT,
                    DMA_CH_UNKNOWN,
                    DMA_CH_UNKNOWN);
                tr.error = probe_vif.mon_cb.route_fault_code;
                tr.fault_source = dma_fault_source_e'(
                    probe_vif.mon_cb.route_fault_source);
                route_ap.write(tr);
            end

            previous_request = probe_vif.mon_cb.route_req_valid;
        end
    endtask

endclass
