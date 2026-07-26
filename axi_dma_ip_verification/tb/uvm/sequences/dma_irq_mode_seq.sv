/* Checks completion behavior with IRQ disabled and then enabled. */
class dma_irq_mode_seq extends dma_base_seq;

    `uvm_object_utils(dma_irq_mode_seq)

    function new(string name = "dma_irq_mode_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] status;

        write_reg(REG_CONTROL, 32'h0);
        submit_descriptor(16'h1200, 16'h5200, 20'd64, 8'h61);
        wait_for_completion();
        read_reg(REG_STATUS, status);
        if (!status[4] || status[6])
            `uvm_error("IRQ_DISABLED",
                $sformatf("unexpected status 0x%08h", status))
        check_and_pop_completion(8'h61, 20'd64);

        write_reg(REG_CONTROL, 32'h1);
        submit_descriptor(16'h1400, 16'h5400, 20'd64, 8'h62);
        wait_for_completion();
        read_reg(REG_STATUS, status);
        if (!status[4] || !status[6])
            `uvm_error("IRQ_ENABLED",
                $sformatf("unexpected status 0x%08h", status))
        check_and_pop_completion(8'h62, 20'd64);

        `uvm_info("DMA_IRQ_MODE",
            "disabled and enabled IRQ modes completed", UVM_LOW)
    endtask

endclass
