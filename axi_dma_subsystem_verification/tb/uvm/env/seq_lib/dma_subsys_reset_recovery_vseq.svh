class dma_subsys_reset_recovery_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_reset_recovery_vseq)

    function new(string name = "dma_subsys_reset_recovery_vseq");
        super.new(name);
    endfunction

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // Repeated reset while idle.
        p_sequencer.test_ctrl_vif.pulse_reset(20);
        wait_for_infrastructure();
        prepare_subsystem();

        // Reset an accepted active command.  The reset monitor tells the
        // scoreboard to discard the incomplete flow and verify clean route,
        // busy, completion and IRQ state after deassertion.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_1000,
            1024, 8'h51, "pre-reset active source");
        publish_dma_intent("active_reset_intent", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_5000,
            1024, 8'hC0, DMA_ERR_NONE,
            1'b1, 1'b0, 1'b0);
        program_dma(DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_5000,
            1024, 8'hC0);
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start flow interrupted by reset");
        wait_channel_busy(DMA_CH0);
        wait_probe_cycles(4);
        p_sequencer.test_ctrl_vif.pulse_reset(20);
        wait_for_infrastructure();

        if ((p_sequencer.probe_vif.mon_cb.busy != '0)
                || (p_sequencer.probe_vif.mon_cb.route_active != '0)
                || (p_sequencer.probe_vif.mon_cb.route_matrix != '0)
                || (p_sequencer.probe_vif.mon_cb.irq_ch != '0)
                || p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error("RESET_NOT_CLEAN",
                "active reset did not restore idle route/IRQ state")
        end

        // Reprogram everything after reset and prove end-to-end recovery.
        prepare_subsystem();
        run_dma_case("post_reset_recovery", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_2000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            128, 8'hC1, 8'h62);
        wait_probe_cycles(5);
    endtask
endclass
