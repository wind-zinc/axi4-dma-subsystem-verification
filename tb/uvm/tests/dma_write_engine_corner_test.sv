class dma_write_engine_corner_test extends dma_mem_test_base;

    `uvm_component_utils(dma_write_engine_corner_test)

    virtual dma_reset_if reset_vif;

    function new(string name = "dma_write_engine_corner_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_reset_if)::get(
                this, "", "reset_vif", reset_vif))
            `uvm_fatal("NO_RESET_VIF",
                "dma_write_engine_corner_test did not receive dma_reset_if")
    endfunction

    task run_phase(uvm_phase phase);
        dma_write_engine_corner_seq seq;

        phase.raise_objection(this);
        seq = dma_write_engine_corner_seq::type_id::create("seq");
        seq.ral = env.ral;
        seq.mem_vif = mem_vif;
        seq.reset_vif = reset_vif;
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
