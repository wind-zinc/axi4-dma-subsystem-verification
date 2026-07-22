/* Checks the documented zero value of all empty completion-head registers. */
class dma_empty_completion_read_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_empty_completion_read_seq)

    function new(string name = "dma_empty_completion_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        uvm_reg_data_t value;

        ral_read(ral.status, value);
        if (value[4])
            `uvm_fatal("EMPTY_COMP_SETUP",
                "completion FIFO was not empty at test start")

        ral_read(ral.comp_tag, value);
        if (value != 0)
            `uvm_error("EMPTY_COMP_TAG",
                $sformatf("empty COMP_TAG returned 0x%08h", value))

        ral_read(ral.comp_length, value);
        if (value != 0)
            `uvm_error("EMPTY_COMP_LENGTH",
                $sformatf("empty COMP_LENGTH returned 0x%08h", value))

        ral_read(ral.comp_status, value);
        if (value != 0)
            `uvm_error("EMPTY_COMP_STATUS",
                $sformatf("empty COMP_STATUS returned 0x%08h", value))
    endtask

endclass

