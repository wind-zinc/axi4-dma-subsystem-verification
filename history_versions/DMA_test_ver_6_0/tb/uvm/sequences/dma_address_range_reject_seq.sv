/* Isolates each width check while all other descriptor fields remain legal. */
class dma_address_range_reject_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_address_range_reject_seq)

    function new(string name = "dma_address_range_reject_seq");
        super.new(name);
    endfunction

    virtual task expect_reject(string scenario);
        uvm_reg_data_t value;
        ral_read(ral.status, value);
        if (!value[8])
            `uvm_error("RANGE_REJECT",
                $sformatf("%s was not rejected: status=0x%08h",
                          scenario, value))
        ral_write(ral.control, 32'h2);
    endtask

    virtual task body();
        uvm_reg_data_t initial_count;
        uvm_reg_data_t final_count;

        ral_write(ral.control, 32'h2);
        ral_read(ral.submitted_count, initial_count);

        ral_write(ral.src_addr, 32'h0001_1000);
        ral_write(ral.dst_addr, 32'h0000_8000);
        ral_write(ral.length, 32'd64);
        ral_write(ral.tag, 32'h11);
        ral_write(ral.submit, 1);
        expect_reject("source address wider than AXI_ADDR_WIDTH");

        ral_write(ral.src_addr, 32'h0000_1000);
        ral_write(ral.dst_addr, 32'h0001_8000);
        ral_write(ral.length, 32'd64);
        ral_write(ral.tag, 32'h12);
        ral_write(ral.submit, 1);
        expect_reject("destination address wider than AXI_ADDR_WIDTH");

        ral_write(ral.src_addr, 32'h0000_1000);
        ral_write(ral.dst_addr, 32'h0000_8000);
        ral_write(ral.length, 32'h0010_0040);
        ral_write(ral.tag, 32'h13);
        ral_write(ral.submit, 1);
        expect_reject("length wider than LEN_WIDTH");

        ral_read(ral.submitted_count, final_count);
        if (final_count != initial_count)
            `uvm_error("RANGE_REJECT_COUNT",
                $sformatf("invalid descriptors changed count %0d -> %0d",
                          initial_count, final_count))
    endtask

endclass

