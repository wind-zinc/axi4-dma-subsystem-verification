class dma_outstanding_test extends dma_mem_test_base;

    `uvm_component_utils(dma_outstanding_test)

    function new(string name = "dma_outstanding_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_config_db#(bit)::set(
            this, "env.outstanding_mon", "require_read_multiple", 1'b1);
        uvm_config_db#(bit)::set(
            this, "env.outstanding_mon", "require_write_multiple", 1'b1);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        dma_outstanding_seq seq;
        phase.raise_objection(this);
        seq = dma_outstanding_seq::type_id::create("seq");
        seq.ral = env.ral;
        seq.mem_vif = mem_vif;
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
