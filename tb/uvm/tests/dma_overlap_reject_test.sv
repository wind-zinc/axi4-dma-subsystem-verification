class dma_overlap_reject_test extends dma_test_base;

    `uvm_component_utils(dma_overlap_reject_test)

    function new(string name = "dma_overlap_reject_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_overlap_reject_seq seq;
        phase.raise_objection(this);
        seq = dma_overlap_reject_seq::type_id::create("seq");
        seq.ral = env.ral;
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
