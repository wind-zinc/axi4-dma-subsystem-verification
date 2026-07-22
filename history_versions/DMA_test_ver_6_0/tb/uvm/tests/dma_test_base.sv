class dma_test_base extends uvm_test;

    `uvm_component_utils(dma_test_base)

    dma_env env;

    function new(string name = "dma_test_base",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dma_env::type_id::create("env", this);
    endfunction

endclass
