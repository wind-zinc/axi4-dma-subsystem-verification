/*
 * Fills both descriptor FIFOs without any hierarchical force.
 *
 * The first long transfer keeps the engine busy while four more requests are
 * queued.  A sixth submission is rejected.  Later, software intentionally
 * leaves four completions unpopped so the completion FIFO becomes full.
 */
class dma_queue_saturation_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_queue_saturation_seq)

    function new(string name = "dma_queue_saturation_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src_addr[5];
        bit [15:0] dst_addr[5];
        bit [19:0] byte_length[5];
        bit [7:0]  tag[5];
        bit [15:0] request_level;
        bit [15:0] completion_level;
        bit [7:0]  actual_tag;
        bit [19:0] actual_length;
        bit [10:0] actual_status;
        uvm_reg_data_t value;

        src_addr[0] = 16'h0000;
        dst_addr[0] = 16'h8000;
        byte_length[0] = 20'd8192;
        tag[0] = 8'ha0;

        src_addr[1] = 16'h2000;
        dst_addr[1] = 16'ha000;
        byte_length[1] = 20'd64;
        tag[1] = 8'ha1;

        src_addr[2] = 16'h2100;
        dst_addr[2] = 16'ha100;
        byte_length[2] = 20'd64;
        tag[2] = 8'ha2;

        src_addr[3] = 16'h2200;
        dst_addr[3] = 16'ha200;
        byte_length[3] = 20'd64;
        tag[3] = 8'ha3;

        /* This request remains queued when the completion FIFO becomes full. */
        src_addr[4] = 16'h4000;
        dst_addr[4] = 16'hc000;
        byte_length[4] = 20'd8192;
        tag[4] = 8'ha4;

        /* Enable IRQ and clear sticky status from any setup access. */
        ral_write(ral.control, 32'h0000_0003);

        for (int index = 0; index < 5; index++)
            ral_submit_descriptor(src_addr[index], dst_addr[index],
                                  byte_length[index], tag[index]);

        /* Request FIFO is now full; this legal descriptor must be rejected. */
        ral_submit_descriptor(16'h6000, 16'he000, 20'd64, 8'hb0);

        ral_read(ral.status, value);
        if (!value[2] || value[3] || !value[7])
            `uvm_error("REQUEST_FIFO_FULL",
                $sformatf("expected full/not-ready/reject-full, status=0x%08h",
                          value))

        ral_read_queue_levels(request_level, completion_level);
        if (request_level != 4)
            `uvm_error("REQUEST_LEVEL",
                $sformatf("got %0d expected 4", request_level))

        ral_read(ral.submitted_count, value);
        if (value != 5)
            `uvm_error("SUBMITTED_COUNT",
                $sformatf("got %0d expected 5", value))

        /* Four unconsumed completions stop the manager with one request left. */
        ral_wait_completed_count(4);
        ral_read(ral.status, value);
        if (!value[4] || !value[5] || !value[6])
            `uvm_error("COMPLETION_FIFO_FULL",
                $sformatf("expected valid/full/IRQ, status=0x%08h", value))

        ral_read_queue_levels(request_level, completion_level);
        if (request_level != 1 || completion_level != 4)
            `uvm_error("FULL_LEVELS",
                $sformatf("request=%0d completion=%0d expected 1/4",
                          request_level, completion_level))

        /* Drain the first four completions and sample every intermediate level. */
        for (int index = 0; index < 4; index++) begin
            ral_read_completion(actual_tag, actual_length, actual_status);
            if (actual_tag != tag[index] ||
                    actual_length != byte_length[index] ||
                    actual_status != 0)
                `uvm_error("SATURATION_COMPLETION",
                    $sformatf("index=%0d tag=0x%0h len=%0d status=0x%0h",
                              index, actual_tag, actual_length, actual_status))

            ral_read_queue_levels(request_level, completion_level);
            ral_pop_completion();
        end

        /* The fifth request starts after space is created in completion FIFO. */
        ral_wait_completed_count(5);
        ral_read_completion(actual_tag, actual_length, actual_status);
        if (actual_tag != tag[4] || actual_length != byte_length[4] ||
                actual_status != 0)
            `uvm_error("FINAL_COMPLETION",
                $sformatf("tag=0x%0h len=%0d status=0x%0h",
                          actual_tag, actual_length, actual_status))

        ral_read_queue_levels(request_level, completion_level);
        ral_pop_completion();

        ral_read(ral.status, value);
        if (value[4] || value[5] || value[6] || !value[1])
            `uvm_error("QUEUE_DRAIN",
                $sformatf("queues did not return idle: 0x%08h", value))

        /* Clear reject_full and verify that sticky status is software-clearable. */
        ral_write(ral.control, 32'h0000_0003);
        ral_read(ral.status, value);
        if (value[10:7] != 0)
            `uvm_error("STICKY_CLEAR",
                $sformatf("sticky status remains set: 0x%08h", value))

        `uvm_info("DMA_QUEUE_SATURATION",
            "request and completion FIFO saturation completed", UVM_LOW)
    endtask

endclass
