class dma_subsys_cmd_monitor extends dma_subsys_probe_monitor_base;
    `uvm_component_utils(dma_subsys_cmd_monitor)

    uvm_analysis_port #(dma_subsys_cmd_tr) cmd_ap;

    function new(
        string        name   = "dma_subsys_cmd_monitor",
        uvm_component parent = null
    );
        super.new(name, parent);
        cmd_ap = new("cmd_ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_cmd_tr tr;

        forever begin
            sample_tick();
            if (!probe_vif.mon_cb.reset_n) begin
                continue;
            end

            for (int channel = 0; channel < DMA_CH_COUNT; channel++) begin
                if (probe_vif.mon_cb.cmd_valid[channel]
                        && probe_vif.mon_cb.cmd_ready[channel]) begin
                    tr = dma_subsys_cmd_tr::type_id::create(
                        $sformatf("accepted_cmd_ch%0d", channel));
                    tr.record_kind = DMA_RECORD_OBSERVED;
                    tr.from_rtl_cmd(
                        probe_vif.mon_cb.cmd_payload[channel],
                        DMA_CMD_ACCEPTED);
                    tr.hw_tag =
                        probe_vif.mon_cb.accepted_hw_tag[channel];
                    tr.hw_tag_valid = 1'b1;
                    tr.ensure_flow_id();
                    tr.stamp(get_full_name(), cycle_count);
                    cmd_ap.write(tr);
                end
            end
        end
    endtask

endclass
