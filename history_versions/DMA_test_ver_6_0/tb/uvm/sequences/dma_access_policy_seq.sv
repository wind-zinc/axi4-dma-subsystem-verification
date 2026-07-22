/* Covers benign accesses that RAL permissions intentionally prevent. */
class dma_access_policy_seq extends dma_base_seq;

    `uvm_object_utils(dma_access_policy_seq)

    function new(string name = "dma_access_policy_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] value;
        bit [31:0] status_before;
        bit [31:0] status_after;

        read_reg(REG_CONTROL, value);
        if (value != 0)
            `uvm_error("CONTROL_RESET",
                $sformatf("control reset value is 0x%08h", value))

        read_reg(REG_SUBMIT, value);
        if (value != 0)
            `uvm_error("SUBMIT_READ", "write-only SUBMIT did not read as zero")

        read_reg(REG_COMP_POP, value);
        if (value != 0)
            `uvm_error("COMP_POP_READ",
                "write-only COMP_POP did not read as zero")

        read_reg(REG_STATUS, status_before);
        write_reg(REG_STATUS, 32'hffff_ffff);
        read_reg(REG_STATUS, status_after);
        if (status_after != status_before)
            `uvm_error("STATUS_WRITE",
                $sformatf("RO status changed: before=0x%08h after=0x%08h",
                          status_before, status_after))

        `uvm_info("DMA_ACCESS_POLICY",
            "read/write access policy checks completed", UVM_LOW)
    endtask

endclass
