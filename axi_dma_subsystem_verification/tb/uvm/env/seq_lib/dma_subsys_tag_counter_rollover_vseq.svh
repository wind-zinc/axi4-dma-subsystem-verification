// Drives enough accepted commands to toggle the complete seven-bit hardware
// tag sequence and the practically reachable low byte of all 32-bit command,
// done, and error counters.  LEN_ZERO makes every command deterministic and
// short while still exercising the normal register-to-manager handshake.
class dma_subsys_tag_counter_rollover_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_tag_counter_rollover_vseq)

    localparam int unsigned COMMANDS_PER_CHANNEL = 129;

    function new(string name = "dma_subsys_tag_counter_rollover_vseq");
        super.new(name);
    endfunction

    protected task run_zero_length_command(
        input dma_channel_e channel,
        input int unsigned  command_index
    );
        dma_channel_e destination_channel;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        logic [7:0] software_tag;
        string case_name;

        destination_channel = command_index[0] ? DMA_CH1 : DMA_CH0;
        software_tag = command_index[0] ? 8'h55 : 8'hAA;

        // The first two commands use complementary full-width patterns so
        // cmd_payload/cmd_reg address bits toggle even though validation ends
        // at LEN_ZERO before a memory descriptor is issued.
        if (command_index[0]) begin
            source_address = 32'h5555_5554;
            destination_address = 32'hAAAA_AAAC;
        end else begin
            source_address = 32'hAAAA_AAAC;
            destination_address = 32'h5555_5554;
        end

        case_name = $sformatf(
            "%s_zero_length_rollover_%0d",
            dma_channel_name(channel), command_index);
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            destination_channel,
            source_address,
            destination_address,
            0,
            software_tag,
            DMA_ERR_LEN_ZERO);
        program_dma(
            channel,
            destination_channel,
            source_address,
            destination_address,
            0,
            software_tag);
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        check_channel_error(
            channel,
            DMA_ERR_LEN_ZERO,
            1'b0,
            case_name);
        clear_channel_result(channel);
    endtask

    protected task check_counter(
        input logic [31:0] address,
        input logic [31:0] expected,
        input string       operation
    );
        logic [31:0] value;

        axil_read32(address, value, operation);
        if (value != expected) begin
            `uvm_error(
                "COUNTER_ROLLOVER_VALUE",
                $sformatf(
                    "%s expected %0d (0x%08h), observed %0d (0x%08h)",
                    operation, expected, expected, value, value))
        end
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        for (int unsigned index = 0;
                index < COMMANDS_PER_CHANNEL; index++) begin
            run_zero_length_command(DMA_CH0, index);
        end
        for (int unsigned index = 0;
                index < COMMANDS_PER_CHANNEL; index++) begin
            run_zero_length_command(DMA_CH1, index);
        end

        check_counter(
            CH0_CTRL_BASE_ADDR + REG_CMD_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH0 command count after tag rollover");
        check_counter(
            CH1_CTRL_BASE_ADDR + REG_CMD_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH1 command count after tag rollover");
        check_counter(
            CH0_CTRL_BASE_ADDR + REG_DONE_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH0 completion count after tag rollover");
        check_counter(
            CH1_CTRL_BASE_ADDR + REG_DONE_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH1 completion count after tag rollover");
        check_counter(
            GLOBAL_IRQ_BASE_ADDR + REG_CH0_ERROR_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH0 global error count after tag rollover");
        check_counter(
            GLOBAL_IRQ_BASE_ADDR + REG_CH1_ERROR_COUNT,
            COMMANDS_PER_CHANNEL,
            "CH1 global error count after tag rollover");

        // Reset supplies the falling edge for every reached tag/counter bit.
        p_sequencer.test_ctrl_vif.pulse_reset(12);
        wait_for_infrastructure();
        wait_probe_cycles(5);
    endtask
endclass
