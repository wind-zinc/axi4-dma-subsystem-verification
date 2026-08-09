// Drives complementary legal and negative bus values that remain reachable
// after the functional-coverage regression.  The sequence deliberately uses
// public AMD VIP APIs for AXI traffic and software-visible AXI-Lite commands.
class dma_subsys_bus_toggle_closure_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_bus_toggle_closure_vseq)

    localparam int unsigned MAX_AXI_BEATS = 256;
    localparam int unsigned LEGAL_ALL_LOW_LENGTH_BITS = 16'hFFFF;
    localparam int unsigned RESET_HOLD_CYCLES = 20;

    function new(string name = "dma_subsys_bus_toggle_closure_vseq");
        super.new(name);
    endfunction

    protected task run_external_mapped_case(
        input dma_master_e               master,
        input logic [AXI_ID_WIDTH-1:0]   transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input byte unsigned              seed,
        input string                     operation
    );
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(payload, AXI_STRB_WIDTH, seed);
        external_write_shape(
            master,
            transaction_id,
            address,
            1,
            AXI_STRB_WIDTH,
            XIL_AXI_BURST_TYPE_INCR,
            payload,
            $sformatf("%s write", operation));
        external_read_shape(
            master,
            transaction_id,
            address,
            1,
            AXI_STRB_WIDTH,
            XIL_AXI_BURST_TYPE_INCR,
            readback,
            responses,
            $sformatf("%s read", operation));
        check_read_responses(responses, 1, $sformatf("%s read", operation));
        if (readback[AXI_DATA_WIDTH-1:0]
                !== payload[AXI_DATA_WIDTH-1:0]) begin
            `uvm_error(
                "TOGGLE_AXI_DATA",
                $sformatf(
                    "%s expected data=0x%08x, observed=0x%08x",
                    operation,
                    payload[AXI_DATA_WIDTH-1:0],
                    readback[AXI_DATA_WIDTH-1:0]))
        end
    endtask

    protected task run_external_byte_edge(
        input dma_master_e               master,
        input logic [AXI_ID_WIDTH-1:0]   transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input byte unsigned              seed,
        input string                     operation
    );
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(payload, 1, seed);
        external_write_shape(
            master,
            transaction_id,
            address,
            1,
            1,
            XIL_AXI_BURST_TYPE_INCR,
            payload,
            $sformatf("%s write", operation));
        external_read_shape(
            master,
            transaction_id,
            address,
            1,
            1,
            XIL_AXI_BURST_TYPE_INCR,
            readback,
            responses,
            $sformatf("%s read", operation));
        check_read_responses(
            responses, 1, $sformatf("%s read", operation));
    endtask

    protected task run_ext1_maximum_burst();
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(
            payload, MAX_AXI_BEATS * AXI_STRB_WIDTH, 8'hC7);
        external_write_shape(
            DMA_MASTER_EXT1,
            4'hF,
            RAM1_BASE_ADDR + 32'h0000_8000,
            MAX_AXI_BEATS,
            AXI_STRB_WIDTH,
            XIL_AXI_BURST_TYPE_INCR,
            payload,
            "EXT1 maximum-length write");
        external_read_shape(
            DMA_MASTER_EXT1,
            4'hF,
            RAM1_BASE_ADDR + 32'h0000_8000,
            MAX_AXI_BEATS,
            AXI_STRB_WIDTH,
            XIL_AXI_BURST_TYPE_INCR,
            readback,
            responses,
            "EXT1 maximum-length read");
        check_read_responses(
            responses, MAX_AXI_BEATS, "EXT1 maximum-length read");
    endtask

    protected task check_axil_access(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input xil_axi_resp_t              expected,
        input string                      operation
    );
        xil_axi_resp_t response;
        logic [31:0] read_value;

        axil_write32_raw(
            address,
            32'hA5A5_5A5A,
            response,
            $sformatf("%s write", operation));
        expect_axil_response(
            response, expected, $sformatf("%s write", operation));
        axil_read32_raw(
            address,
            read_value,
            response,
            $sformatf("%s read", operation));
        expect_axil_response(
            response, expected, $sformatf("%s read", operation));
    endtask

    protected task run_axil_address_complements();
        logic [AXIL_ADDR_WIDTH-1:0] local_invalid[3];
        logic [AXIL_ADDR_WIDTH-1:0] top_unmapped[2];

        local_invalid = '{
            CH0_CTRL_BASE_ADDR + 32'h0000_0FFC,
            CH1_CTRL_BASE_ADDR + 32'h0000_0FFC,
            GLOBAL_IRQ_BASE_ADDR + 32'h0000_0FFC};
        top_unmapped = '{32'hAAAA_AAAC, 32'h5555_5554};

        foreach (local_invalid[index]) begin
            check_axil_access(
                local_invalid[index],
                XIL_AXI_RESP_SLVERR,
                $sformatf("local invalid complement %0d", index));
        end
        foreach (top_unmapped[index]) begin
            check_axil_access(
                top_unmapped[index],
                XIL_AXI_RESP_DECERR,
                $sformatf("top unmapped complement %0d", index));
        end

        // Return every decoded write-address lane to a low legal value.
        axil_write32(
            CH0_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h0000_0000,
            "return CH0 write address low");
        axil_write32(
            CH1_CTRL_BASE_ADDR + REG_SRC_ADDR,
            32'h0000_0000,
            "return CH1 write address low");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            32'h0000_0000,
            "return IRQ write address low");
    endtask

    protected task run_dma_address_and_length_extremes();
        // 0xFFFF sets every legal low length bit.  The following four-byte
        // transfers return those bits low while driving address bits 15:2
        // first high and then low on both DMA channels.
        run_dma_case(
            "ch0_all_legal_length_bits",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR,
            RAM1_BASE_ADDR,
            LEGAL_ALL_LOW_LENGTH_BITS,
            8'hFF,
            8'h19);
        run_dma_case(
            "ch0_high_legal_address",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR + 32'h0000_FFFC,
            RAM1_BASE_ADDR + 32'h0000_FFFC,
            4,
            8'h00,
            8'h2A);
        run_dma_case(
            "ch0_low_legal_address",
            DMA_CH0,
            DMA_CH1,
            RAM0_BASE_ADDR,
            RAM1_BASE_ADDR,
            4,
            8'hA5,
            8'h3B);

        run_dma_case(
            "ch1_all_legal_length_bits",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR,
            RAM0_BASE_ADDR,
            LEGAL_ALL_LOW_LENGTH_BITS,
            8'hFF,
            8'h4C);
        run_dma_case(
            "ch1_high_legal_address",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR + 32'h0000_FFFC,
            RAM0_BASE_ADDR + 32'h0000_FFFC,
            4,
            8'h00,
            8'h5D);
        run_dma_case(
            "ch1_low_legal_address",
            DMA_CH1,
            DMA_CH0,
            RAM1_BASE_ADDR,
            RAM0_BASE_ADDR,
            4,
            8'h5A,
            8'h6E);
    endtask

    protected task run_invalid_max_length(
        input dma_channel_e channel,
        input int unsigned  case_index
    );
        dma_channel_e destination_channel;
        logic [31:0] source_address;
        logic [31:0] destination_address;
        string case_name;

        destination_channel =
            (channel == DMA_CH0) ? DMA_CH1 : DMA_CH0;
        source_address =
            (channel == DMA_CH0) ? RAM0_BASE_ADDR : RAM1_BASE_ADDR;
        destination_address =
            (channel == DMA_CH0) ? RAM1_BASE_ADDR : RAM0_BASE_ADDR;
        case_name = $sformatf(
            "%s_invalid_max_length", dma_channel_name(channel));

        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            channel,
            destination_channel,
            source_address,
            destination_address,
            20'hFFFFF,
            byte'(8'hE0 + case_index),
            DMA_ERR_SRC_RANGE);
        program_dma(
            channel,
            destination_channel,
            source_address,
            destination_address,
            20'hFFFFF,
            byte'(8'hE0 + case_index));
        set_channel_control(
            channel,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            $sformatf("start %s", case_name));
        check_channel_error(
            channel, DMA_ERR_SRC_RANGE, 1'b0, case_name);
        clear_channel_result(channel);
    endtask

    virtual task body();
        wait_for_infrastructure();
        prepare_subsystem();

        run_axil_address_complements();

        // Use complementary values inside the two implemented RAM windows.
        // The vendor crossbar's decode-miss response path can expose BVALID
        // before the upstream AW handshake, which the AMD VIP correctly treats
        // as a protocol fatal.  This coverage-closure test therefore keeps all
        // full-AXI traffic legal; structurally unreachable high address bits
        // remain candidates for the reviewed coverage exclusion file.
        run_external_mapped_case(
            DMA_MASTER_EXT0,
            4'hF,
            RAM1_BASE_ADDR + 32'h0000_FFFC,
            8'h71,
            "EXT0 high mapped address");
        run_external_mapped_case(
            DMA_MASTER_EXT0,
            4'h0,
            RAM0_BASE_ADDR,
            8'h82,
            "EXT0 low mapped address");
        run_external_mapped_case(
            DMA_MASTER_EXT1,
            4'hF,
            RAM1_BASE_ADDR + 32'h0000_FFFC,
            8'h93,
            "EXT1 high mapped address");
        run_external_mapped_case(
            DMA_MASTER_EXT1,
            4'h0,
            RAM0_BASE_ADDR,
            8'hA4,
            "EXT1 low mapped address");

        // One-byte accesses at each RAM's final byte cover legal low address,
        // SIZE, and byte-lane directions on both decoded target lanes.
        run_external_byte_edge(
            DMA_MASTER_EXT0,
            4'h5,
            RAM0_BASE_ADDR + 32'h0000_FFFF,
            8'hB5,
            "RAM0 final-byte access");
        run_external_byte_edge(
            DMA_MASTER_EXT1,
            4'hA,
            RAM1_BASE_ADDR + 32'h0000_FFFF,
            8'hC6,
            "RAM1 final-byte access");
        run_ext1_maximum_burst();

        run_dma_address_and_length_extremes();
        run_invalid_max_length(DMA_CH0, 0);
        run_invalid_max_length(DMA_CH1, 1);

        // Reset supplies falling transitions for the invalid-command length
        // bits and leaves every VIP agent in a clean state.
        p_sequencer.test_ctrl_vif.pulse_reset(RESET_HOLD_CYCLES);
        wait_for_infrastructure();
        p_sequencer.test_ctrl_vif.clear_all();
        wait_probe_cycles(5);
    endtask
endclass
