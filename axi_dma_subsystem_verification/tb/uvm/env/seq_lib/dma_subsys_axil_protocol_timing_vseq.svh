class dma_subsys_axil_protocol_timing_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_axil_protocol_timing_vseq)

    localparam int unsigned AXIL_EVENT_AW = 0;
    localparam int unsigned AXIL_EVENT_W  = 1;
    localparam int unsigned AXIL_EVENT_B  = 2;
    localparam int unsigned AXIL_EVENT_R  = 3;
    localparam int unsigned AXIL_ORDER_GAP_CYCLES = 2;

    function new(string name = "dma_subsys_axil_protocol_timing_vseq");
        super.new(name);
    endfunction

    protected task wait_for_axil_event(
        input int unsigned event_kind,
        input string       operation
    );
        bit observed;

        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.test_ctrl_vif.axil_mon_cb);
            case (event_kind)
                AXIL_EVENT_AW: observed =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_awvalid_observed
                    && p_sequencer.test_ctrl_vif.axil_mon_cb.axil_awready_observed;
                AXIL_EVENT_W: observed =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_wvalid_observed
                    && p_sequencer.test_ctrl_vif.axil_mon_cb.axil_wready_observed;
                AXIL_EVENT_B: observed =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_bvalid_observed;
                AXIL_EVENT_R: observed =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_rvalid_observed;
                default: observed = 1'b0;
            endcase
            if (observed) begin
                return;
            end
        end
        `uvm_fatal(
            "AXIL_TIMING_TIMEOUT",
            $sformatf("%s did not observe AXI-Lite event %0d",
                      operation, event_kind))
    endtask

    protected task observe_first_write_channel(
        input xil_axi_xfer_wrcmd_order_t expected_order,
        input string                     operation
    );
        bit aw_presented;
        bit w_presented;

        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.test_ctrl_vif.axil_mon_cb);
            aw_presented =
                p_sequencer.test_ctrl_vif.axil_mon_cb.axil_awvalid_observed;
            w_presented =
                p_sequencer.test_ctrl_vif.axil_mon_cb.axil_wvalid_observed;

            if (aw_presented || w_presented) begin
                `uvm_info(
                    "AXIL_ORDER_OBSERVED",
                    $sformatf(
                        "%s first sampled VALID: AWVALID=%0b WVALID=%0b",
                        operation, aw_presented, w_presented),
                    UVM_LOW)
                if (aw_presented && w_presented) begin
                    `uvm_error(
                        "AXIL_ORDER_SIMULTANEOUS",
                        $sformatf(
                            "%s first asserted AWVALID and WVALID together",
                            operation))
                end else if ((expected_order
                                == XIL_AXI_WRCMD_ORDER_CMD_BEFORE_DATA)
                            && !aw_presented) begin
                    `uvm_error(
                        "AXIL_ORDER_MISMATCH",
                        $sformatf(
                            "%s asserted WVALID before AWVALID",
                            operation))
                end else if ((expected_order
                                == XIL_AXI_WRCMD_ORDER_DATA_BEFORE_CMD)
                            && !w_presented) begin
                    `uvm_error(
                        "AXIL_ORDER_MISMATCH",
                        $sformatf(
                            "%s asserted AWVALID before WVALID",
                            operation))
                end
                return;
            end
        end

        `uvm_fatal(
            "AXIL_ORDER_TIMEOUT",
            $sformatf("%s observed no AXI-Lite write VALID", operation))
    endtask

    protected task vip_ordered_write(
        input xil_axi_xfer_wrcmd_order_t order,
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [31:0]                value,
        output xil_axi_resp_t             response,
        input string                      operation
    );
        axi_transaction transaction;
        bit [8*4096-1:0] payload;
        bit completed;
        int unsigned address_delay_cycles;
        int unsigned data_delay_cycles;

        payload = '0;
        payload[AXIL_DATA_WIDTH-1:0] = value;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;
        address_delay_cycles =
            (order == XIL_AXI_WRCMD_ORDER_DATA_BEFORE_CMD)
            ? AXIL_ORDER_GAP_CYCLES : 0;
        data_delay_cycles =
            (order == XIL_AXI_WRCMD_ORDER_CMD_BEFORE_DATA)
            ? AXIL_ORDER_GAP_CYCLES : 0;

        transaction =
            p_sequencer.vip_mgr.axil_cpu.wr_driver.create_transaction(
                operation);
        transaction.set_write_cmd(
            address,
            XIL_AXI_BURST_TYPE_INCR,
            0,
            0,
            XIL_AXI_SIZE_4BYTE);
        transaction.set_prot(XIL_AXI_PROT_NORMAL_ACCESS_MASK);
        transaction.set_addr_delay(address_delay_cycles);
        transaction.set_data_insertion_delay(data_delay_cycles);
        transaction.set_data_block(payload);
        transaction.set_beat_delay(0, 0);
        // The crossbar intentionally holds WREADY low until AW has selected a
        // destination.  AMD VIP DATA_BEFORE_CMD waits for an accepted W beat,
        // which deadlocks with that legal slave policy until its watchdog
        // releases AW.  Independent channels plus explicit delays exercise
        // VALID presentation order without requiring W to handshake first.
        transaction.set_xfer_wrcmd_order(XIL_AXI_WRCMD_ORDER_NONE);
        transaction.set_xfer_wrdata_insertion_policy(
            XIL_AXI_WRCMD_INSERTION_ALWAYS);
        transaction.set_adjust_addr_delay_enabled(XIL_AXI_FALSE);
        transaction.set_adjust_data_beat_delay_enabled(XIL_AXI_FALSE);
        transaction.set_allow_data_before_cmd(0);
        transaction.set_driver_return_item_policy(
            XIL_AXI_PAYLOAD_RETURN);

        `uvm_info(
            "AXIL_ORDER_CFG",
            $sformatf(
                "%s requested_order=%0d vip_order=NONE addr_delay=%0d data_delay=%0d",
                operation, order,
                address_delay_cycles, data_delay_cycles),
            UVM_LOW)

        fork : ordered_write_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.wr_driver.send(transaction);
                p_sequencer.vip_mgr.axil_cpu.wr_driver.wait_rsp(
                    transaction);
                response = transaction.get_bresp();
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable ordered_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "AXIL_ORDERED_WRITE_TIMEOUT",
                $sformatf("%s timed out at 0x%08h", operation, address))
        end
    endtask

    protected task write_with_vip_order(
        input xil_axi_xfer_wrcmd_order_t order,
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [31:0]                value,
        input xil_axi_resp_t              expected_response,
        input string                      operation
    );
        xil_axi_resp_t response;

        fork
            vip_ordered_write(
                order, address, value, response, operation);
            observe_first_write_channel(order, operation);
        join

        expect_axil_response(response, expected_response, operation);
        wait_probe_cycles(2);
    endtask

    protected task write_with_bready_backpressure(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [31:0]                value,
        input xil_axi_resp_t              expected_response,
        input string                      operation
    );
        xil_axi_resp_t response;
        logic [1:0] held_response;

        p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b1;
        wait_probe_cycles(1);
        fork
            begin
                axil_write32_raw(address, value, response, operation);
            end
            begin
                wait_for_axil_event(AXIL_EVENT_B, operation);
                held_response =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_bresp_observed;
                repeat (4) begin
                    @(p_sequencer.test_ctrl_vif.axil_mon_cb);
                    if (!p_sequencer.test_ctrl_vif.axil_mon_cb.axil_bvalid_observed
                            || (p_sequencer.test_ctrl_vif.axil_mon_cb.axil_bresp_observed
                                != held_response)) begin
                        `uvm_error(
                            "AXIL_B_STABILITY",
                            $sformatf(
                                "%s did not hold BVALID/BRESP under backpressure",
                                operation))
                    end
                end
                p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b0;
            end
        join
        expect_axil_response(response, expected_response, operation);
        wait_probe_cycles(2);
    endtask

    protected task read_with_rready_backpressure(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        output logic [31:0]                value,
        input  xil_axi_resp_t              expected_response,
        input  string                      operation
    );
        xil_axi_resp_t response;
        logic [1:0] held_response;

        p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b1;
        wait_probe_cycles(1);
        fork
            begin
                axil_read32_raw(address, value, response, operation);
            end
            begin
                wait_for_axil_event(AXIL_EVENT_R, operation);
                held_response =
                    p_sequencer.test_ctrl_vif.axil_mon_cb.axil_rresp_observed;
                repeat (4) begin
                    @(p_sequencer.test_ctrl_vif.axil_mon_cb);
                    if (!p_sequencer.test_ctrl_vif.axil_mon_cb.axil_rvalid_observed
                            || (p_sequencer.test_ctrl_vif.axil_mon_cb.axil_rresp_observed
                                != held_response)) begin
                        `uvm_error(
                            "AXIL_R_STABILITY",
                            $sformatf(
                                "%s did not hold RVALID/RRESP under backpressure",
                                operation))
                    end
                end
                p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b0;
            end
        join
        expect_axil_response(response, expected_response, operation);
        wait_probe_cycles(2);
    endtask

    virtual task body();
        logic [31:0] read_value;

        wait_for_infrastructure();
        prepare_subsystem(32'd0);

        write_with_vip_order(
            XIL_AXI_WRCMD_ORDER_CMD_BEFORE_DATA,
            CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h0000_5A40,
            XIL_AXI_RESP_OKAY,
            "AW-before-W channel register write");
        write_with_vip_order(
            XIL_AXI_WRCMD_ORDER_DATA_BEFORE_CMD,
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h4000_0303,
            XIL_AXI_RESP_OKAY,
            "W-before-AW global register write");
        write_with_vip_order(
            XIL_AXI_WRCMD_ORDER_DATA_BEFORE_CMD,
            GLOBAL_IRQ_BASE_ADDR + 32'h0000_03FC,
            32'hA5A5_5A5A,
            XIL_AXI_RESP_SLVERR,
            "W-before-AW invalid global write");

        write_with_bready_backpressure(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0303,
            XIL_AXI_RESP_OKAY,
            "global write response backpressure");
        read_with_rready_backpressure(
            GLOBAL_IRQ_BASE_ADDR + REG_GLOBAL_VERSION,
            read_value,
            XIL_AXI_RESP_OKAY,
            "global read response backpressure");
        if (read_value !== VERSION_VALUE) begin
            `uvm_error(
                "AXIL_TIMING_READBACK",
                $sformatf("version expected 0x%08h, observed 0x%08h",
                          VERSION_VALUE, read_value))
        end

        p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b0;
        p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b0;
        wait_probe_cycles(5);
    endtask
endclass
