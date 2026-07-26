/* Writes every read-only register and verifies that the access is benign. */
class dma_ro_write_protection_seq extends dma_base_seq;

    `uvm_object_utils(dma_ro_write_protection_seq)

    function new(string name = "dma_ro_write_protection_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [7:0] ro_addr[7];
        bit [31:0] before_value;
        bit [31:0] after_value;

        ro_addr = '{REG_STATUS, REG_COMP_TAG, REG_COMP_LENGTH,
                    REG_COMP_STATUS, REG_QUEUE_LEVELS,
                    REG_SUBMITTED_COUNT, REG_COMPLETED_COUNT};

        for (int index = 0; index < 7; index++) begin
            read_reg(ro_addr[index], before_value);
            write_reg(ro_addr[index], 32'hffff_ffff, 4'hf);
            read_reg(ro_addr[index], after_value);
            if (after_value != before_value)
                `uvm_error("RO_WRITE_CHANGED",
                    $sformatf("addr=0x%02h before=0x%08h after=0x%08h",
                              ro_addr[index], before_value, after_value))
        end
    endtask

endclass

