class dma_subsys_irq_mask_multi_pending_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_irq_mask_multi_pending_vseq)

    function new(string name = "dma_subsys_irq_mask_multi_pending_vseq");
        super.new(name);
    endfunction

    protected task start_and_wait(
        input string case_name,
        input dma_channel_e source_ch,
        input dma_channel_e dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input int unsigned byte_count,
        input logic [7:0] software_tag,
        input dma_error_e expected_error,
        input bit initialize_source
    );
        logic [31:0] status;

        if (initialize_source) begin
            initialize_region(source_address, byte_count,
                byte'(software_tag), $sformatf("%s source", case_name));
        end
        publish_dma_intent($sformatf("%s_intent", case_name),
            source_ch, dest_ch, source_address, destination_address,
            byte_count, software_tag, expected_error,
            1'b1, 1'b1, 1'b0);
        program_dma(source_ch, dest_ch, source_address,
            destination_address, byte_count, software_tag);
        set_channel_control(source_ch,
            1'b1, 1'b1, 1'b0, 1'b0,
            $sformatf("start %s", case_name));
        wait_channel_done(source_ch, status);
        if (status[15:8] != expected_error) begin
            `uvm_error("IRQ_CASE_RESULT",
                $sformatf("%s status=0x%08h", case_name, status))
        end
    endtask

    virtual task body();
        logic [31:0] irq_status;

        wait_for_infrastructure();
        prepare_subsystem(32'd0);

        // Sample every enable-mask shape before creating pending causes.
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000, "mask every IRQ cause");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0001, "enable CH0 done only");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0002, "enable CH1 done only");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0003, "enable both done causes");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0100, "enable CH0 error only");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0200, "enable CH1 error only");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0300, "enable both error causes");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0000, "enable global fault only");
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000, "return to all-masked state");

        start_and_wait("masked_done_ch0", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1200,
            RAM0_BASE_ADDR + 32'h0000_2200,
            32, 8'h91, DMA_ERR_NONE, 1'b1);
        start_and_wait("masked_done_ch1", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1200,
            RAM1_BASE_ADDR + 32'h0000_2200,
            32, 8'h92, DMA_ERR_NONE, 1'b1);
        if (p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error("IRQ_MASK_DONE", "masked done caused global IRQ")
        end
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0003, "unmask both pending done causes");
        wait_probe_cycles(2);

        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h0000_0003, "clear done pending bits");
        clear_channel_result(DMA_CH0);
        clear_channel_result(DMA_CH1);
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000, "mask errors before negative commands");

        start_and_wait("masked_error_ch0", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_3000,
            RAM0_BASE_ADDR + 32'h0000_3800,
            0, 8'h93, DMA_ERR_LEN_ZERO, 1'b0);
        start_and_wait("masked_error_ch1", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_3001,
            RAM1_BASE_ADDR + 32'h0000_3800,
            4, 8'h94, DMA_ERR_SRC_ALIGN, 1'b0);
        if (p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error("IRQ_MASK_ERROR", "masked error caused global IRQ")
        end

        // Add a masked manager fault, then enable error+fault together.  This
        // closes masked_pending and enabled_cause.multiple.
        p_sequencer.test_ctrl_vif.pulse_unexpected_rd_status(0);
        wait_probe_cycles(2);
        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0300, "unmask both errors and global fault");
        wait_probe_cycles(2);
        axil_read32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
            irq_status, "read multi-cause IRQ status");
        if (!irq_status[30] || (irq_status[9:8] != 2'b11)
                || !p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error("IRQ_MULTI_PENDING",
                $sformatf("unexpected IRQ status=0x%08h", irq_status))
        end

        axil_write32(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303, "clear every pending cause");
        clear_channel_result(DMA_CH0);
        clear_channel_result(DMA_CH1);
        wait_probe_cycles(5);
    endtask
endclass
