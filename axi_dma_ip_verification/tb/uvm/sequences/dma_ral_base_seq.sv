/* Common frontdoor helpers for sequences that use the UVM register model. */
class dma_ral_base_seq extends uvm_sequence #(axil_item);

    `uvm_object_utils(dma_ral_base_seq)

    dma_reg_block ral;
    localparam int unsigned MAX_STATUS_POLLS = 5000;

    function new(string name = "dma_ral_base_seq");
        super.new(name);
    endfunction

    virtual task ral_write(uvm_reg rg, uvm_reg_data_t value);
        uvm_status_e status;

        if (ral == null)
            `uvm_fatal("NO_RAL", "RAL model was not assigned")

        rg.write(status, value, UVM_FRONTDOOR,
                 ral.default_map, this);
        if (status != UVM_IS_OK)
            `uvm_error("RAL_WRITE",
                $sformatf("write failed for %s", rg.get_full_name()))
    endtask

    virtual task ral_read(
        uvm_reg rg,
        output uvm_reg_data_t value
    );
        uvm_status_e status;

        if (ral == null)
            `uvm_fatal("NO_RAL", "RAL model was not assigned")

        rg.read(status, value, UVM_FRONTDOOR,
                ral.default_map, this);
        if (status != UVM_IS_OK)
            `uvm_error("RAL_READ",
                $sformatf("read failed for %s", rg.get_full_name()))
    endtask

    /* Program and commit one descriptor through the RAL frontdoor. */
    virtual task ral_submit_descriptor(
        bit [15:0] src_addr,
        bit [15:0] dst_addr,
        bit [19:0] byte_length,
        bit [7:0]  tag
    );
        ral_write(ral.src_addr, src_addr);
        ral_write(ral.dst_addr, dst_addr);
        ral_write(ral.length, byte_length);
        ral_write(ral.tag, tag);
        ral_write(ral.submit, 1);
    endtask

    /* Read both FIFO occupancy counters from QUEUE_LEVELS. */
    virtual task ral_read_queue_levels(
        output bit [15:0] request_level,
        output bit [15:0] completion_level
    );
        uvm_reg_data_t value;

        ral_read(ral.queue_levels, value);
        request_level    = value[15:0];
        completion_level = value[31:16];
    endtask

    /* Poll the completed descriptor counter, not a fixed cycle delay. */
    virtual task ral_wait_completed_count(int unsigned expected_count);
        uvm_reg_data_t value;

        repeat (MAX_STATUS_POLLS) begin
            ral_read(ral.completed_count, value);
            if (value >= expected_count)
                return;
        end

        `uvm_fatal("RAL_COUNT_TIMEOUT",
            $sformatf("completed_count did not reach %0d", expected_count))
    endtask

    virtual task wait_for_completion();
        uvm_reg_data_t value;

        repeat (MAX_STATUS_POLLS) begin
            ral_read(ral.status, value);
            if (value[4])
                return;
        end

        `uvm_fatal("RAL_DMA_TIMEOUT",
            "completion FIFO did not become valid")
    endtask

    /* Read the current completion FIFO head without removing it. */
    virtual task ral_read_completion(
        output bit [7:0]  tag,
        output bit [19:0] byte_length,
        output bit [10:0] completion_status
    );
        uvm_reg_data_t value;

        wait_for_completion();

        ral_read(ral.comp_tag, value);
        tag = value[7:0];

        ral_read(ral.comp_length, value);
        byte_length = value[19:0];

        ral_read(ral.comp_status, value);
        completion_status = value[10:0];
    endtask

    virtual task ral_pop_completion();
        ral_write(ral.comp_pop, 1);
    endtask

    virtual task check_and_pop_completion(
        bit [7:0] expected_tag,
        bit [19:0] expected_length
    );
        uvm_reg_data_t value;

        bit [7:0]  actual_tag;
        bit [19:0] actual_length;
        bit [10:0] actual_status;

        ral_read_completion(actual_tag, actual_length, actual_status);

        if (actual_tag != expected_tag)
            `uvm_error("RAL_COMP_TAG",
                $sformatf("got 0x%0h expected 0x%0h",
                          actual_tag, expected_tag))

        if (actual_length != expected_length)
            `uvm_error("RAL_COMP_LENGTH",
                $sformatf("got %0d expected %0d",
                          actual_length, expected_length))

        if (actual_status != 0)
            `uvm_error("RAL_COMP_STATUS",
                $sformatf("completion status is 0x%03h", actual_status))

        ral_pop_completion();
        ral_read(ral.status, value);
        if (value[4] || value[6])
            `uvm_error("RAL_COMP_POP",
                $sformatf("completion/IRQ still active: 0x%08h", value))
    endtask

    virtual task body();
        `uvm_fatal("RAL_BASE_SEQ",
            "dma_ral_base_seq must be extended")
    endtask

endclass
