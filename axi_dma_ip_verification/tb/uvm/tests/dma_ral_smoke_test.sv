class dma_ral_smoke_test extends dma_test_base;

    `uvm_component_utils(dma_ral_smoke_test)

    function new(string name = "dma_ral_smoke_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_ral_smoke_seq seq;

        phase.raise_objection(this);
        seq = dma_ral_smoke_seq::type_id::create("seq");
        seq.ral = env.ral;
        if (!seq.randomize())
            `uvm_fatal("RAL_SEQ_RANDOMIZE", "RAL sequence randomization failed")
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
