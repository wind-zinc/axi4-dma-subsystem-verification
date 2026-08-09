// Completes a legal status-producing hardware-tag sweep.  The older counter
// rollover sequence intentionally uses zero-length commands, which increments
// manager tags but cannot exercise descriptor/status tag buses.
class dma_subsys_legal_tag_rollover_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_legal_tag_rollover_vseq)

    localparam int unsigned COMMANDS_PER_CHANNEL = 65;
    localparam int unsigned RESET_HOLD_CYCLES = 20;

    function new(string name = "dma_subsys_legal_tag_rollover_vseq");
        super.new(name);
    endfunction

    protected task run_channel_rollover(
        input dma_channel_e channel
    );
        dma_channel_e destination_channel;
        logic [31:0] source_address;
        logic [31:0] destination_address;

        if (channel == DMA_CH0) begin
            destination_channel = DMA_CH1;
            source_address = RAM0_BASE_ADDR + 32'h0000_0100;
            destination_address = RAM1_BASE_ADDR + 32'h0000_0200;
        end else begin
            destination_channel = DMA_CH0;
            source_address = RAM1_BASE_ADDR + 32'h0000_0300;
            destination_address = RAM0_BASE_ADDR + 32'h0000_0400;
        end

        initialize_region(
            source_address,
            4,
            (channel == DMA_CH0) ? 8'h3C : 8'hC3,
            $sformatf("%s legal tag source", dma_channel_name(channel)));

        for (int unsigned command_index = 0;
                command_index < COMMANDS_PER_CHANNEL;
                command_index++) begin
            run_dma_case(
                $sformatf(
                    "%s_legal_tag_%0d",
                    dma_channel_name(channel),
                    command_index),
                channel,
                destination_channel,
                source_address,
                destination_address,
                4,
                byte'(command_index),
                byte'(8'h40 + command_index),
                DMA_ERR_NONE,
                1'b0);
        end
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // Reaching accepted command index 64 raises tag_seq_reg[6].
        // Lower bits toggle naturally while counting; reset supplies the
        // final falling edge for bit 6 and both owner-tag lanes.
        run_channel_rollover(DMA_CH0);
        run_channel_rollover(DMA_CH1);

        p_sequencer.test_ctrl_vif.pulse_reset(RESET_HOLD_CYCLES);
        wait_for_infrastructure();
        p_sequencer.test_ctrl_vif.clear_all();
        wait_probe_cycles(5);
    endtask
endclass
