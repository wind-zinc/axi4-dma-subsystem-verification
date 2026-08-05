class dma_subsys_memory_response_error_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_memory_response_error_vseq)

    function new(string name = "dma_subsys_memory_response_error_vseq");
        super.new(name);
    endfunction

    protected task run_response_error(
        input string case_name,
        input dma_channel_e source_ch,
        input dma_channel_e dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input logic [7:0] software_tag,
        input bit write_side,
        input int unsigned memory_index,
        input logic [1:0] response,
        input dma_error_e expected_error
    );
        initialize_region(source_address, 64, byte'(software_tag),
            $sformatf("%s source", case_name));
        publish_dma_intent($sformatf("%s_intent", case_name),
            source_ch, dest_ch, source_address, destination_address,
            64, software_tag, expected_error, 1'b1, 1'b1, 1'b1);
        program_dma(source_ch, dest_ch, source_address,
            destination_address, 64, software_tag);

        if (write_side) begin
            p_sequencer.test_ctrl_vif.forced_bresp[memory_index] = response;
            p_sequencer.test_ctrl_vif.force_bresp_enable[
                memory_index] = 1'b1;
        end else begin
            p_sequencer.test_ctrl_vif.forced_rresp[memory_index] = response;
            p_sequencer.test_ctrl_vif.force_rresp_enable[
                memory_index] = 1'b1;
        end
        set_channel_control(source_ch,
            1'b1, 1'b1, 1'b0, 1'b0,
            $sformatf("start %s", case_name));
        check_channel_error(source_ch, expected_error, 1'b0, case_name);
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
        wait_for_infrastructure();
        prepare_subsystem();

        run_response_error("read_slverr", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_5000,
            8'hD0, 1'b0, 0, 2'b10, DMA_ERR_AXI_RD_SLVERR);
        run_response_error("read_decerr", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_5000,
            8'hD1, 1'b0, 1, 2'b11, DMA_ERR_AXI_RD_DECERR);
        run_response_error("write_slverr", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_2000,
            RAM1_BASE_ADDR + 32'h0000_6000,
            8'hD2, 1'b1, 1, 2'b10, DMA_ERR_AXI_WR_SLVERR);
        run_response_error("write_decerr", DMA_CH1, DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_2000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            8'hD3, 1'b1, 0, 2'b11, DMA_ERR_AXI_WR_DECERR);

        p_sequencer.test_ctrl_vif.force_bresp_enable = '0;
        p_sequencer.test_ctrl_vif.force_rresp_enable = '0;
        wait_probe_cycles(5);
    endtask
endclass
