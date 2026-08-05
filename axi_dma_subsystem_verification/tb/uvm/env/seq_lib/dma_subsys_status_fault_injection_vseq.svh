class dma_subsys_status_fault_injection_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_status_fault_injection_vseq)

    function new(string name = "dma_subsys_status_fault_injection_vseq");
        super.new(name);
    endfunction

    protected task wait_for_fault(
        input dma_error_e expected_error,
        input string operation
    );
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.combined_fault_valid) begin
                if (p_sequencer.probe_vif.mon_cb.combined_fault.error
                        != expected_error) begin
                    `uvm_error("FAULT_CODE",
                        $sformatf("%s expected 0x%02h got 0x%02h",
                            operation, expected_error,
                            p_sequencer.probe_vif.mon_cb.combined_fault.error))
                end
                return;
            end
        end
        `uvm_fatal("FAULT_TIMEOUT", operation)
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // Corrupt a naturally timed read status tag.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_1000,
            64, 8'h11, "tag-mismatch source");
        publish_dma_intent("tag_mismatch_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_2000,
            64, 8'hE0, DMA_ERR_TAG_MISMATCH);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_2000,
            64, 8'hE0);
        p_sequencer.test_ctrl_vif.forced_rd_tag[0] = '1;
        p_sequencer.test_ctrl_vif.corrupt_rd_tag_enable[0] = 1'b1;
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start tag-mismatch flow");
        check_channel_error(DMA_CH0,
            DMA_ERR_TAG_MISMATCH, 1'b0, "tag mismatch");
        p_sequencer.test_ctrl_vif.corrupt_rd_tag_enable[0] = 1'b0;
        clear_channel_result(DMA_CH0);

        // Preserve normal status timing but replace the reported write length.
        initialize_region(RAM1_BASE_ADDR + 32'h0000_1000,
            64, 8'h22, "length-mismatch source");
        publish_dma_intent("length_mismatch_intent", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_2000,
            64, 8'hE1, DMA_ERR_LEN_MISMATCH);
        program_dma(DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_2000,
            64, 8'hE1);
        p_sequencer.test_ctrl_vif.forced_wr_len[1] = 20'd60;
        p_sequencer.test_ctrl_vif.corrupt_wr_len_enable[1] = 1'b1;
        set_channel_control(DMA_CH1,
            1'b1, 1'b1, 1'b0, 1'b0, "start length-mismatch flow");
        check_channel_error(DMA_CH1,
            DMA_ERR_LEN_MISMATCH, 1'b0, "length mismatch");
        p_sequencer.test_ctrl_vif.corrupt_wr_len_enable[1] = 1'b0;
        clear_channel_result(DMA_CH1);

        // The SW register block always supplies the correct source channel;
        // override the manager's captured copy during validation to reach its
        // defensive ROUTE_CONFLICT completion branch.
        publish_dma_intent("manager_route_conflict_intent", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_3000,
            64, 8'hE2, DMA_ERR_ROUTE_CONFLICT);
        program_dma(DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_3000,
            64, 8'hE2);
        p_sequencer.test_ctrl_vif.forced_cmd_reg_src[0] = 1'b1;
        p_sequencer.test_ctrl_vif.force_cmd_reg_src_enable[0] = 1'b1;
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start manager route-conflict flow");
        wait_probe_cycles(3);
        p_sequencer.test_ctrl_vif.force_cmd_reg_src_enable[0] = 1'b0;
        check_channel_error(DMA_CH0,
            DMA_ERR_ROUTE_CONFLICT, 1'b0, "manager route conflict");
        clear_channel_result(DMA_CH0);

        // Force one illegal manager state.  Its default and recovery branches
        // must raise a MANAGER/INTERNAL fault and produce an INTERNAL result.
        initialize_region(RAM1_BASE_ADDR + 32'h0000_4000,
            64, 8'h44, "internal-fault source");
        publish_dma_intent("internal_fault_intent", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_4000,
            RAM1_BASE_ADDR + 32'h0000_5000,
            64, 8'hE3, DMA_ERR_INTERNAL);
        program_dma(DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_4000,
            RAM1_BASE_ADDR + 32'h0000_5000,
            64, 8'hE3);
        set_channel_control(DMA_CH1,
            1'b1, 1'b1, 1'b0, 1'b0, "start internal-fault flow");
        wait_channel_busy(DMA_CH1);
        p_sequencer.test_ctrl_vif.forced_manager_state[1] = 4'hF;
        p_sequencer.test_ctrl_vif.force_manager_state_enable[1] = 1'b1;
        wait_probe_cycles(1);
        p_sequencer.test_ctrl_vif.force_manager_state_enable[1] = 1'b0;
        wait_for_fault(DMA_ERR_INTERNAL, "manager internal fault");
        check_channel_error(DMA_CH1,
            DMA_ERR_INTERNAL, 1'b0, "manager internal recovery");
        clear_channel_result(DMA_CH1);

        // Four idle status sources close RD0/RD1/WR0/WR1 fault-source bins.
        publish_dma_intent("unexpected_status_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR, RAM0_BASE_ADDR + 32'h100,
            4, 8'hE4, DMA_ERR_UNEXPECTED_STATUS,
            1'b0, 1'b0, 1'b0);
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000, "mask first unexpected-status fault");
        fork
            p_sequencer.test_ctrl_vif.pulse_unexpected_rd_status(0);
            wait_for_fault(DMA_ERR_UNEXPECTED_STATUS, "unexpected RD0 status");
        join
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000, "clear RD0 fault");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0000, "enable remaining fault sources");
        fork
            p_sequencer.test_ctrl_vif.pulse_unexpected_rd_status(1);
            wait_for_fault(DMA_ERR_UNEXPECTED_STATUS, "unexpected RD1 status");
        join
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000, "clear RD1 fault");
        fork
            p_sequencer.test_ctrl_vif.pulse_unexpected_wr_status(0);
            wait_for_fault(DMA_ERR_UNEXPECTED_STATUS, "unexpected WR0 status");
        join
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000, "clear WR0 fault");
        fork
            p_sequencer.test_ctrl_vif.pulse_unexpected_wr_status(1);
            wait_for_fault(DMA_ERR_UNEXPECTED_STATUS, "unexpected WR1 status");
        join
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0000, "clear WR1 fault");

        // Finally corrupt the route-controller request source.  This flow is
        // intentionally terminated by reset after the ROUTE fault is seen.
        publish_dma_intent("route_fault_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_7000,
            64, 8'hE5, DMA_ERR_ROUTE_CONFLICT,
            1'b1, 1'b0, 1'b1);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_7000,
            64, 8'hE5);
        p_sequencer.test_ctrl_vif.forced_route_src[0] = 1'b1;
        p_sequencer.test_ctrl_vif.force_route_src_enable[0] = 1'b1;
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start route-controller fault flow");
        wait_for_fault(DMA_ERR_ROUTE_CONFLICT, "route-controller fault");
        p_sequencer.test_ctrl_vif.reset_request = 1'b1;
        p_sequencer.test_ctrl_vif.force_route_src_enable[0] = 1'b0;
        wait_probe_cycles(20);
        p_sequencer.test_ctrl_vif.reset_request = 1'b0;
        wait_for_infrastructure();
        p_sequencer.test_ctrl_vif.clear_all();
        wait_probe_cycles(5);
    endtask
endclass
