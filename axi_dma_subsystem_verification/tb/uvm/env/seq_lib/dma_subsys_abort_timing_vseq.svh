class dma_subsys_abort_timing_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_abort_timing_vseq)

    function new(string name = "dma_subsys_abort_timing_vseq");
        super.new(name);
    endfunction

    protected task wait_for_route_wait(input int unsigned channel);
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.route_req_valid[channel]
                    && !p_sequencer.probe_vif.mon_cb.route_req_ready[
                        channel]) begin
                return;
            end
        end
        `uvm_fatal("ABORT_ROUTE_WAIT", "route waiter was not observed")
    endtask

    virtual task body();
        logic [31:0] status;

        wait_for_infrastructure();
        prepare_subsystem();

        // Abort after descriptors have entered the DMA engines.  The design
        // cannot cancel an in-flight vendor DMA, so it completes with the
        // explicit ABORT_INFLIGHT_UNSUPPORTED result.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_0800,
            1024, 8'h19, "inflight-abort source");
        publish_dma_intent("abort_inflight_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_0800,
            RAM0_BASE_ADDR + 32'h0000_5000,
            1024, 8'hB0, DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED,
            1'b1, 1'b1, 1'b1);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_0800,
            RAM0_BASE_ADDR + 32'h0000_5000,
            1024, 8'hB0);
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start inflight-abort flow");
        wait_channel_busy(DMA_CH0);
        wait_probe_cycles(8);
        set_channel_control(DMA_CH0,
            1'b1, 1'b0, 1'b1, 1'b0, "abort in-flight CH0");
        check_channel_error(DMA_CH0,
            DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED, 1'b1,
            "inflight abort");
        clear_channel_result(DMA_CH0);

        // CH0 owns destination route 0.  CH1 is accepted but blocked in
        // WAIT_ROUTE, giving a deterministic pre-descriptor abort window.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_1000,
            1024, 8'h2A, "pending-abort route owner");
        initialize_region(RAM1_BASE_ADDR + 32'h0000_1000,
            64, 8'h3B, "pending-abort waiter");
        publish_dma_intent("abort_owner_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            1024, 8'hB1);
        publish_dma_intent("abort_pending_intent", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_6000,
            64, 8'hB2, DMA_ERR_ABORT_PENDING,
            1'b1, 1'b1, 1'b1);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            1024, 8'hB1);
        program_dma(DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_6000,
            64, 8'hB2);
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start route owner");
        wait_channel_busy(DMA_CH0);
        set_channel_control(DMA_CH1,
            1'b1, 1'b1, 1'b0, 1'b0, "start route waiter");
        wait_for_route_wait(1);
        set_channel_control(DMA_CH1,
            1'b1, 1'b0, 1'b1, 1'b0, "abort pending CH1");
        check_channel_error(DMA_CH1,
            DMA_ERR_ABORT_PENDING, 1'b1, "pending abort");
        wait_channel_done(DMA_CH0, status);
        if (status[15:8] != DMA_ERR_NONE) begin
            `uvm_error("ABORT_OWNER", $sformatf("status=0x%08h", status))
        end
        clear_channel_result(DMA_CH0);
        clear_channel_result(DMA_CH1);
        wait_probe_cycles(5);
    endtask
endclass
