/* Test base that retrieves the verification-only AXI memory controls. */
class dma_mem_test_base extends dma_test_base;

    `uvm_component_utils(dma_mem_test_base)

    virtual dma_mem_ctrl_if mem_vif;

    function new(string name = "dma_mem_test_base",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_mem_ctrl_if)::get(
                this, "", "mem_ctrl_vif", mem_vif))
            `uvm_fatal("NO_MEM_CTRL_VIF",
                "dma_mem_test_base did not receive dma_mem_ctrl_if")
    endfunction

endclass

