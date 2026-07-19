class dma_random_smoke_test extends uvm_test;

    `uvm_component_utils(dma_random_smoke_test)

    dma_env env;

    function new(string name = "dma_random_smoke_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dma_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        dma_random_smoke_seq seq;

        phase.raise_objection(this);

        seq = dma_random_smoke_seq::type_id::create("seq");
        if (!seq.randomize())
            `uvm_fatal("SEQ_RANDOMIZE",
                "dma_random_smoke_seq randomization failed")

        seq.start(env.axil_agt.sqr);
        #100ns;

        phase.drop_objection(this);
    endtask

endclass
