class dma_sva_activation_test extends dma_mem_test_base;

    `uvm_component_utils(dma_sva_activation_test)

    virtual dma_sva_ctrl_if sva_ctrl_vif;
    virtual dma_reset_if reset_vif;

    function new(string name = "dma_sva_activation_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_sva_ctrl_if)::get(
                this, "", "sva_ctrl_vif", sva_ctrl_vif))
            `uvm_fatal("NO_SVA_CTRL_VIF",
                "dma_sva_activation_test did not receive dma_sva_ctrl_if")
        if (!uvm_config_db#(virtual dma_reset_if)::get(
                this, "", "reset_vif", reset_vif))
            `uvm_fatal("NO_RESET_VIF",
                "dma_sva_activation_test did not receive dma_reset_if")
    endfunction

    task run_phase(uvm_phase phase);
        dma_sva_activation_seq seq;

        phase.raise_objection(this);
        seq = dma_sva_activation_seq::type_id::create("seq");
        seq.mem_vif = mem_vif;
        seq.sva_ctrl_vif = sva_ctrl_vif;
        seq.reset_vif = reset_vif;
        seq.start(env.axil_agt.sqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
