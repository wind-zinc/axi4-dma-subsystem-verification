class dma_length_sweep_test extends dma_test_base;

    `uvm_component_utils(dma_length_sweep_test)

    function new(string name = "dma_length_sweep_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_length_sweep_seq seq;
        phase.raise_objection(this);
        seq = dma_length_sweep_seq::type_id::create("seq");
        seq.start(env.axil_agt.sqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
