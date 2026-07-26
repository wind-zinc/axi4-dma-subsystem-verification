/* Covers command-register writes that must not generate a command pulse. */
class dma_command_noop_seq extends dma_base_seq;

    `uvm_object_utils(dma_command_noop_seq)

    function new(string name = "dma_command_noop_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] before_count;
        bit [31:0] after_count;
        bit [31:0] status;

        write_reg(REG_CONTROL, 32'h2);
        read_reg(REG_SUBMITTED_COUNT, before_count);

        write_reg(REG_SUBMIT, 32'h1, 4'h0);
        write_reg(REG_SUBMIT, 32'h0, 4'h1);
        read_reg(REG_SUBMITTED_COUNT, after_count);
        if (after_count != before_count)
            `uvm_error("SUBMIT_NOOP",
                $sformatf("count changed from %0d to %0d",
                          before_count, after_count))

        write_reg(REG_COMP_POP, 32'h1, 4'h0);
        write_reg(REG_COMP_POP, 32'h0, 4'h1);
        read_reg(REG_STATUS, status);
        if (status[10])
            `uvm_error("POP_NOOP",
                $sformatf("no-op pop set sticky status: 0x%08h", status))
    endtask

endclass

