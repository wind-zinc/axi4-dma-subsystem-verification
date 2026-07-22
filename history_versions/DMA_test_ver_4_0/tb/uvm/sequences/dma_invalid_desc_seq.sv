/* Exercises invalid descriptor rejection without starting the DMA engine. */
class dma_invalid_desc_seq extends dma_base_seq;

    `uvm_object_utils(dma_invalid_desc_seq)

    function new(string name = "dma_invalid_desc_seq");
        super.new(name);
    endfunction

    virtual task expect_invalid_sticky(string scenario);
        bit [31:0] status;
        read_reg(REG_STATUS, status);
        if (!status[8])
            `uvm_error("INVALID_DESC",
                $sformatf("%s did not set reject_invalid: 0x%08h",
                          scenario, status))
    endtask

    virtual task clear_sticky();
        bit [31:0] status;
        write_reg(REG_CONTROL, 32'h2);
        read_reg(REG_STATUS, status);
        if (status[10:7] != 0)
            `uvm_error("CLEAR_STICKY",
                $sformatf("sticky bits did not clear: 0x%08h", status))
    endtask

    virtual task body();
        bit [31:0] count;

        clear_sticky();

        submit_descriptor(16'h1000, 16'h5000, 20'd0, 8'h71);
        expect_invalid_sticky("zero length");
        clear_sticky();

        submit_descriptor(16'h1001, 16'h5000, 20'd32, 8'h72);
        expect_invalid_sticky("unaligned source");
        clear_sticky();

        write_reg(REG_SRC_ADDR, 32'h0000_1000);
        write_reg(REG_DST_ADDR, 32'h0000_5000);
        write_reg(REG_LENGTH, 32'd32);
        write_reg(REG_TAG, 32'h0000_0100);
        write_reg(REG_SUBMIT, 32'h1);
        expect_invalid_sticky("tag wider than TAG_WIDTH");

        read_reg(REG_SUBMITTED_COUNT, count);
        if (count != 0)
            `uvm_error("INVALID_COUNT",
                $sformatf("invalid descriptors were accepted: %0d", count))

        `uvm_info("DMA_INVALID_DESC",
            "invalid descriptor cases completed", UVM_LOW)
    endtask

endclass
