class dma_subsys_descriptor_error_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_descriptor_error_vseq)

    function new(string name = "dma_subsys_descriptor_error_vseq");
        super.new(name);
    endfunction

    protected task check_rejected_error(
        input dma_channel_e channel,
        input dma_error_e expected_error,
        input string operation
    );
        logic [31:0] value;
        wait_probe_cycles(2);
        axil_read32(channel_base(channel) + REG_LAST_ERROR,
            value, operation);
        if (value[7:0] != expected_error) begin
            `uvm_error("REJECTED_ERROR",
                $sformatf("%s expected 0x%02h got 0x%02h",
                    operation, expected_error, value[7:0]))
        end
    endtask

    virtual task body();
        logic [31:0] status;

        wait_for_infrastructure();
        prepare_subsystem();

        run_dma_case("length_zero", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_2000,
            0, 8'hA0, 8'h10, DMA_ERR_LEN_ZERO, 1'b0);
        run_dma_case("source_alignment", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1001,
            RAM1_BASE_ADDR + 32'h0000_2000,
            16, 8'hA1, 8'h11, DMA_ERR_SRC_ALIGN, 1'b0);
        run_dma_case("destination_alignment", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_2001,
            16, 8'hA2, 8'h12, DMA_ERR_DST_ALIGN, 1'b0);
        run_dma_case("source_range", DMA_CH1, DMA_CH0,
            RAM0_END_ADDR - 32'd3,
            RAM0_BASE_ADDR + 32'h0000_2000,
            8, 8'hA3, 8'h13, DMA_ERR_SRC_RANGE, 1'b0);
        run_dma_case("destination_range", DMA_CH0, DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM1_END_ADDR - 32'd3,
            8, 8'hA4, 8'h14, DMA_ERR_DST_RANGE, 1'b0);
        run_dma_case("overlap", DMA_CH1, DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_3000,
            RAM1_BASE_ADDR + 32'h0000_3004,
            32, 8'hA5, 8'h15, DMA_ERR_OVERLAP, 1'b0);

        // Disabled start is rejected in dma_ctrl_regs and never reaches the
        // manager's command handshake.
        set_channel_control(DMA_CH0,
            1'b0, 1'b0, 1'b0, 1'b1, "disable and clear CH0");
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_4000,
            RAM0_BASE_ADDR + 32'h0000_5000,
            64, 8'hA6);
        publish_dma_intent("disabled_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_4000,
            RAM0_BASE_ADDR + 32'h0000_5000,
            64, 8'hA6, DMA_ERR_DISABLED, 1'b0, 1'b0, 1'b0);
        set_channel_control(DMA_CH0,
            1'b0, 1'b1, 1'b0, 1'b0, "start disabled CH0");
        check_rejected_error(DMA_CH0, DMA_ERR_DISABLED,
            "check disabled rejection");
        set_channel_control(DMA_CH0,
            1'b1, 1'b0, 1'b0, 1'b1, "re-enable CH0");

        // Keep one accepted transfer active, then issue a second start while
        // busy.  The second intent is coverage-only and must not be queued by
        // the scoreboard.
        initialize_region(RAM0_BASE_ADDR + 32'h0000_6000,
            1024, 8'hC1, "busy owner source");
        publish_dma_intent("busy_owner_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_7000,
            1024, 8'hA7);
        program_dma(DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_7000,
            1024, 8'hA7);
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "start busy owner");
        wait_channel_busy(DMA_CH0);
        publish_dma_intent("busy_rejected_intent", DMA_CH0, DMA_CH0,
            RAM0_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_7000,
            1024, 8'hA7, DMA_ERR_BUSY, 1'b0, 1'b0, 1'b0);
        set_channel_control(DMA_CH0,
            1'b1, 1'b1, 1'b0, 1'b0, "repeat start while busy");
        check_rejected_error(DMA_CH0, DMA_ERR_BUSY,
            "check busy rejection");
        wait_channel_done(DMA_CH0, status);
        clear_channel_result(DMA_CH0);
        wait_probe_cycles(5);
    endtask
endclass
