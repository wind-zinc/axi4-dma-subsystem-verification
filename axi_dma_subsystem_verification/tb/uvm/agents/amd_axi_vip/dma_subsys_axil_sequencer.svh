class dma_subsys_axil_sequencer extends uvm_sequencer #(
    dma_subsys_reg_tr
);
    `uvm_component_utils(dma_subsys_axil_sequencer)

    function new(
        string        name   = "dma_subsys_axil_sequencer",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

endclass
