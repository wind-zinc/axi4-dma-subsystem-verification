/* RAL sequence base for tests that also control the AXI memory proxy. */
class dma_mem_ral_base_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_mem_ral_base_seq)

    virtual dma_mem_ctrl_if mem_vif;

    function new(string name = "dma_mem_ral_base_seq");
        super.new(name);
    endfunction

    virtual function void require_mem_vif();
        if (mem_vif == null)
            `uvm_fatal("NO_MEM_VIF",
                "memory-control virtual interface was not assigned")
    endfunction

endclass

