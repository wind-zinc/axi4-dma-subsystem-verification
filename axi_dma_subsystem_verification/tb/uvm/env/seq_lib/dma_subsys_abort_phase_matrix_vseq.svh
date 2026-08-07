// Complements dma_subsys_abort_timing_vseq with the opposite channel roles.
// Every abort is requested through the software-visible AXI-Lite control
// register; no DUT handshake or internal state is forced by this sequence.
class dma_subsys_abort_phase_matrix_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_abort_phase_matrix_vseq)

    function new(string name = "dma_subsys_abort_phase_matrix_vseq");
        super.new(name);
    endfunction

    protected function int unsigned channel_index(
        input dma_channel_e channel
    );
        return (channel == DMA_CH1) ? 1 : 0;
    endfunction

    protected task wait_for_route_wait(
        input dma_channel_e channel,
        input string        operation
    );
        int unsigned index;

        index = channel_index(channel);
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.route_req_valid[index]
                    && !p_sequencer.probe_vif.mon_cb.route_req_ready[
                        index]) begin
                return;
            end
        end

        `uvm_fatal(
            "ABORT_ROUTE_WAIT",
            $sformatf("%s did not observe a blocked route request",
                      operation))
    endtask

    protected task run_inflight_abort(
        input dma_channel_e              channel,
        input dma_channel_e              destination_channel,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input logic [7:0]                software_tag,
        input byte unsigned              payload_seed,
        input string                     case_name
    );
        initialize_region(
            source_address,
            1024,
            payload_seed,
            $sformatf("%s source", case_name));
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            destination_channel,
            source_address,
            destination_address,
            1024,
            software_tag,
            DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED,
            1'b1,
            1'b1,
            1'b1);
        program_dma(
            channel,
            destination_channel,
            source_address,
            destination_address,
            1024,
            software_tag);
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        wait_channel_busy(channel);
        wait_probe_cycles(8);
        set_channel_control(
            channel,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            $sformatf("abort %s", case_name));
        check_channel_error(
            channel,
            DMA_ERR_ABORT_INFLIGHT_UNSUPPORTED,
            1'b1,
            case_name);
        clear_channel_result(channel);
    endtask

    protected task run_pending_route_abort(
        input dma_channel_e              owner_channel,
        input dma_channel_e              waiter_channel,
        input dma_channel_e              contested_destination,
        input logic [AXI_ADDR_WIDTH-1:0] owner_source_address,
        input logic [AXI_ADDR_WIDTH-1:0] owner_destination_address,
        input logic [AXI_ADDR_WIDTH-1:0] waiter_source_address,
        input logic [AXI_ADDR_WIDTH-1:0] waiter_destination_address,
        input string                     case_name
    );
        logic [31:0] owner_status;

        initialize_region(
            owner_source_address,
            1024,
            8'h4D,
            $sformatf("%s owner source", case_name));
        initialize_region(
            waiter_source_address,
            64,
            8'h9A,
            $sformatf("%s waiter source", case_name));

        publish_dma_intent(
            $sformatf("%s_owner_intent", case_name),
            owner_channel,
            contested_destination,
            owner_source_address,
            owner_destination_address,
            1024,
            8'hC1);
        publish_dma_intent(
            $sformatf("%s_waiter_intent", case_name),
            waiter_channel,
            contested_destination,
            waiter_source_address,
            waiter_destination_address,
            64,
            8'hC2,
            DMA_ERR_ABORT_PENDING,
            1'b1,
            1'b1,
            1'b1);
        program_dma(
            owner_channel,
            contested_destination,
            owner_source_address,
            owner_destination_address,
            1024,
            8'hC1);
        program_dma(
            waiter_channel,
            contested_destination,
            waiter_source_address,
            waiter_destination_address,
            64,
            8'hC2);

        set_channel_control(
            owner_channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s owner", case_name));
        wait_channel_busy(owner_channel);
        set_channel_control(
            waiter_channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s waiter", case_name));
        wait_for_route_wait(waiter_channel, case_name);
        set_channel_control(
            waiter_channel,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            $sformatf("abort %s waiter", case_name));
        check_channel_error(
            waiter_channel,
            DMA_ERR_ABORT_PENDING,
            1'b1,
            $sformatf("%s waiter", case_name));
        clear_channel_result(waiter_channel);

        wait_channel_done(owner_channel, owner_status);
        if (owner_status[15:8] != DMA_ERR_NONE) begin
            `uvm_error(
                "ABORT_OWNER_RESULT",
                $sformatf("%s owner status=0x%08h",
                          case_name, owner_status))
        end
        clear_channel_result(owner_channel);
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        // The existing abort-timing test covers CH0 in flight.  Exercise the
        // same software-visible behavior with CH1 owning the transaction.
        run_inflight_abort(
            DMA_CH1,
            DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_0800,
            RAM1_BASE_ADDR + 32'h0000_5000,
            8'hC0,
            8'h37,
            "ch1_inflight_abort");

        // CH1 naturally owns destination route 1.  CH0 then requests the
        // same route and is aborted while it is still pre-descriptor.
        run_pending_route_abort(
            DMA_CH1,
            DMA_CH0,
            DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1000,
            RAM1_BASE_ADDR + 32'h0000_6000,
            RAM0_BASE_ADDR + 32'h0000_1000,
            RAM0_BASE_ADDR + 32'h0000_6000,
            "ch0_pending_route_abort");

        // Prove that both channels and both route destinations recover after
        // the abort scenarios.
        run_dma_case(
            "post_abort_clean_ch0",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_7000,
            RAM1_BASE_ADDR + 32'h0000_7000,
            32,
            8'hD0,
            8'h51);
        run_dma_case(
            "post_abort_clean_ch1",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_7800,
            RAM0_BASE_ADDR + 32'h0000_7800,
            32,
            8'hD1,
            8'h62);

        wait_probe_cycles(5);
    endtask
endclass
