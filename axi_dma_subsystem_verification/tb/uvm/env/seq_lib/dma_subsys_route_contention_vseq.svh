class dma_subsys_route_contention_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_route_contention_vseq)

    function new(string name = "dma_subsys_route_contention_vseq");
        super.new(name);
    endfunction

    protected task wait_for_waiter();
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.route_req_valid[1]
                    && !p_sequencer.probe_vif.mon_cb.route_req_ready[1]) begin
                return;
            end
        end
        `uvm_fatal("ROUTE_CONTENTION_TIMEOUT",
            "CH1 never waited for CH0-owned destination CH0")
    endtask

    virtual task body();
        logic [31:0] status;

        wait_for_infrastructure();
        prepare_subsystem();
        initialize_region(RAM0_BASE_ADDR + 32'h0000_1000,
            1024, 8'h31, "contention owner source");
        initialize_region(RAM1_BASE_ADDR + 32'h0000_1000,
            256, 8'hA2, "contention waiter source");

        publish_dma_intent("contention_owner_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            1024, 8'h70);
        publish_dma_intent("contention_waiter_intent", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_7000,
            256, 8'h71);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            1024, 8'h70);
        program_dma(DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_7000,
            256, 8'h71);

        set_channel_control(DMA_CH0, 1'b1, 1'b1, 1'b0, 1'b0,
            "start route owner CH0");
        wait_channel_busy(DMA_CH0);
        set_channel_control(DMA_CH1, 1'b1, 1'b1, 1'b0, 1'b0,
            "start contending CH1");
        wait_for_waiter();
        // Hold the request long enough to close the long-wait bin even on a
        // fast simulator/memory configuration.
        wait_probe_cycles(8);

        wait_channel_done(DMA_CH0, status);
        if (status[15:8] != DMA_ERR_NONE) begin
            `uvm_error("ROUTE_OWNER_RESULT",
                $sformatf("owner status=0x%08h", status))
        end
        wait_channel_done(DMA_CH1, status);
        if (status[15:8] != DMA_ERR_NONE) begin
            `uvm_error("ROUTE_WAITER_RESULT",
                $sformatf("waiter status=0x%08h", status))
        end
        clear_channel_result(DMA_CH0);
        clear_channel_result(DMA_CH1);

        // A controlled two-cycle READY hold closes the short-wait bin without
        // depending on simulator scheduling around a previous completion.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_3000,
            32, 8'hC3, "short-wait source");
        publish_dma_intent("short_wait_intent", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_4000,
            32, 8'h72);
        program_dma(DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_4000,
            32, 8'h72);
        p_sequencer.test_ctrl_vif.force_route_ready_low[0] = 1'b1;
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start short-wait flow");
        do begin
            @(p_sequencer.probe_vif.mon_cb);
        end while (!p_sequencer.probe_vif.mon_cb.route_req_valid[0]);
        wait_probe_cycles(2);
        p_sequencer.test_ctrl_vif.force_route_ready_low[0] = 1'b0;
        wait_channel_done(DMA_CH0, status);
        clear_channel_result(DMA_CH0);
        wait_probe_cycles(5);
    endtask
endclass
