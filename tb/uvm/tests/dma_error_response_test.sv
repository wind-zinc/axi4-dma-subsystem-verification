class dma_error_test_base extends dma_mem_test_base;

    `uvm_component_utils(dma_error_test_base)

    function new(string name = "dma_error_test_base",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function dma_error_mode_e get_error_mode();
        return DMA_READ_SLVERR;
    endfunction

    task run_phase(uvm_phase phase);
        dma_error_response_seq seq;
        phase.raise_objection(this);
        seq = dma_error_response_seq::type_id::create("seq");
        seq.ral = env.ral;
        seq.mem_vif = mem_vif;
        seq.mode = get_error_mode();
        seq.start(null);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass

class dma_read_slverr_test extends dma_error_test_base;
    `uvm_component_utils(dma_read_slverr_test)
    function new(string name = "dma_read_slverr_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function dma_error_mode_e get_error_mode();
        return DMA_READ_SLVERR;
    endfunction
endclass

class dma_read_decerr_test extends dma_error_test_base;
    `uvm_component_utils(dma_read_decerr_test)
    function new(string name = "dma_read_decerr_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function dma_error_mode_e get_error_mode();
        return DMA_READ_DECERR;
    endfunction
endclass

class dma_write_slverr_test extends dma_error_test_base;
    `uvm_component_utils(dma_write_slverr_test)
    function new(string name = "dma_write_slverr_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function dma_error_mode_e get_error_mode();
        return DMA_WRITE_SLVERR;
    endfunction
endclass

class dma_write_decerr_test extends dma_error_test_base;
    `uvm_component_utils(dma_write_decerr_test)
    function new(string name = "dma_write_decerr_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function dma_error_mode_e get_error_mode();
        return DMA_WRITE_DECERR;
    endfunction
endclass

