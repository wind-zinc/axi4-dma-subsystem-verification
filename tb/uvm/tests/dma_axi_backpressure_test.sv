class dma_axi_backpressure_test extends dma_mem_test_base;

    `uvm_component_utils(dma_axi_backpressure_test)

    function new(string name = "dma_axi_backpressure_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_axi_backpressure_seq seq;
        phase.raise_objection(this);
        seq = dma_axi_backpressure_seq::type_id::create("seq");
        seq.ral = env.ral;
        seq.mem_vif = mem_vif;
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass

