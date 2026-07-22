/*
 * The streaming DMA implements memcpy-like forward flow.  It cannot promise
 * memmove semantics when source and destination overlap, so the manager must
 * reject overlapping or address-wrapping descriptors before they enter FIFO.
 */
class dma_overlap_reject_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_overlap_reject_seq)

    function new(string name = "dma_overlap_reject_seq");
        super.new(name);
    endfunction

    virtual task expect_rejected(
        bit [15:0] src_addr,
        bit [15:0] dst_addr,
        bit [19:0] byte_length,
        bit [7:0]  tag,
        string     scenario
    );
        uvm_reg_data_t before_count;
        uvm_reg_data_t after_count;
        uvm_reg_data_t status;

        ral_read(ral.submitted_count, before_count);
        ral_submit_descriptor(src_addr, dst_addr, byte_length, tag);
        ral_read(ral.status, status);
        ral_read(ral.submitted_count, after_count);

        if (!status[8])
            `uvm_error("OVERLAP_ACCEPTED",
                $sformatf("%s did not set reject_invalid", scenario))
        if (after_count != before_count)
            `uvm_error("OVERLAP_COUNT",
                $sformatf("%s changed submitted_count %0d -> %0d",
                          scenario, before_count, after_count))

        /* CONTROL[1] clears sticky rejection flags. */
        ral_write(ral.control, 32'h2);
    endtask

    virtual task body();
        /* Destination begins inside the source interval. */
        expect_rejected(16'h1000, 16'h1080, 20'd256, 8'hd0,
                        "destination inside source");
        /* Source begins inside the destination interval. */
        expect_rejected(16'h2080, 16'h2000, 20'd256, 8'hd1,
                        "source inside destination");
        expect_rejected(16'h3000, 16'h3000, 20'd64, 8'hd2,
                        "identical ranges");

        /* These ranges would wrap beyond the 16-bit AXI address space. */
        expect_rejected(16'hfff0, 16'h4000, 20'd32, 8'hd3,
                        "source address overflow");
        expect_rejected(16'h4000, 16'hfff0, 20'd32, 8'hd4,
                        "destination address overflow");

        /* Adjacent ranges do not overlap and remain legal. */
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(16'h1000, 16'h1100, 20'd256, 8'hd5);
        check_and_pop_completion(8'hd5, 20'd256);
    endtask

endclass
