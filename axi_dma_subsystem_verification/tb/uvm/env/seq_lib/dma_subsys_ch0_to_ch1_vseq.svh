// First end-to-end subsystem scenario:
// EXT0 initializes RAM0, DMA CH0 routes data to CH1/RAM1, and EXT1 reads back.
class dma_subsys_ch0_to_ch1_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_ch0_to_ch1_vseq)

    localparam logic [AXI_ADDR_WIDTH-1:0] SOURCE_ADDRESS =
        RAM0_BASE_ADDR + 32'h0000_1000;
    localparam logic [AXI_ADDR_WIDTH-1:0] DESTINATION_ADDRESS =
        RAM1_BASE_ADDR + 32'h0000_1000;
    localparam int unsigned TRANSFER_BYTES = 64;
    localparam int unsigned TRANSFER_BEATS =
        TRANSFER_BYTES / AXI_STRB_WIDTH;
    localparam logic [7:0] SOFTWARE_TAG = 8'h31;

    function new(string name = "dma_subsys_ch0_to_ch1_vseq");
        super.new(name);
    endfunction

    protected function byte unsigned pattern_byte(input int unsigned index);
        return byte'(8'h35 + (index * 8'h17));
    endfunction

    protected function void build_payload(
        output bit [8*4096-1:0] payload
    );
        payload = '0;
        for (int unsigned index = 0;
                index < TRANSFER_BYTES; index++) begin
            payload[index*8 +: 8] = pattern_byte(index);
        end
    endfunction

    protected function void compare_payload(
        input bit [8*4096-1:0] expected,
        input bit [8*4096-1:0] actual,
        input string            operation
    );
        int unsigned mismatch_count;
        int unsigned first_index;

        mismatch_count = 0;
        first_index = 0;
        for (int unsigned index = 0;
                index < TRANSFER_BYTES; index++) begin
            if (actual[index*8 +: 8]
                    != expected[index*8 +: 8]) begin
                if (mismatch_count == 0) begin
                    first_index = index;
                end
                mismatch_count++;
            end
        end

        if (mismatch_count != 0) begin
            `uvm_error(
                "VSEQ_DATA",
                $sformatf(
                    "%s has %0d mismatches; first byte %0d expected=0x%02h actual=0x%02h",
                    operation, mismatch_count, first_index,
                    expected[first_index*8 +: 8],
                    actual[first_index*8 +: 8]))
        end
    endfunction

    protected task wait_for_completion();
        logic [31:0] irq_status;
        logic [31:0] fault_status;
        logic [31:0] last_error;

        for (int unsigned poll = 0;
                poll < p_sequencer.cfg.status_poll_limit; poll++) begin
            axil_read32(
                GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
                irq_status,
                "poll global IRQ status");

            if (irq_status[30]) begin
                axil_read32(
                    GLOBAL_IRQ_BASE_ADDR + REG_FAULT_STATUS,
                    fault_status,
                    "read global fault status");
                `uvm_fatal(
                    "VSEQ_FAULT",
                    $sformatf(
                        "Global fault while waiting for completion: 0x%08h",
                        fault_status))
                return;
            end
            if (irq_status[8]) begin
                axil_read32(
                    GLOBAL_IRQ_BASE_ADDR + REG_IRQ_LAST_ERROR,
                    last_error,
                    "read global last error");
                `uvm_fatal(
                    "VSEQ_DMA_ERROR",
                    $sformatf(
                        "CH0 error pending while waiting for completion: 0x%08h",
                        last_error))
                return;
            end
            if (irq_status[0] && !irq_status[16]) begin
                return;
            end

            wait_probe_cycles(2);
        end

        `uvm_fatal(
            "VSEQ_COMPLETION_TIMEOUT",
            $sformatf(
                "CH0 did not complete within %0d status polls",
                p_sequencer.cfg.status_poll_limit))
    endtask

    protected task wait_for_route_idle();
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if ((p_sequencer.probe_vif.mon_cb.busy == '0)
                    && (p_sequencer.probe_vif.mon_cb.route_active == '0)
                    && (p_sequencer.probe_vif.mon_cb.route_matrix == '0)) begin
                return;
            end
        end
        `uvm_fatal(
            "VSEQ_ROUTE_TIMEOUT",
            "DMA busy/route ownership did not return to idle")
    endtask

    virtual task body();
        dma_subsys_cmd_tr intent;
        bit [8*4096-1:0] source_payload;
        bit [8*4096-1:0] source_readback;
        bit [8*4096-1:0] destination_readback;
        xil_axi_resp_t [255:0] source_read_response;
        xil_axi_resp_t [255:0] destination_read_response;
        logic [31:0] register_value;

        wait_for_infrastructure();

        if ((TRANSFER_BYTES % AXI_STRB_WIDTH) != 0) begin
            `uvm_fatal(
                "VSEQ_CONFIG",
                "TRANSFER_BYTES must be a whole number of AXI beats")
            return;
        end
        if (TRANSFER_BEATS > AXI_MAX_BURST_LEN) begin
            `uvm_fatal(
                "VSEQ_CONFIG",
                "First end-to-end test must fit in one AXI burst")
            return;
        end

        build_payload(source_payload);

        // Start from a software-clean status while keeping CH0 enabled.
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303,
            "clear global IRQ/fault status");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0101,
            "enable CH0 done/error/fault IRQ");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "enable CH0 and clear channel status");

        // Establish expected source bytes through observed external AXI.
        external_write(
            DMA_MASTER_EXT0,
            SOURCE_ADDRESS,
            TRANSFER_BEATS,
            source_payload,
            "initialize RAM0 source");
        wait_probe_cycles(2);
        external_read(
            DMA_MASTER_EXT0,
            SOURCE_ADDRESS,
            TRANSFER_BEATS,
            source_readback,
            source_read_response,
            "read back RAM0 source");
        check_read_responses(
            source_read_response,
            TRANSFER_BEATS,
            "RAM0 source readback");
        compare_payload(
            source_payload,
            source_readback,
            "RAM0 source readback");

        intent = dma_subsys_cmd_tr::type_id::create("ch0_to_ch1_intent");
        intent.event_kind = DMA_CMD_INTENT;
        intent.source_ch = DMA_CH0;
        intent.dest_ch = DMA_CH1;
        intent.src_addr = SOURCE_ADDRESS;
        intent.dst_addr = DESTINATION_ADDRESS;
        intent.length = TRANSFER_BYTES;
        intent.sw_tag = SOFTWARE_TAG;
        intent.expect_accept = 1'b1;
        intent.expect_completion = 1'b1;
        intent.expect_irq = 1'b1;
        intent.expected_error = DMA_ERR_NONE;
        p_sequencer.publish_intent(intent);

        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            SOURCE_ADDRESS,
            "program CH0 source");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_DST_ADDR,
            DESTINATION_ADDRESS,
            "program CH0 destination");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_LENGTH,
            TRANSFER_BYTES,
            "program CH0 length");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_ROUTE,
            32'h0000_0001,
            "program CH0 to CH1 route");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_SW_TAG,
            {24'd0, SOFTWARE_TAG},
            "program CH0 software tag");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0005,
            "start CH0");

        wait_for_completion();
        wait_for_route_idle();
        wait_probe_cycles(1);

        if (!p_sequencer.probe_vif.mon_cb.global_irq
                || !p_sequencer.probe_vif.mon_cb.irq_ch[0]) begin
            `uvm_error(
                "VSEQ_IRQ",
                $sformatf(
                    "Expected CH0/global IRQ after completion, irq_ch=%0b irq=%0b",
                    p_sequencer.probe_vif.mon_cb.irq_ch,
                    p_sequencer.probe_vif.mon_cb.global_irq))
        end

        axil_read32(
            CH0_CTRL_BASE_ADDR + REG_STATUS,
            register_value,
            "read CH0 completion status");
        if (register_value[0]
                || !register_value[1]
                || register_value[2]
                || (register_value[15:8] != DMA_ERR_NONE)) begin
            `uvm_error(
                "VSEQ_CH_STATUS",
                $sformatf("Unexpected CH0 status 0x%08h", register_value))
        end

        axil_read32(
            CH0_CTRL_BASE_ADDR + REG_COMPLETED_LEN,
            register_value,
            "read CH0 completed length");
        if (register_value[LEN_WIDTH-1:0] != TRANSFER_BYTES) begin
            `uvm_error(
                "VSEQ_COMPLETED_LEN",
                $sformatf(
                    "Expected completed length %0d, got %0d",
                    TRANSFER_BYTES, register_value[LEN_WIDTH-1:0]))
        end

        axil_read32(
            CH0_CTRL_BASE_ADDR + REG_LAST_ERROR,
            register_value,
            "read CH0 last error");
        if (register_value[7:0] != DMA_ERR_NONE) begin
            `uvm_error(
                "VSEQ_LAST_ERROR",
                $sformatf("CH0 last error is 0x%02h",
                          register_value[7:0]))
        end

        external_read(
            DMA_MASTER_EXT1,
            DESTINATION_ADDRESS,
            TRANSFER_BEATS,
            destination_readback,
            destination_read_response,
            "read back RAM1 destination");
        check_read_responses(
            destination_read_response,
            TRANSFER_BEATS,
            "RAM1 destination readback");
        compare_payload(
            source_payload,
            destination_readback,
            "RAM1 destination readback");

        // Clear both software-visible status blocks and prove IRQ deassertion.
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h0000_0001,
            "clear CH0 global done pending");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "clear CH0 local completion status");
        wait_probe_cycles(2);

        axil_read32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
            register_value,
            "confirm global IRQ clear");
        if (register_value[0]
                || register_value[8]
                || p_sequencer.probe_vif.mon_cb.irq_ch[0]
                || p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error(
                "VSEQ_IRQ_CLEAR",
                $sformatf(
                    "IRQ did not clear: status=0x%08h irq_ch=%0b irq=%0b",
                    register_value,
                    p_sequencer.probe_vif.mon_cb.irq_ch,
                    p_sequencer.probe_vif.mon_cb.global_irq))
        end

        // Allow the adapter to publish the final external read before check.
        wait_probe_cycles(5);
        `uvm_info(
            "DMA_SUBSYS_CH0_TO_CH1_VSEQ",
            "Completed EXT0->RAM0, DMA CH0->CH1, RAM1->EXT1 end-to-end flow",
            UVM_LOW)
    endtask

endclass
