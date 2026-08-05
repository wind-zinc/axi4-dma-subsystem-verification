class dma_subsys_completion_order_reverse_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_completion_order_reverse_vseq)

    function new(string name = "dma_subsys_completion_order_reverse_vseq");
        super.new(name);
    endfunction

    virtual task body();
        dma_channel_e observed_order[DMA_CH_COUNT];
        bit seen[DMA_CH_COUNT];
        int unsigned observed_count;
        logic [31:0] status;

        wait_for_infrastructure();
        prepare_subsystem();
        initialize_region(RAM1_BASE_ADDR + 32'h0000_2000,
            256, 8'h91, "slow CH1 source");
        initialize_region(RAM0_BASE_ADDR + 32'h0000_2000,
            4, 8'hE2, "fast CH0 source");
        publish_dma_intent("slow_ch1_intent", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_2000,
            RAM1_BASE_ADDR + 32'h0000_3000,
            256, 8'h81);
        publish_dma_intent("fast_ch0_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_2000,
            RAM0_BASE_ADDR + 32'h0000_3000,
            4, 8'h82);
        program_dma(DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_2000,
            RAM1_BASE_ADDR + 32'h0000_3000,
            256, 8'h81);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_2000,
            RAM0_BASE_ADDR + 32'h0000_3000,
            4, 8'h82);

        foreach (seen[index]) begin
            seen[index] = 1'b0;
            observed_order[index] = DMA_CH_UNKNOWN;
        end
        observed_count = 0;
        fork
            begin : observe_completions
                for (int unsigned cycle = 0;
                        cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
                    @(p_sequencer.probe_vif.mon_cb);
                    for (int channel = 0;
                            channel < DMA_CH_COUNT; channel++) begin
                        if (p_sequencer.probe_vif.mon_cb.completion_valid[
                                channel] && !seen[channel]) begin
                            seen[channel] = 1'b1;
                            observed_order[observed_count] =
                                dma_channel_e'(channel);
                            observed_count++;
                        end
                    end
                    if (observed_count == DMA_CH_COUNT) break;
                end
            end
            begin : issue_in_reverse_order
                set_channel_control(DMA_CH1,
                    1'b1, 1'b1, 1'b0, 1'b0, "issue slow CH1 first");
                wait_channel_busy(DMA_CH1);
                set_channel_control(DMA_CH0,
                    1'b1, 1'b1, 1'b0, 1'b0, "issue fast CH0 second");
            end
        join

        if ((observed_count != 2)
                || (observed_order[0] != DMA_CH0)
                || (observed_order[1] != DMA_CH1)) begin
            `uvm_error("REVERSE_REORDER",
                $sformatf("expected CH0 then CH1, count=%0d order=%0d,%0d",
                    observed_count, observed_order[0], observed_order[1]))
        end
        wait_channel_done(DMA_CH0, status);
        wait_channel_done(DMA_CH1, status);
        clear_channel_result(DMA_CH0);
        clear_channel_result(DMA_CH1);
        wait_probe_cycles(5);
    endtask
endclass
