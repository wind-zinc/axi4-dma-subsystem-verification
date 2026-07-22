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

    virtual task check_and_pop_completion(
        bit [7:0] expected_tag,
        bit [19:0] expected_length
    );
        uvm_reg_data_t value;

        wait_for_completion();

        ral_read(ral.comp_tag, value);
        if (value[7:0] != expected_tag)
            `uvm_error("RAL_COMP_TAG",
                $sformatf("got 0x%0h expected 0x%0h",
                          value[7:0], expected_tag))

        ral_read(ral.comp_length, value);
        if (value[19:0] != expected_length)
            `uvm_error("RAL_COMP_LENGTH",
                $sformatf("got %0d expected %0d",
                          value[19:0], expected_length))

        ral_read(ral.comp_status, value);
        if (value[10:0] != 0)
            `uvm_error("RAL_COMP_STATUS",
                $sformatf("completion status is 0x%08h", value))

        ral_write(ral.comp_pop, 1);
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
