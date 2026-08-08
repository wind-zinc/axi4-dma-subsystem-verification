// Directed AXI-Lite timing/data patterns for reachable condition and toggle
// holes in dma_ctrl_regs, dma_irq_status_ctrl, and the subsystem crossbar
// wiring.  All traffic is issued through the AMD master VIP; the only narrow
// hook used here is the already-supported WSTRB override.
class dma_subsys_axil_condition_closure_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_axil_condition_closure_vseq)

    localparam int unsigned BATCH_DEPTH = 8;

    function new(
        string name = "dma_subsys_axil_condition_closure_vseq"
    );
        super.new(name);
    endfunction

    protected task axil_write32_prot_raw(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        input  logic [AXIL_DATA_WIDTH-1:0] value,
        input  logic [2:0]                 protection,
        output xil_axi_resp_t              response,
        input  string                      operation
    );
        bit [8*8-1:0] data;
        bit completed;

        data = '0;
        data[AXIL_DATA_WIDTH-1:0] = value;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;
        fork : prot_write_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_WRITE_BURST(
                    address, protection, data, response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable prot_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "AXIL_PROT_WRITE_TIMEOUT",
                $sformatf("%s timed out at 0x%08h", operation, address))
        end
    endtask

    protected task axil_read32_prot_raw(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        input  logic [2:0]                 protection,
        output logic [AXIL_DATA_WIDTH-1:0] value,
        output xil_axi_resp_t              response,
        input  string                      operation
    );
        bit [8*8-1:0] data;
        bit completed;

        data = '0;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;
        fork : prot_read_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_READ_BURST(
                    address, protection, data, response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable prot_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "AXIL_PROT_READ_TIMEOUT",
                $sformatf("%s timed out at 0x%08h", operation, address))
        end
        value = data[AXIL_DATA_WIDTH-1:0];
    endtask

    protected task write_aw_before_w_global();
        axi_transaction transaction;
        bit [8*4096-1:0] payload;
        xil_axi_resp_t response;

        payload = '0;
        payload[31:0] = 32'h4000_0303;
        transaction =
            p_sequencer.vip_mgr.axil_cpu.wr_driver.create_transaction(
                "global_aw_before_w");
        transaction.set_write_cmd(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            XIL_AXI_BURST_TYPE_INCR,
            0,
            0,
            XIL_AXI_SIZE_4BYTE);
        transaction.set_prot(XIL_AXI_PROT_NORMAL_ACCESS_MASK);
        transaction.set_addr_delay(0);
        transaction.set_data_insertion_delay(4);
        transaction.set_data_block(payload);
        transaction.set_beat_delay(0, 0);
        transaction.set_xfer_wrcmd_order(XIL_AXI_WRCMD_ORDER_NONE);
        transaction.set_xfer_wrdata_insertion_policy(
            XIL_AXI_WRCMD_INSERTION_ALWAYS);
        transaction.set_adjust_addr_delay_enabled(XIL_AXI_FALSE);
        transaction.set_adjust_data_beat_delay_enabled(XIL_AXI_FALSE);
        transaction.set_allow_data_before_cmd(0);
        transaction.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);

        p_sequencer.vip_mgr.axil_cpu.wr_driver.send(transaction);
        p_sequencer.vip_mgr.axil_cpu.wr_driver.wait_rsp(transaction);
        response = transaction.get_bresp();
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "global AW-before-W write");
    endtask

    // M_ISSUE is four in the AXI-Lite crossbar.  Eight queued requests while
    // the upstream response is held fill the legal buffering window and make
    // the local register block observe VALID=1 with READY=0.
    protected task run_write_response_batch();
        axi_transaction transaction[BATCH_DEPTH];
        bit [8*4096-1:0] payload;

        p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b1;
        wait_probe_cycles(1);
        for (int unsigned index = 0; index < BATCH_DEPTH; index++) begin
            payload = '0;
            payload[31:0] = 32'h0101_0101 * (index + 1);
            transaction[index] =
                p_sequencer.vip_mgr.axil_cpu.wr_driver.create_transaction(
                    $sformatf("condition_write_batch_%0d", index));
            transaction[index].set_write_cmd(
                CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
                XIL_AXI_BURST_TYPE_INCR,
                0,
                0,
                XIL_AXI_SIZE_4BYTE);
            transaction[index].set_prot(XIL_AXI_PROT_NORMAL_ACCESS_MASK);
            transaction[index].set_data_block(payload);
            transaction[index].set_beat_delay(0, 0);
            transaction[index].set_xfer_wrcmd_order(
                XIL_AXI_WRCMD_ORDER_NONE);
            transaction[index].set_xfer_wrdata_insertion_policy(
                XIL_AXI_WRCMD_INSERTION_ALWAYS);
            transaction[index].set_driver_return_item_policy(
                XIL_AXI_PAYLOAD_RETURN);
            p_sequencer.vip_mgr.axil_cpu.wr_driver.send(
                transaction[index]);
        end

        wait_probe_cycles(32);
        p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b0;
        foreach (transaction[index]) begin
            p_sequencer.vip_mgr.axil_cpu.wr_driver.wait_rsp(
                transaction[index]);
            expect_axil_response(
                transaction[index].get_bresp(),
                XIL_AXI_RESP_OKAY,
                $sformatf("condition write batch %0d", index));
        end
        wait_probe_cycles(2);
    endtask

    protected task run_read_response_batch();
        axi_transaction transaction[BATCH_DEPTH];

        p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b1;
        wait_probe_cycles(1);
        for (int unsigned index = 0; index < BATCH_DEPTH; index++) begin
            transaction[index] =
                p_sequencer.vip_mgr.axil_cpu.rd_driver.create_transaction(
                    $sformatf("condition_read_batch_%0d", index));
            transaction[index].set_read_cmd(
                CH0_CTRL_BASE_ADDR + REG_VERSION,
                XIL_AXI_BURST_TYPE_INCR,
                0,
                0,
                XIL_AXI_SIZE_4BYTE);
            transaction[index].set_prot(XIL_AXI_PROT_NORMAL_ACCESS_MASK);
            transaction[index].set_driver_return_item_policy(
                XIL_AXI_PAYLOAD_RETURN);
            p_sequencer.vip_mgr.axil_cpu.rd_driver.send(
                transaction[index]);
        end

        wait_probe_cycles(32);
        p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b0;
        foreach (transaction[index]) begin
            p_sequencer.vip_mgr.axil_cpu.rd_driver.wait_rsp(
                transaction[index]);
            expect_axil_response(
                transaction[index].get_rresp(0),
                XIL_AXI_RESP_OKAY,
                $sformatf("condition read batch %0d", index));
        end
        wait_probe_cycles(2);
    endtask

    protected task sweep_register_data(input dma_channel_e channel);
        logic [AXIL_ADDR_WIDTH-1:0] base;
        logic [AXIL_BLOCK_ADDR_WIDTH-1:0] offsets[5];
        logic [31:0] read_value;

        base = channel_base(channel);
        offsets = '{
            REG_SRC_ADDR,
            REG_DST_ADDR,
            REG_LENGTH,
            REG_ROUTE,
            REG_SW_TAG};
        foreach (offsets[index]) begin
            axil_write32(
                base + offsets[index],
                32'hFFFF_FFFF,
                $sformatf("%s all-one register sweep %0d",
                          dma_channel_name(channel), index));
            axil_read32(
                base + offsets[index],
                read_value,
                $sformatf("%s all-one register readback %0d",
                          dma_channel_name(channel), index));
            axil_write32(
                base + offsets[index],
                32'h0000_0000,
                $sformatf("%s all-zero register sweep %0d",
                          dma_channel_name(channel), index));
            axil_read32(
                base + offsets[index],
                read_value,
                $sformatf("%s all-zero register readback %0d",
                          dma_channel_name(channel), index));
        end
    endtask

    protected task run_ch1_busy_only_start();
        logic [31:0] status;

        initialize_region(
            RAM1_BASE_ADDR + 32'h0000_0800,
            4096,
            8'h6D,
            "CH1 busy-only source");
        publish_dma_intent(
            "ch1_busy_only_intent",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_0800,
            RAM0_BASE_ADDR + 32'h0000_8000,
            4096,
            8'hB1);
        program_dma(
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_0800,
            RAM0_BASE_ADDR + 32'h0000_8000,
            4096,
            8'hB1);
        set_channel_control(
            DMA_CH1, 1'b1, 1'b1, 1'b0, 1'b0,
            "start CH1 busy-only flow");
        wait_channel_busy(DMA_CH1);
        set_channel_control(
            DMA_CH1, 1'b1, 1'b1, 1'b0, 1'b0,
            "repeat start while CH1 is busy");
        wait_channel_done(DMA_CH1, status);
        clear_channel_result(DMA_CH1);
    endtask

    protected task run_ch1_disabled_start();
        logic [31:0] last_error;

        set_channel_control(
            DMA_CH1, 1'b0, 1'b0, 1'b0, 1'b1,
            "disable and clear CH1 for closure");
        program_dma(
            DMA_CH1,
            DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1800,
            RAM1_BASE_ADDR + 32'h0000_2800,
            64,
            8'hB0);
        publish_dma_intent(
            "ch1_disabled_rejected_intent",
            DMA_CH1,
            DMA_CH1,
            RAM1_BASE_ADDR + 32'h0000_1800,
            RAM1_BASE_ADDR + 32'h0000_2800,
            64,
            8'hB0,
            DMA_ERR_DISABLED,
            1'b0,
            1'b0,
            1'b0);
        set_channel_control(
            DMA_CH1, 1'b0, 1'b1, 1'b0, 1'b0,
            "start disabled CH1 for closure");
        wait_probe_cycles(2);
        axil_read32(
            CH1_CTRL_BASE_ADDR + REG_LAST_ERROR,
            last_error,
            "read CH1 disabled-start error");
        if (last_error[7:0] != DMA_ERR_DISABLED) begin
            `uvm_error(
                "CH1_DISABLED_CLOSURE",
                $sformatf("expected 0x%02h observed 0x%02h",
                          DMA_ERR_DISABLED, last_error[7:0]))
        end
        set_channel_control(
            DMA_CH1, 1'b1, 1'b0, 1'b0, 1'b1,
            "re-enable CH1 after disabled closure");
    endtask

    virtual task body();
        xil_axi_resp_t response;
        logic [31:0] read_value;

        wait_for_infrastructure();
        prepare_subsystem(32'd0);

        sweep_register_data(DMA_CH0);
        sweep_register_data(DMA_CH1);
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'hFFFF_FFFF,
            "global IRQ enable all-one sweep");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000,
            "global IRQ enable all-zero sweep");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'hFFFF_FFFF,
            "global IRQ clear all-one sweep");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h0000_0000,
            "global IRQ clear all-zero sweep");

        // Evaluate START/ABORT/CLEAR with WSTRB[0]=0.  The write is legal but
        // has no architectural side effect.
        p_sequencer.test_ctrl_vif.forced_axil_wstrb = 4'b1110;
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b1;
        axil_write32_raw(
            CH0_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0013,
            response,
            "CH0 control bits with byte zero masked");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "CH0 masked control write");
        axil_write32_raw(
            CH1_CTRL_BASE_ADDR + REG_CTRL,
            32'h0000_0013,
            response,
            "CH1 control bits with byte zero masked");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "CH1 masked control write");
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b0;

        // Idle abort reaches the false/false branch of the pending/busy
        // predicates without creating a command.
        set_channel_control(
            DMA_CH0, 1'b1, 1'b0, 1'b1, 1'b0, "idle abort CH0");
        set_channel_control(
            DMA_CH1, 1'b1, 1'b0, 1'b1, 1'b0, "idle abort CH1");

        write_aw_before_w_global();
        axil_write32_prot_raw(
            CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h1357_9BDF,
            3'b111,
            response,
            "AXI-Lite high AWPROT write");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "AXI-Lite high AWPROT write");
        axil_write32_prot_raw(
            CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h0000_0000,
            3'b000,
            response,
            "AXI-Lite low AWPROT write");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "AXI-Lite low AWPROT write");
        axil_read32_prot_raw(
            GLOBAL_IRQ_BASE_ADDR + REG_GLOBAL_VERSION,
            3'b111,
            read_value,
            response,
            "AXI-Lite high ARPROT read");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "AXI-Lite high ARPROT read");
        axil_read32_prot_raw(
            GLOBAL_IRQ_BASE_ADDR + REG_GLOBAL_VERSION,
            3'b000,
            read_value,
            response,
            "AXI-Lite low ARPROT read");
        expect_axil_response(
            response, XIL_AXI_RESP_OKAY, "AXI-Lite low ARPROT read");

        // Local invalid offsets return SLVERR; top-level unmapped addresses
        // return DECERR.  Complementary address patterns toggle every
        // software-visible address bit that the master can legally drive.
        axil_write32_raw(
            CH0_CTRL_BASE_ADDR + 32'h0000_0FFC,
            32'hA5A5_5A5A,
            response,
            "CH0 local invalid write");
        expect_axil_response(
            response, XIL_AXI_RESP_SLVERR, "CH0 local invalid write");
        axil_read32_raw(
            CH1_CTRL_BASE_ADDR + 32'h0000_0FFC,
            read_value,
            response,
            "CH1 local invalid read");
        expect_axil_response(
            response, XIL_AXI_RESP_SLVERR, "CH1 local invalid read");
        axil_write32_raw(
            32'hAAAA_AAAC,
            32'hFFFF_0000,
            response,
            "top complementary unmapped write");
        expect_axil_response(
            response, XIL_AXI_RESP_DECERR,
            "top complementary unmapped write");
        axil_read32_raw(
            32'h5555_5554,
            read_value,
            response,
            "top complementary unmapped read");
        expect_axil_response(
            response, XIL_AXI_RESP_DECERR,
            "top complementary unmapped read");

        run_write_response_batch();
        run_read_response_batch();

        prepare_subsystem();
        run_ch1_disabled_start();
        run_ch1_busy_only_start();

        p_sequencer.test_ctrl_vif.hold_axil_b_channel = 1'b0;
        p_sequencer.test_ctrl_vif.hold_axil_r_channel = 1'b0;
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b0;
        wait_probe_cycles(5);
    endtask
endclass
