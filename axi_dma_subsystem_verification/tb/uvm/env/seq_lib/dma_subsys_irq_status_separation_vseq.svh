class dma_subsys_irq_status_separation_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_irq_status_separation_vseq)

    function new(string name = "dma_subsys_irq_status_separation_vseq");
        super.new(name);
    endfunction

    protected task expect_irq_status(
        input logic [1:0] expected_done,
        input logic [1:0] expected_error,
        input bit         expected_fault,
        input bit         expected_summary,
        input string      operation
    );
        logic [31:0] status;

        axil_read32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
            status,
            operation);
        if ((status[1:0] != expected_done)
                || (status[9:8] != expected_error)
                || (status[30] != expected_fault)
                || (status[31] != expected_summary)) begin
            `uvm_error(
                "IRQ_STATUS_SEPARATION",
                $sformatf(
                    "%s expected done=%02b error=%02b fault=%0b summary=%0b, status=0x%08h",
                    operation, expected_done, expected_error,
                    expected_fault, expected_summary, status))
        end
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem(32'h0000_0100);

        // A validation failure raises both done and error pending.  Clearing
        // only done leaves the otherwise-missing error-only status shape.
        publish_dma_intent(
            "irq_error_only_intent",
            DMA_CH0,
            DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_0100,
            RAM0_BASE_ADDR + 32'h0000_0200,
            0,
            8'h70,
            DMA_ERR_LEN_ZERO,
            1'b1,
            1'b1,
            1'b1);
        program_dma(
            DMA_CH0,
            DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_0100,
            RAM0_BASE_ADDR + 32'h0000_0200,
            0,
            8'h70);
        set_channel_control(
            DMA_CH0,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "start IRQ error-only flow");
        check_channel_error(
            DMA_CH0,
            DMA_ERR_LEN_ZERO,
            1'b0,
            "IRQ error-only flow");
        wait_probe_cycles(2);
        expect_irq_status(
            2'b01, 2'b01, 1'b0, 1'b1,
            "observe done plus error pending");

        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h0000_0001,
            "clear CH0 done only");
        wait_probe_cycles(2);
        expect_irq_status(
            2'b00, 2'b01, 1'b0, 1'b1,
            "observe error-only pending");
        if (!p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error(
                "IRQ_ERROR_ONLY_LEVEL",
                "enabled CH0 error pending did not hold global IRQ high")
        end

        // Raise a manager fault, then attempt to clear bit 30 while byte lane
        // three is masked.  The first write must not clear the fault.
        p_sequencer.test_ctrl_vif.pulse_unexpected_rd_status(0);
        wait_probe_cycles(2);
        expect_irq_status(
            2'b00, 2'b01, 1'b1, 1'b1,
            "observe error plus fault pending");

        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b1;
        p_sequencer.test_ctrl_vif.forced_axil_wstrb = 4'b0111;
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000,
            "attempt masked fault clear");
        wait_probe_cycles(2);
        expect_irq_status(
            2'b00, 2'b01, 1'b1, 1'b1,
            "fault survives masked byte-three write");

        p_sequencer.test_ctrl_vif.forced_axil_wstrb = 4'b1000;
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000,
            "clear fault through enabled byte lane");
        wait_probe_cycles(2);
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b0;
        expect_irq_status(
            2'b00, 2'b01, 1'b0, 1'b1,
            "fault cleared while error remains");

        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h0000_0100,
            "clear final CH0 error pending");
        set_channel_control(
            DMA_CH0,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "clear CH0 local result");
        wait_probe_cycles(3);
        expect_irq_status(
            2'b00, 2'b00, 1'b0, 1'b0,
            "all pending status cleared");
        if (p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error(
                "IRQ_FINAL_LEVEL",
                "global IRQ remained asserted after all causes were cleared")
        end
        wait_probe_cycles(5);
    endtask
endclass
