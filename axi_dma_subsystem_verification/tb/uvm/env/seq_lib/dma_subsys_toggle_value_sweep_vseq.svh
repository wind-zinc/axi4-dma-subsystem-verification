class dma_subsys_toggle_value_sweep_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_toggle_value_sweep_vseq)

    function new(string name = "dma_subsys_toggle_value_sweep_vseq");
        super.new(name);
    endfunction

    protected task run_response_toggle_case(
        input string                     case_name,
        input dma_channel_e              source_ch,
        input dma_channel_e              dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input logic [7:0]                software_tag,
        input bit                        write_side,
        input int unsigned               memory_index,
        input logic [1:0]                response,
        input dma_error_e                expected_error
    );
        initialize_region(
            source_address,
            64,
            byte'(software_tag),
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            source_ch,
            dest_ch,
            source_address,
            destination_address,
            64,
            software_tag,
            expected_error,
            1'b1,
            1'b1,
            1'b1);
        program_dma(
            source_ch,
            dest_ch,
            source_address,
            destination_address,
            64,
            software_tag);

        if (write_side) begin
            p_sequencer.test_ctrl_vif.forced_bresp[memory_index] = response;
            p_sequencer.test_ctrl_vif.force_bresp_enable[
                memory_index] = 1'b1;
        end else begin
            p_sequencer.test_ctrl_vif.forced_rresp[memory_index] = response;
            p_sequencer.test_ctrl_vif.force_rresp_enable[
                memory_index] = 1'b1;
        end
        set_channel_control(
            source_ch,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        check_channel_error(
            source_ch,
            expected_error,
            1'b0,
            case_name);
        wait_probe_cycles(2);
        if (write_side) begin
            p_sequencer.test_ctrl_vif.force_bresp_enable[
                memory_index] = 1'b0;
        end else begin
            p_sequencer.test_ctrl_vif.force_rresp_enable[
                memory_index] = 1'b0;
        end
        wait_probe_cycles(2);
        clear_channel_result(source_ch);
    endtask

    virtual task body();
        int unsigned lengths[6];
        logic [31:0] offsets[6];
        logic [7:0] tags[6];
        dma_channel_e source_ch;
        dma_channel_e dest_ch;
        logic [31:0] source_base;
        logic [31:0] destination_base;

        lengths = '{4, 128, 256, 1024, 2048, 32768};
        offsets = '{
            32'h0000_0004,
            32'h0000_0080,
            32'h0000_0100,
            32'h0000_0800,
            32'h0000_2000,
            32'h0000_4000};
        tags = '{8'h00, 8'hFF, 8'hA5, 8'h5A, 8'h3C, 8'hC3};

        wait_for_infrastructure();
        prepare_subsystem();

        // Exercise low/high patterns in tag, length, and legal RAM address
        // fields.  The final 32-KiB transfer toggles upper legal length bits.
        foreach (lengths[index]) begin
            source_ch = index[0] ? DMA_CH1 : DMA_CH0;
            dest_ch = index[1] ? DMA_CH1 : DMA_CH0;
            source_base = index[0] ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
            destination_base =
                index[0] ? RAM0_BASE_ADDR : RAM1_BASE_ADDR;
            run_dma_case(
                $sformatf(
                    "toggle_len_%0d_tag_%02h",
                    lengths[index],
                    tags[index]),
                source_ch,
                dest_ch,
                source_base + offsets[index],
                destination_base + offsets[index],
                lengths[index],
                tags[index],
                byte'(8'h20 + (index * 8'h13)));
        end

        // Complement the existing response-error test so response bit zero
        // toggles on both read targets and both write targets.
        run_response_toggle_case(
            "toggle_read_decerr_mem0",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_0100,
            RAM1_BASE_ADDR + 32'h0000_C100,
            8'h81,
            1'b0,
            0,
            2'b11,
            DMA_ERR_AXI_RD_DECERR);
        run_response_toggle_case(
            "toggle_read_slverr_mem1",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_0200,
            RAM0_BASE_ADDR + 32'h0000_C200,
            8'h42,
            1'b0,
            1,
            2'b10,
            DMA_ERR_AXI_RD_SLVERR);
        run_response_toggle_case(
            "toggle_write_slverr_mem0",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_0300,
            RAM0_BASE_ADDR + 32'h0000_C300,
            8'h24,
            1'b1,
            0,
            2'b10,
            DMA_ERR_AXI_WR_SLVERR);
        run_response_toggle_case(
            "toggle_write_decerr_mem1",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_0400,
            RAM1_BASE_ADDR + 32'h0000_C400,
            8'h18,
            1'b1,
            1,
            2'b11,
            DMA_ERR_AXI_WR_DECERR);

        // Return completion/error buses to the all-zero semantic state.
        run_dma_case(
            "toggle_final_clean",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_D000,
            RAM0_BASE_ADDR + 32'h0000_D800,
            64,
            8'h00,
            8'h73);

        p_sequencer.test_ctrl_vif.force_bresp_enable = '0;
        p_sequencer.test_ctrl_vif.force_rresp_enable = '0;
        wait_probe_cycles(5);
    endtask
endclass
