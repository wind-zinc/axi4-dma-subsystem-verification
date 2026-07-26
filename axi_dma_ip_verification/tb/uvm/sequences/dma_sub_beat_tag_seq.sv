/* Covers legal 1/2/3-byte transfers and zero/high descriptor tags. */
class dma_sub_beat_tag_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_sub_beat_tag_seq)

    function new(string name = "dma_sub_beat_tag_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src_addr[3];
        bit [15:0] dst_addr[3];
        bit [19:0] byte_length[3];
        bit [7:0]  tag[3];

        src_addr[0] = 16'h1000;
        src_addr[1] = 16'h1100;
        src_addr[2] = 16'h1200;
        dst_addr[0] = 16'h5000;
        dst_addr[1] = 16'h5100;
        dst_addr[2] = 16'h5200;
        byte_length[0] = 20'd1;
        byte_length[1] = 20'd2;
        byte_length[2] = 20'd3;
        tag[0] = 8'h00;
        tag[1] = 8'hc0;
        tag[2] = 8'hff;

        ral_write(ral.control, 32'h0000_0001);

        for (int index = 0; index < 3; index++) begin
            ral_submit_descriptor(src_addr[index], dst_addr[index],
                                  byte_length[index], tag[index]);
            check_and_pop_completion(tag[index], byte_length[index]);
        end

        `uvm_info("DMA_SUB_BEAT_TAG",
            "1/2/3-byte transfers with zero/high tags completed", UVM_LOW)
    endtask

endclass
