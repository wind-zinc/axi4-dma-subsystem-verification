/* Assert reset after a descriptor is active, then prove clean recovery. */
class dma_reset_recovery_seq extends dma_mem_ral_base_seq;

    `uvm_object_utils(dma_reset_recovery_seq)

    virtual dma_reset_if reset_vif;

    function new(string name = "dma_reset_recovery_seq");
        super.new(name);
    endfunction

    virtual task body();
        uvm_reg_data_t value;
        bit active_seen = 1'b0;

        require_mem_vif();
        if (reset_vif == null)
            `uvm_fatal("NO_RESET_VIF", "reset virtual interface is null")

        mem_vif.clear_all();
        /* Hold AR so the operation is definitely active but no source data
         * has entered the memory-to-memory stream when reset arrives. */
        mem_vif.set_stalls(1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(16'h0000, 16'h8000, 20'd8192, 8'he0);

        repeat (1000) begin
            ral_read(ral.status, value);
            if (value[0]) begin
                active_seen = 1'b1;
                break;
            end
        end
        if (!active_seen)
            `uvm_fatal("RESET_SETUP", "DMA did not become active")

        reset_vif.pulse(4);
        mem_vif.clear_all();
        ral.reset();
        repeat (2) @(posedge reset_vif.clk);

        ral_read(ral.status, value);
        if (value[6:0] != 7'b0001010)
            `uvm_error("RESET_STATUS",
                $sformatf("unexpected reset status 0x%08h", value))
        ral_read(ral.submitted_count, value);
        if (value != 0)
            `uvm_error("RESET_SUBMITTED",
                $sformatf("submitted_count is %0d after reset", value))
        ral_read(ral.completed_count, value);
        if (value != 0)
            `uvm_error("RESET_COMPLETED",
                $sformatf("completed_count is %0d after reset", value))

        /* A normal transfer after reset proves that all interfaces recover. */
        ral_write(ral.control, 32'h1);
        ral_submit_descriptor(16'h3000, 16'h7000, 20'd64, 8'he1);
        check_and_pop_completion(8'he1, 20'd64);
    endtask

endclass
