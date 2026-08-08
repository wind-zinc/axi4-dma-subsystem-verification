// Deterministically covers reset exits from every reachable manager state and
// the legal stalled-descriptor abort branches.  READY hooks only hold a state
// until software abort or reset; they are never released mid-transfer to
// manufacture a same-cycle handshake.  Command programming and abort requests
// remain software-visible AXI-Lite operations.
class dma_subsys_fsm_reset_arc_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_fsm_reset_arc_vseq)

    localparam logic [3:0] ST_IDLE           = 4'd0;
    localparam logic [3:0] ST_VALIDATE       = 4'd1;
    localparam logic [3:0] ST_WAIT_ROUTE     = 4'd2;
    localparam logic [3:0] ST_ISSUE_WR_DESC  = 4'd3;
    localparam logic [3:0] ST_ISSUE_RD_DESC  = 4'd4;
    localparam logic [3:0] ST_WAIT_STATUS    = 4'd5;
    localparam logic [3:0] ST_COMPLETE       = 4'd6;
    localparam logic [3:0] ST_ERROR_RECOVERY = 4'd7;
    // AMD AXI VIP requires reset to remain asserted for at least 16 cycles.
    // Keep the same margin as the static testbench boot reset.
    localparam int unsigned RESET_HOLD_CYCLES = 20;

    function new(string name = "dma_subsys_fsm_reset_arc_vseq");
        super.new(name);
    endfunction

    protected function int unsigned channel_index(
        input dma_channel_e channel
    );
        return (channel == DMA_CH1) ? 1 : 0;
    endfunction

    protected task wait_manager_state(
        input dma_channel_e channel,
        input logic [3:0]   expected_state,
        input string        operation
    );
        int unsigned index;
        logic [3:0] observed_state;

        index = channel_index(channel);
        observed_state = 'x;
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.test_ctrl_vif.state_mon_cb);
            observed_state = p_sequencer.test_ctrl_vif.state_mon_cb
                .manager_state_observed[index];
            if (observed_state == expected_state) begin
                return;
            end
        end
        `uvm_fatal(
            "FSM_STATE_TIMEOUT",
            $sformatf(
                "%s did not observe %s manager state %0d; last state=%0d",
                operation, dma_channel_name(channel), expected_state,
                observed_state))
    endtask

    protected task recover_after_reset();
        p_sequencer.test_ctrl_vif.force_route_ready_low = '0;
        p_sequencer.test_ctrl_vif.force_wr_desc_ready_low = '0;
        p_sequencer.test_ctrl_vif.force_rd_desc_ready_low = '0;
        p_sequencer.test_ctrl_vif.force_manager_state_enable = '0;
        wait_for_infrastructure();
        p_sequencer.test_ctrl_vif.clear_all();
        prepare_subsystem();
    endtask

    // Descriptor READY outputs are driven by vendor-engine registers.  Keep
    // the hook asserted until reset, clear it while reset is active, and then
    // let the real engine leave reset normally.  No force/release transition
    // is used to advance an in-flight transfer.
    protected task reset_after_stall();
        p_sequencer.test_ctrl_vif.reset_request = 1'b1;
        repeat (RESET_HOLD_CYCLES)
            @(posedge p_sequencer.test_ctrl_vif.clk);
        p_sequencer.test_ctrl_vif.force_route_ready_low = '0;
        p_sequencer.test_ctrl_vif.force_wr_desc_ready_low = '0;
        p_sequencer.test_ctrl_vif.force_rd_desc_ready_low = '0;
        p_sequencer.test_ctrl_vif.reset_request = 1'b0;
        recover_after_reset();
    endtask

    protected task reset_from_manager_state(
        input dma_channel_e channel,
        input logic [3:0]   target_state,
        input int unsigned  case_index
    );
        int unsigned index;
        logic [31:0] memory_base;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        string case_name;

        index = channel_index(channel);
        memory_base = (channel == DMA_CH1)
            ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
        source_address = memory_base
            + 32'h0000_0800 + (case_index * 32'h0000_0100);
        destination_address = memory_base
            + 32'h0000_8800 + (case_index * 32'h0000_0100);
        case_name = $sformatf(
            "%s_reset_from_state_%0d",
            dma_channel_name(channel), target_state);

        initialize_region(
            source_address,
            64,
            byte'(8'h20 + (case_index * 8'h11) + index),
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'h80 + case_index + index),
            DMA_ERR_NONE,
            1'b1,
            1'b0,
            1'b0);
        program_dma(
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'h80 + case_index + index));

        case (target_state)
            ST_WAIT_ROUTE:
                p_sequencer.test_ctrl_vif.force_route_ready_low[index]
                    = 1'b1;
            ST_ISSUE_WR_DESC:
                p_sequencer.test_ctrl_vif.force_wr_desc_ready_low[index]
                    = 1'b1;
            ST_ISSUE_RD_DESC:
                p_sequencer.test_ctrl_vif.force_rd_desc_ready_low[index]
                    = 1'b1;
            default: begin end
        endcase

        // The observer starts before the control write.  This is essential
        // for ST_VALIDATE, which lasts only one clock after command acceptance.
        fork
            begin
                set_channel_control(
                    channel,
                    1'b1,
                    1'b1,
                    1'b0,
                    1'b0,
                    $sformatf("start %s", case_name));
            end
            begin
                wait_manager_state(channel, target_state, case_name);
                p_sequencer.test_ctrl_vif.reset_request = 1'b1;
                repeat (RESET_HOLD_CYCLES)
                    @(posedge p_sequencer.test_ctrl_vif.clk);
                p_sequencer.test_ctrl_vif.reset_request = 1'b0;
            end
        join

        recover_after_reset();
    endtask

    protected task reset_from_error_recovery(
        input dma_channel_e channel,
        input int unsigned  case_index
    );
        int unsigned index;
        logic [31:0] memory_base;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        string case_name;

        index = channel_index(channel);
        memory_base = (channel == DMA_CH1)
            ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
        source_address = memory_base
            + 32'h0000_2000 + (case_index * 32'h0000_0100);
        destination_address = memory_base
            + 32'h0000_A000 + (case_index * 32'h0000_0100);
        case_name = $sformatf(
            "%s_reset_from_error_recovery",
            dma_channel_name(channel));

        initialize_region(
            source_address,
            64,
            byte'(8'h61 + index),
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hE0 + index),
            DMA_ERR_INTERNAL,
            1'b1,
            1'b0,
            1'b0);
        program_dma(
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hE0 + index));
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        wait_channel_busy(channel);

        // One illegal encoding executes the RTL default branch.  At this
        // edge the underlying state receives ERROR_RECOVERY; release the
        // force and assert reset before the following edge so URG observes
        // ERROR_RECOVERY->IDLE rather than ERROR_RECOVERY->COMPLETE.
        p_sequencer.test_ctrl_vif.forced_manager_state[index] = 4'hF;
        p_sequencer.test_ctrl_vif.force_manager_state_enable[index] = 1'b1;
        @(p_sequencer.test_ctrl_vif.state_mon_cb);
        p_sequencer.test_ctrl_vif.reset_request = 1'b1;
        p_sequencer.test_ctrl_vif.force_manager_state_enable[index] = 1'b0;
        repeat (RESET_HOLD_CYCLES)
            @(posedge p_sequencer.test_ctrl_vif.clk);
        p_sequencer.test_ctrl_vif.reset_request = 1'b0;

        recover_after_reset();
    endtask

    protected task abort_while_write_descriptor_stalled(
        input dma_channel_e channel,
        input int unsigned  case_index
    );
        int unsigned index;
        logic [31:0] memory_base;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        string case_name;

        index = channel_index(channel);
        memory_base = (channel == DMA_CH1)
            ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
        source_address = memory_base
            + 32'h0000_3000 + (case_index * 32'h0000_0100);
        destination_address = memory_base
            + 32'h0000_B000 + (case_index * 32'h0000_0100);
        case_name = $sformatf(
            "%s_abort_stalled_write_descriptor",
            dma_channel_name(channel));

        wait_manager_state(
            channel, ST_IDLE, $sformatf("prepare %s", case_name));
        wait_channel_busy(channel, 1'b0);

        initialize_region(
            source_address,
            64,
            byte'(8'h72 + index),
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hF0 + index),
            DMA_ERR_ABORT_PENDING,
            1'b1,
            1'b1,
            1'b1);
        program_dma(
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hF0 + index));
        p_sequencer.test_ctrl_vif.force_wr_desc_ready_low[index] = 1'b1;
        // READY is held low, so ISSUE_WR_DESC persists.  Complete the start
        // AXI-Lite API call before issuing abort; two concurrent convenience
        // API calls on the same AMD master agent are not safely serialized.
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        wait_channel_busy(channel);
        wait_manager_state(channel, ST_ISSUE_WR_DESC, case_name);
        set_channel_control(
            channel,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            $sformatf("abort %s", case_name));
        wait_probe_cycles(2);
        check_channel_error(
            channel,
            DMA_ERR_ABORT_PENDING,
            1'b1,
            case_name);
        clear_channel_result(channel);
        wait_manager_state(
            channel, ST_IDLE, $sformatf("complete %s", case_name));
        wait_channel_busy(channel, 1'b0);
        reset_after_stall();
    endtask

    // Samples abort while the read descriptor is genuinely backpressured.
    // The transfer is then discarded by reset instead of relying on a
    // simulator-specific force/release event to resume the vendor DMA.
    protected task abort_while_read_descriptor_stalled_then_reset(
        input dma_channel_e channel,
        input int unsigned  case_index
    );
        int unsigned index;
        logic [31:0] memory_base;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        logic [31:0] status;
        string case_name;

        index = channel_index(channel);
        memory_base = (channel == DMA_CH1)
            ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
        source_address = memory_base
            + 32'h0000_4000 + (case_index * 32'h0000_0100);
        destination_address = memory_base
            + 32'h0000_C000 + (case_index * 32'h0000_0100);
        case_name = $sformatf(
            "%s_abort_stalled_read_descriptor_then_reset",
            dma_channel_name(channel));

        wait_manager_state(
            channel, ST_IDLE, $sformatf("prepare %s", case_name));
        wait_channel_busy(channel, 1'b0);

        initialize_region(
            source_address,
            64,
            byte'(8'h91 + case_index),
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hD0 + case_index),
            DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED,
            1'b1,
            1'b0,
            1'b0);
        program_dma(
            channel,
            channel,
            source_address,
            destination_address,
            64,
            byte'(8'hD0 + case_index));
        p_sequencer.test_ctrl_vif.force_rd_desc_ready_low[index] = 1'b1;
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        wait_channel_busy(channel);
        wait_manager_state(channel, ST_ISSUE_RD_DESC, case_name);

        set_channel_control(
            channel,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            $sformatf("abort %s", case_name));
        wait_probe_cycles(2);
        wait_manager_state(
            channel, ST_ISSUE_RD_DESC,
            $sformatf("post-abort %s", case_name));
        axil_read32(
            channel_base(channel) + REG_STATUS,
            status,
            $sformatf("read %s abort status", case_name));
        if (!status[4]) begin
            `uvm_error(
                "FSM_ABORT_NOT_SEEN",
                $sformatf("%s status did not record abort: 0x%08h",
                          case_name, status))
        end
        reset_after_stall();
    endtask

    protected task wait_for_route_fault(input string operation);
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.combined_fault_valid
                    && (p_sequencer.probe_vif.mon_cb.combined_fault.error
                        == DMA_ERR_ROUTE_CONFLICT)) begin
                return;
            end
        end
        `uvm_fatal("FSM_ROUTE_FAULT_TIMEOUT", operation)
    endtask

    protected task run_ch1_invalid_route_request();
        publish_dma_intent(
            "ch1_invalid_route_request_intent",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_5000,
            RAM0_BASE_ADDR + 32'h0000_D000,
            64,
            8'h7E,
            DMA_ERR_ROUTE_CONFLICT,
            1'b1,
            1'b0,
            1'b1);
        program_dma(
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_5000,
            RAM0_BASE_ADDR + 32'h0000_D000,
            64,
            8'h7E);
        p_sequencer.test_ctrl_vif.forced_route_src[1] = 1'b0;
        p_sequencer.test_ctrl_vif.force_route_src_enable[1] = 1'b1;
        set_channel_control(
            DMA_CH1,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "start CH1 invalid route-source request");
        wait_for_route_fault("CH1 invalid route-source request");
        p_sequencer.test_ctrl_vif.reset_request = 1'b1;
        p_sequencer.test_ctrl_vif.force_route_src_enable[1] = 1'b0;
        repeat (RESET_HOLD_CYCLES)
            @(posedge p_sequencer.test_ctrl_vif.clk);
        p_sequencer.test_ctrl_vif.reset_request = 1'b0;
        recover_after_reset();
    endtask

    virtual task body();
        logic [3:0] reset_states[5];

        reset_states = '{
            ST_VALIDATE,
            ST_WAIT_ROUTE,
            ST_ISSUE_WR_DESC,
            ST_ISSUE_RD_DESC,
            ST_WAIT_STATUS};

        wait_for_infrastructure();
        prepare_subsystem();

        foreach (reset_states[index]) begin
            reset_from_manager_state(DMA_CH0, reset_states[index], index);
        end
        reset_from_error_recovery(DMA_CH0, 0);

        foreach (reset_states[index]) begin
            reset_from_manager_state(DMA_CH1, reset_states[index], index);
        end
        reset_from_error_recovery(DMA_CH1, 1);

        abort_while_write_descriptor_stalled(DMA_CH0, 0);
        abort_while_write_descriptor_stalled(DMA_CH1, 1);
        abort_while_read_descriptor_stalled_then_reset(DMA_CH0, 0);
        abort_while_read_descriptor_stalled_then_reset(DMA_CH1, 1);
        run_ch1_invalid_route_request();

        p_sequencer.test_ctrl_vif.clear_all();
        wait_probe_cycles(5);
    endtask
endclass
