class dma_subsys_register_access_policy_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_register_access_policy_vseq)

    function new(string name = "dma_subsys_register_access_policy_vseq");
        super.new(name);
    endfunction

    protected task read_expect(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input xil_axi_resp_t expected,
        input string operation
    );
        logic [31:0] value;
        xil_axi_resp_t response;
        axil_read32_raw(address, value, response, operation);
        expect_axil_response(response, expected, operation);
    endtask

    protected task write_expect(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [31:0] value,
        input xil_axi_resp_t expected,
        input string operation
    );
        xil_axi_resp_t response;
        axil_write32_raw(address, value, response, operation);
        expect_axil_response(response, expected, operation);
    endtask

    virtual task body();
        logic [11:0] channel_offsets[13];
        logic [11:0] global_offsets[11];
        logic [AXIL_ADDR_WIDTH-1:0] base;

        channel_offsets = '{
            REG_CTRL, REG_STATUS, REG_SRC_ADDR, REG_DST_ADDR,
            REG_LENGTH, REG_ROUTE, REG_SW_TAG, REG_LAST_HW_TAG,
            REG_COMPLETED_LEN, REG_LAST_ERROR, REG_CMD_COUNT,
            REG_DONE_COUNT, REG_VERSION};
        global_offsets = '{
            REG_IRQ_STATUS, REG_IRQ_ENABLE, REG_IRQ_CLEAR,
            REG_IRQ_LAST_ERROR, REG_CH0_DONE_COUNT, REG_CH1_DONE_COUNT,
            REG_CH0_ERROR_COUNT, REG_CH1_ERROR_COUNT, REG_ROUTE_STATUS,
            REG_GLOBAL_VERSION, REG_FAULT_STATUS};

        wait_for_infrastructure();
        prepare_subsystem(32'd0);

        for (int block = 0; block < 2; block++) begin
            base = (block == 0) ? CH0_CTRL_BASE_ADDR : CH1_CTRL_BASE_ADDR;
            foreach (channel_offsets[index]) begin
                read_expect(base + channel_offsets[index],
                    XIL_AXI_RESP_OKAY,
                    $sformatf("read CH%0d register 0x%03h",
                              block, channel_offsets[index]));
            end
        end
        foreach (global_offsets[index]) begin
            if (global_offsets[index] != REG_IRQ_CLEAR) begin
                read_expect(GLOBAL_IRQ_BASE_ADDR + global_offsets[index],
                    XIL_AXI_RESP_OKAY,
                    $sformatf("read global register 0x%03h",
                              global_offsets[index]));
            end
        end

        // Normal RW and WO accesses.
        write_expect(CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h0000_1234, XIL_AXI_RESP_OKAY, "full-strobe RW write");
        write_expect(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303, XIL_AXI_RESP_OKAY, "WO clear write");

        // RO write and WO read are legal AXI transfers that the register
        // blocks reject with SLVERR.
        write_expect(CH0_CTRL_BASE_ADDR + REG_STATUS,
            32'hFFFF_FFFF, XIL_AXI_RESP_SLVERR, "RO write attempt");
        read_expect(GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            XIL_AXI_RESP_SLVERR, "WO read attempt");
        read_expect(CH0_CTRL_BASE_ADDR + 32'h0000_03FC,
            XIL_AXI_RESP_SLVERR, "unmapped offset read");
        write_expect(CH1_CTRL_BASE_ADDR + 32'h0000_03FC,
            32'hA5A5_5A5A, XIL_AXI_RESP_SLVERR,
            "unmapped offset write");

        // Outside all three 4-KiB control windows, the AXI-Lite crossbar
        // itself returns DECERR.
        read_expect(32'h0000_3000,
            XIL_AXI_RESP_DECERR, "unmapped block read");
        write_expect(32'h0000_3000, 32'h1,
            XIL_AXI_RESP_DECERR, "unmapped block write");

        // Shape WSTRB without using a vendor-private transaction class.
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b1;
        p_sequencer.test_ctrl_vif.forced_axil_wstrb = 4'b0011;
        write_expect(CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'hABCD_5678, XIL_AXI_RESP_OKAY, "partial-strobe write");
        p_sequencer.test_ctrl_vif.forced_axil_wstrb = 4'b0000;
        write_expect(CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'hFFFF_FFFF, XIL_AXI_RESP_OKAY, "zero-strobe write");
        p_sequencer.test_ctrl_vif.force_axil_wstrb_enable = 1'b0;

        wait_probe_cycles(5);
    endtask
endclass
