class dma_subsys_virtual_sequencer extends uvm_sequencer #(
    uvm_sequence_item
);
    `uvm_component_utils(dma_subsys_virtual_sequencer)

    dma_subsys_vip_manager vip_mgr;
    dma_subsys_axil_sequencer axil_sequencer;
    dma_subsys_reg_block ral;
    dma_subsys_env_cfg cfg;
    virtual dma_subsys_probe_if probe_vif;
    uvm_analysis_port #(dma_subsys_cmd_tr) intent_ap;

    function new(
        string        name   = "dma_subsys_virtual_sequencer",
        uvm_component parent = null
    );
        super.new(name, parent);
        intent_ap = new("intent_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_subsys_probe_if)::get(
                this, "", "dma_subsys_probe_vif", probe_vif)) begin
            `uvm_fatal(
                "VSEQR_PROBE_VIF",
                "Virtual sequencer did not receive dma_subsys_probe_vif")
        end
    endfunction

    virtual function void publish_intent(input dma_subsys_cmd_tr tr);
        dma_subsys_cmd_tr copy;

        copy = dma_subsys_cmd_tr::type_id::create("published_intent");
        copy.copy(tr);
        copy.record_kind = DMA_RECORD_INTENT;
        copy.ensure_flow_id();
        copy.stamp(get_full_name());
        intent_ap.write(copy);
    endfunction

endclass
