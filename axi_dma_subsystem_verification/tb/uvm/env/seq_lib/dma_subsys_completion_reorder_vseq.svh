// Deterministic cross-channel completion reordering scenario.
//
// CH0 is issued first and transfers 64 bytes entirely through delayed MEM0.
// CH1 is issued second and transfers one beat through zero-delay MEM1.
// The expected system-level result is CH1 completion before CH0 completion.
//
// This verifies independent DMA-flow ordering.  It does not claim AXI
// response reordering within one DMA master; the current DMA engines use a
// fixed AXI ID and accept only one active command per channel.
class dma_subsys_completion_reorder_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_completion_reorder_vseq)

    localparam logic [AXI_ADDR_WIDTH-1:0] SLOW_SOURCE_ADDRESS =
        RAM0_BASE_ADDR + 32'h0000_2000;
    localparam logic [AXI_ADDR_WIDTH-1:0] SLOW_DESTINATION_ADDRESS =
        RAM0_BASE_ADDR + 32'h0000_3000;
    localparam int unsigned SLOW_TRANSFER_BYTES = 64;
    localparam int unsigned SLOW_TRANSFER_BEATS =
        SLOW_TRANSFER_BYTES / AXI_STRB_WIDTH;
    localparam logic [7:0] SLOW_SOFTWARE_TAG = 8'hA0;

    localparam logic [AXI_ADDR_WIDTH-1:0] FAST_SOURCE_ADDRESS =
        RAM1_BASE_ADDR + 32'h0000_2000;
    localparam logic [AXI_ADDR_WIDTH-1:0] FAST_DESTINATION_ADDRESS =
        RAM1_BASE_ADDR + 32'h0000_3000;
    localparam int unsigned FAST_TRANSFER_BYTES = AXI_STRB_WIDTH;
    localparam int unsigned FAST_TRANSFER_BEATS =
        FAST_TRANSFER_BYTES / AXI_STRB_WIDTH;
    localparam logic [7:0] FAST_SOFTWARE_TAG = 8'hB1;

    function new(
        string name = "dma_subsys_completion_reorder_vseq"
    );
        super.new(name);
    endfunction

    protected function void build_payload(
        output bit [8*4096-1:0] payload,
        input int unsigned      byte_count,
        input byte unsigned     seed,
        input byte unsigned     step
    );
        payload = '0;
        for (int unsigned index = 0; index < byte_count; index++) begin
            payload[index*8 +: 8] = byte'(seed + (index * step));
        end
    endfunction

    protected function void compare_payload(
        input bit [8*4096-1:0] expected,
        input bit [8*4096-1:0] actual,
        input int unsigned      byte_count,
        input string            operation
    );
        int unsigned mismatch_count;
        int unsigned first_index;

        mismatch_count = 0;
        first_index = 0;
        for (int unsigned index = 0; index < byte_count; index++) begin
            if (actual[index*8 +: 8] != expected[index*8 +: 8]) begin
                if (mismatch_count == 0) begin
                    first_index = index;
                end
                mismatch_count++;
            end
        end

        if (mismatch_count != 0) begin
            `uvm_error(
                "REORDER_DATA",
                $sformatf(
                    "%s has %0d mismatches; first byte %0d expected=0x%02h actual=0x%02h",
                    operation,
                    mismatch_count,
                    first_index,
                    expected[first_index*8 +: 8],
                    actual[first_index*8 +: 8]))
        end
    endfunction

    protected function dma_subsys_cmd_tr make_intent(
        input string                         name,
        input dma_channel_e                  source_ch,
        input dma_channel_e                  dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0]     source_address,
        input logic [AXI_ADDR_WIDTH-1:0]     destination_address,
        input int unsigned                   byte_count,
        input logic [7:0]                    software_tag
    );
        dma_subsys_cmd_tr intent;

        intent = dma_subsys_cmd_tr::type_id::create(name);
        intent.event_kind = DMA_CMD_INTENT;
        intent.source_ch = source_ch;
        intent.dest_ch = dest_ch;
        intent.src_addr = source_address;
        intent.dst_addr = destination_address;
        intent.length = byte_count;
        intent.sw_tag = software_tag;
        intent.expect_accept = 1'b1;
        intent.expect_completion = 1'b1;
        intent.expect_irq = 1'b1;
        intent.expected_error = DMA_ERR_NONE;
        return intent;
    endfunction

    protected task program_channel(
        input logic [AXIL_ADDR_WIDTH-1:0] channel_base,
        input logic [AXI_ADDR_WIDTH-1:0]  source_address,
        input logic [AXI_ADDR_WIDTH-1:0]  destination_address,
        input int unsigned                byte_count,
        input dma_channel_e               destination_channel,
        input logic [7:0]                 software_tag,
        input string                      channel_name
    );
        axil_write32(
            channel_base + REG_SRC_ADDR,
            source_address,
            $sformatf("program %s source", channel_name));
        axil_write32(
            channel_base + REG_DST_ADDR,
            destination_address,
            $sformatf("program %s destination", channel_name));
        axil_write32(
            channel_base + REG_LENGTH,
            byte_count,
            $sformatf("program %s length", channel_name));
        axil_write32(
            channel_base + REG_ROUTE,
            (destination_channel == DMA_CH1) ? 32'd1 : 32'd0,
            $sformatf("program %s route", channel_name));
        axil_write32(
            channel_base + REG_SW_TAG,
            {24'd0, software_tag},
            $sformatf("program %s software tag", channel_name));
    endtask

    protected task wait_for_channel_busy(
        input int unsigned channel
    );
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.busy[channel]) begin
                return;
            end
        end

        `uvm_fatal(
            "REORDER_BUSY_TIMEOUT",
            $sformatf(
                "CH%0d did not become busy after start",
                channel))
    endtask

    protected task wait_for_all_routes_idle();
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
            "REORDER_IDLE_TIMEOUT",
            "Both channels did not return to idle")
    endtask

    protected task check_channel_result(
        input logic [AXIL_ADDR_WIDTH-1:0] channel_base,
        input int unsigned                expected_length,
        input string                      channel_name
    );
        logic [31:0] value;

        axil_read32(
            channel_base + REG_STATUS,
            value,
            $sformatf("read %s status", channel_name));
        if (value[0]
                || !value[1]
                || value[2]
                || (value[15:8] != DMA_ERR_NONE)) begin
            `uvm_error(
                "REORDER_STATUS",
                $sformatf(
                    "%s unexpected status 0x%08h",
                    channel_name,
                    value))
        end

        axil_read32(
            channel_base + REG_COMPLETED_LEN,
            value,
            $sformatf("read %s completed length", channel_name));
        if (value[LEN_WIDTH-1:0] != expected_length) begin
            `uvm_error(
                "REORDER_LENGTH",
                $sformatf(
                    "%s expected length %0d got %0d",
                    channel_name,
                    expected_length,
                    value[LEN_WIDTH-1:0]))
        end

        axil_read32(
            channel_base + REG_LAST_ERROR,
            value,
            $sformatf("read %s last error", channel_name));
        if (value[7:0] != DMA_ERR_NONE) begin
            `uvm_error(
                "REORDER_LAST_ERROR",
                $sformatf(
                    "%s last error is 0x%02h",
                    channel_name,
                    value[7:0]))
        end
    endtask

    virtual task body();
        dma_subsys_cmd_tr slow_intent;
        dma_subsys_cmd_tr fast_intent;
        bit [8*4096-1:0] slow_payload;
        bit [8*4096-1:0] fast_payload;
        bit [8*4096-1:0] slow_readback;
        bit [8*4096-1:0] fast_readback;
        xil_axi_resp_t [255:0] slow_read_response;
        xil_axi_resp_t [255:0] fast_read_response;
        dma_channel_e completion_order[DMA_CH_COUNT];
        bit completion_seen[DMA_CH_COUNT];
        int unsigned completion_count;
        logic [31:0] irq_status;

        wait_for_infrastructure();

        build_payload(
            slow_payload,
            SLOW_TRANSFER_BYTES,
            8'h21,
            8'h0D);
        build_payload(
            fast_payload,
            FAST_TRANSFER_BYTES,
            8'hC3,
            8'h07);

        // Start from clean software-visible state and enable both channels.
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303,
            "clear both channel IRQs and global fault");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0303,
            "enable both done/error IRQs and global fault IRQ");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "enable CH0 and clear local status");
        axil_write32(
            CH1_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "enable CH1 and clear local status");

        // Observed external writes establish independent reference memory.
        external_write(
            DMA_MASTER_EXT0,
            SLOW_SOURCE_ADDRESS,
            SLOW_TRANSFER_BEATS,
            slow_payload,
            "initialize delayed RAM0 source");
        external_write(
            DMA_MASTER_EXT1,
            FAST_SOURCE_ADDRESS,
            FAST_TRANSFER_BEATS,
            fast_payload,
            "initialize fast RAM1 source");
        wait_probe_cycles(2);

        slow_intent = make_intent(
            "slow_ch0_intent",
            DMA_CH0,
            DMA_CH0,
            SLOW_SOURCE_ADDRESS,
            SLOW_DESTINATION_ADDRESS,
            SLOW_TRANSFER_BYTES,
            SLOW_SOFTWARE_TAG);
        fast_intent = make_intent(
            "fast_ch1_intent",
            DMA_CH1,
            DMA_CH1,
            FAST_SOURCE_ADDRESS,
            FAST_DESTINATION_ADDRESS,
            FAST_TRANSFER_BYTES,
            FAST_SOFTWARE_TAG);

        p_sequencer.publish_intent(slow_intent);
        p_sequencer.publish_intent(fast_intent);

        program_channel(
            CH0_CTRL_BASE_ADDR,
            SLOW_SOURCE_ADDRESS,
            SLOW_DESTINATION_ADDRESS,
            SLOW_TRANSFER_BYTES,
            DMA_CH0,
            SLOW_SOFTWARE_TAG,
            "CH0");
        program_channel(
            CH1_CTRL_BASE_ADDR,
            FAST_SOURCE_ADDRESS,
            FAST_DESTINATION_ADDRESS,
            FAST_TRANSFER_BYTES,
            DMA_CH1,
            FAST_SOFTWARE_TAG,
            "CH1");

        foreach (completion_seen[channel]) begin
            completion_seen[channel] = 1'b0;
            completion_order[channel] = DMA_CH_UNKNOWN;
        end
        completion_count = 0;

        // Start observing before either command is issued so a very short
        // CH1 flow cannot complete between the AXI-Lite start write and the
        // first completion sample.
        fork
            begin : completion_observer
                for (int unsigned cycle = 0;
                        cycle < p_sequencer.cfg.status_poll_limit;
                        cycle++) begin
                    @(p_sequencer.probe_vif.mon_cb);

                    for (int channel = 0;
                            channel < DMA_CH_COUNT; channel++) begin
                        if (p_sequencer.probe_vif.mon_cb.completion_valid[
                                channel]
                                && !completion_seen[channel]) begin
                            completion_seen[channel] = 1'b1;
                            completion_order[completion_count] =
                                dma_channel_e'(channel);
                            completion_count++;
                        end
                    end

                    if (completion_count == DMA_CH_COUNT) begin
                        break;
                    end
                end
            end
            begin : ordered_stimulus
                // CH0 must be accepted and busy before the later CH1 issue.
                axil_write32(
                    CH0_CTRL_BASE_ADDR + REG_CTRL,
                    32'h0000_0005,
                    "start delayed CH0 flow");
                wait_for_channel_busy(0);

                axil_write32(
                    CH1_CTRL_BASE_ADDR + REG_CTRL,
                    32'h0000_0005,
                    "start fast CH1 flow");
            end
        join

        if (completion_count != DMA_CH_COUNT) begin
            `uvm_fatal(
                "REORDER_COMPLETION_TIMEOUT",
                $sformatf(
                    "Observed %0d/%0d channel completions",
                    completion_count,
                    DMA_CH_COUNT))
        end

        if ((completion_order[0] != DMA_CH1)
                || (completion_order[1] != DMA_CH0)) begin
            `uvm_error(
                "REORDER_NOT_OBSERVED",
                $sformatf(
                    "Expected CH1 then CH0 completion, observed %s then %s",
                    dma_channel_name(completion_order[0]),
                    dma_channel_name(completion_order[1])))
        end else begin
            `uvm_info(
                "REORDER_OBSERVED",
                "CH0 was issued first, CH1 was issued second, and CH1 completed first",
                UVM_LOW)
        end

        wait_for_all_routes_idle();
        wait_probe_cycles(2);

        check_channel_result(
            CH0_CTRL_BASE_ADDR,
            SLOW_TRANSFER_BYTES,
            "CH0");
        check_channel_result(
            CH1_CTRL_BASE_ADDR,
            FAST_TRANSFER_BYTES,
            "CH1");

        axil_read32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
            irq_status,
            "read both-channel IRQ status");
        if ((irq_status[1:0] != 2'b11)
                || (irq_status[9:8] != 2'b00)
                || (irq_status[17:16] != 2'b00)
                || irq_status[30]
                || (p_sequencer.probe_vif.mon_cb.irq_ch != 2'b11)
                || !p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error(
                "REORDER_IRQ",
                $sformatf(
                    "Unexpected post-completion IRQ state status=0x%08h irq_ch=%0b irq=%0b",
                    irq_status,
                    p_sequencer.probe_vif.mon_cb.irq_ch,
                    p_sequencer.probe_vif.mon_cb.global_irq))
        end

        external_read(
            DMA_MASTER_EXT0,
            SLOW_DESTINATION_ADDRESS,
            SLOW_TRANSFER_BEATS,
            slow_readback,
            slow_read_response,
            "read delayed RAM0 destination");
        check_read_responses(
            slow_read_response,
            SLOW_TRANSFER_BEATS,
            "delayed RAM0 destination");
        compare_payload(
            slow_payload,
            slow_readback,
            SLOW_TRANSFER_BYTES,
            "delayed RAM0 destination");

        external_read(
            DMA_MASTER_EXT1,
            FAST_DESTINATION_ADDRESS,
            FAST_TRANSFER_BEATS,
            fast_readback,
            fast_read_response,
            "read fast RAM1 destination");
        check_read_responses(
            fast_read_response,
            FAST_TRANSFER_BEATS,
            "fast RAM1 destination");
        compare_payload(
            fast_payload,
            fast_readback,
            FAST_TRANSFER_BYTES,
            "fast RAM1 destination");

        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303,
            "clear both channel IRQs and fault status");
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "clear CH0 local status");
        axil_write32(
            CH1_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0014,
            "clear CH1 local status");
        wait_probe_cycles(2);

        axil_read32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_STATUS,
            irq_status,
            "confirm both-channel IRQ clear");
        if ((irq_status[9:8] != 2'b00)
                || (irq_status[1:0] != 2'b00)
                || (p_sequencer.probe_vif.mon_cb.irq_ch != 2'b00)
                || p_sequencer.probe_vif.mon_cb.global_irq) begin
            `uvm_error(
                "REORDER_IRQ_CLEAR",
                $sformatf(
                    "IRQ did not clear status=0x%08h irq_ch=%0b irq=%0b",
                    irq_status,
                    p_sequencer.probe_vif.mon_cb.irq_ch,
                    p_sequencer.probe_vif.mon_cb.global_irq))
        end

        wait_probe_cycles(5);
    endtask

endclass
