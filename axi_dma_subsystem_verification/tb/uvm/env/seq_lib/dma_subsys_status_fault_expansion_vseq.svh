class dma_subsys_status_fault_expansion_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_status_fault_expansion_vseq)

    function new(string name = "dma_subsys_status_fault_expansion_vseq");
        super.new(name);
    endfunction

    protected task wait_for_manager_fault(
        input dma_error_e expected_error,
        input string      operation
    );
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.combined_fault_valid) begin
                if (p_sequencer.probe_vif.mon_cb.combined_fault.error
                        != expected_error) begin
                    `uvm_error(
                        "STATUS_EXPANSION_FAULT",
                        $sformatf(
                            "%s expected fault 0x%02h, observed 0x%02h",
                            operation,
                            expected_error,
                            p_sequencer.probe_vif.mon_cb.combined_fault.error))
                end
                return;
            end
        end
        `uvm_fatal(
            "STATUS_EXPANSION_TIMEOUT",
            $sformatf("%s did not raise a manager fault", operation))
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // The earlier status test covered a read-tag mismatch and a write
        // length mismatch.  Corrupt the write-status tag itself here.
        initialize_region(
            RAM0_BASE_ADDR + 32'h0000_1400,
            64,
            8'h31,
            "write-tag mismatch source");
        publish_dma_intent(
            "write_tag_mismatch_intent",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1400,
            RAM1_BASE_ADDR + 32'h0000_2400,
            64,
            8'hF0,
            DMA_ERR_TAG_MISMATCH);
        program_dma(
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1400,
            RAM1_BASE_ADDR + 32'h0000_2400,
            64,
            8'hF0);
        p_sequencer.test_ctrl_vif.forced_wr_tag[1] = 8'hFF;
        p_sequencer.test_ctrl_vif.corrupt_wr_tag_enable[1] = 1'b1;
        set_channel_control(
            DMA_CH0,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "start write-tag mismatch flow");
        check_channel_error(
            DMA_CH0,
            DMA_ERR_TAG_MISMATCH,
            1'b0,
            "write-tag mismatch");
        wait_probe_cycles(2);
        p_sequencer.test_ctrl_vif.corrupt_wr_tag_enable[1] = 1'b0;
        clear_channel_result(DMA_CH0);

        // Mirror the illegal-state recovery scenario onto CH0.  Forcing only
        // the state encoding leaves command/tag/context data naturally timed.
        initialize_region(
            RAM0_BASE_ADDR + 32'h0000_3400,
            64,
            8'h42,
            "CH0 manager recovery source");
        publish_dma_intent(
            "ch0_manager_recovery_intent",
            DMA_CH0,
            DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_3400,
            RAM0_BASE_ADDR + 32'h0000_4400,
            64,
            8'hF1,
            DMA_ERR_INTERNAL);
        program_dma(
            DMA_CH0,
            DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_3400,
            RAM0_BASE_ADDR + 32'h0000_4400,
            64,
            8'hF1);
        set_channel_control(
            DMA_CH0,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "start CH0 manager recovery flow");
        wait_channel_busy(DMA_CH0);
        p_sequencer.test_ctrl_vif.forced_manager_state[0] = 4'hF;
        p_sequencer.test_ctrl_vif.force_manager_state_enable[0] = 1'b1;
        wait_probe_cycles(1);
        p_sequencer.test_ctrl_vif.force_manager_state_enable[0] = 1'b0;
        wait_for_manager_fault(
            DMA_ERR_INTERNAL,
            "CH0 illegal manager state");
        check_channel_error(
            DMA_CH0,
            DMA_ERR_INTERNAL,
            1'b0,
            "CH0 manager recovery");
        clear_channel_result(DMA_CH0);

        p_sequencer.test_ctrl_vif.corrupt_wr_tag_enable = '0;
        p_sequencer.test_ctrl_vif.force_manager_state_enable = '0;
        wait_probe_cycles(5);
    endtask
endclass
