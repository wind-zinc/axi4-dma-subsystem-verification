/* Deterministically samples request FIFO level 2 while the first DMA stalls. */
class dma_queue_mid_level_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_queue_mid_level_seq)

    function new(string name = "dma_queue_mid_level_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] request_level;
        bit [15:0] completion_level;
        bit manager_busy;
        uvm_reg_data_t value;
        bit [7:0] actual_tag;
        bit [19:0] actual_length;
        bit [10:0] actual_status;

        require_mem_vif();
        mem_vif.clear_all();
        mem_vif.set_stalls(0, 0, 0, 1, 0);
        ral_write(ral.control, 32'h1);

        ral_submit_descriptor(16'h1000, 16'h8000, 20'd256, 8'hd0);

        manager_busy = 1'b0;
        repeat (100) begin
            ral_read(ral.status, value);
            ral_read_queue_levels(request_level, completion_level);
            if (value[0] && request_level == 0) begin
                manager_busy = 1'b1;
                break;
            end
        end
        if (!manager_busy)
            `uvm_fatal("QUEUE_MID_SETUP",
                "first request did not enter the DMA engine")

        ral_submit_descriptor(16'h2000, 16'h9000, 20'd64, 8'hd1);
        ral_submit_descriptor(16'h2100, 16'h9100, 20'd64, 8'hd2);

        ral_read_queue_levels(request_level, completion_level);
        if (request_level != 2)
            `uvm_error("QUEUE_MID_LEVEL",
                $sformatf("request level=%0d expected 2", request_level))

        mem_vif.clear_stalls();
        ral_wait_completed_count(3);

        for (int index = 0; index < 3; index++) begin
            ral_read_completion(actual_tag, actual_length, actual_status);
            if (actual_tag != 8'hd0 + index || actual_status != 0)
                `uvm_error("QUEUE_MID_COMPLETION",
                    $sformatf("index=%0d tag=0x%0h status=0x%0h",
                              index, actual_tag, actual_status))
            ral_pop_completion();
        end

        ral_read_queue_levels(request_level, completion_level);
        if (request_level != 0 || completion_level != 0)
            `uvm_error("QUEUE_MID_DRAIN",
                $sformatf("request=%0d completion=%0d",
                          request_level, completion_level))

        mem_vif.clear_all();
    endtask

endclass

