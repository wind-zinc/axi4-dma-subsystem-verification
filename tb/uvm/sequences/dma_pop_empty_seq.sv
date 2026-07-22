/* Exercises the software error path for popping an empty completion FIFO. */
class dma_pop_empty_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_pop_empty_seq)

    function new(string name = "dma_pop_empty_seq");
        super.new(name);
    endfunction

    virtual task body();
        uvm_reg_data_t value;

        ral_write(ral.control, 32'h0000_0003);
        ral_read(ral.status, value);
        if (value[4])
            `uvm_fatal("POP_EMPTY_SETUP", "completion FIFO is not empty")

        ral_pop_completion();
        ral_read(ral.status, value);
        if (!value[10] || value[4] || value[6])
            `uvm_error("POP_EMPTY",
                $sformatf("unexpected status after empty pop: 0x%08h", value))

        ral_write(ral.control, 32'h0000_0003);
        ral_read(ral.status, value);
        if (value[10])
            `uvm_error("POP_EMPTY_CLEAR",
                $sformatf("pop_empty sticky did not clear: 0x%08h", value))

        `uvm_info("DMA_POP_EMPTY", "empty completion pop completed", UVM_LOW)
    endtask

endclass
