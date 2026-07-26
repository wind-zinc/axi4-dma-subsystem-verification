/*
 * ENABLE_UNALIGNED is zero in tb_uvm_top.  Exercise every non-zero byte
 * offset as a rejected software submission instead of pretending those
 * descriptors can execute.
 */
class dma_alignment_reject_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_alignment_reject_seq)

    function new(string name = "dma_alignment_reject_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src_addr[6];
        bit [15:0] dst_addr[6];
        uvm_reg_data_t value;

        src_addr[0] = 16'h1001; dst_addr[0] = 16'h5000;
        src_addr[1] = 16'h1002; dst_addr[1] = 16'h5000;
        src_addr[2] = 16'h1003; dst_addr[2] = 16'h5000;
        src_addr[3] = 16'h1000; dst_addr[3] = 16'h5001;
        src_addr[4] = 16'h1000; dst_addr[4] = 16'h5002;
        src_addr[5] = 16'h1000; dst_addr[5] = 16'h5003;

        for (int index = 0; index < 6; index++) begin
            ral_write(ral.control, 32'h0000_0002);
            ral_submit_descriptor(src_addr[index], dst_addr[index],
                                  20'd32, 8'hd0 + index);
            ral_read(ral.status, value);
            if (!value[8])
                `uvm_error("ALIGNMENT_REJECT",
                    $sformatf("src=0x%04h dst=0x%04h status=0x%08h",
                              src_addr[index], dst_addr[index], value))
        end

        ral_read(ral.submitted_count, value);
        if (value != 0)
            `uvm_error("ALIGNMENT_COUNT",
                $sformatf("misaligned descriptors accepted: %0d", value))

        `uvm_info("DMA_ALIGNMENT_REJECT",
            "all disabled unaligned offsets were rejected", UVM_LOW)
    endtask

endclass
