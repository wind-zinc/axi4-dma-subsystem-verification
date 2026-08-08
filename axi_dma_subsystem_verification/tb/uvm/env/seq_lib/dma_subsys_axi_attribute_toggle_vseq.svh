// Complements burst-shape testing with legal high/low AXI attribute values.
// DMA-generated attributes are intentionally fixed by the subsystem design;
// EXT0/EXT1 remain programmable and therefore must be covered, not waived.
class dma_subsys_axi_attribute_toggle_vseq extends dma_subsys_vseq_base;
    `uvm_object_utils(dma_subsys_axi_attribute_toggle_vseq)

    function new(string name = "dma_subsys_axi_attribute_toggle_vseq");
        super.new(name);
    endfunction

    protected task external_write_attributes(
        input dma_master_e                master,
        input logic [AXI_ID_WIDTH-1:0]    transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0]  address,
        input int unsigned                beat_count,
        input logic [3:0]                 cache,
        input logic [2:0]                 protection,
        input bit [8*4096-1:0]            payload,
        input string                      operation
    );
        xil_axi_data_beat [255:0] write_user;
        xil_axi_resp_t response;
        bit completed;

        foreach (write_user[index]) begin
            write_user[index] = '0;
        end
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : attribute_write_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_WRITE_BURST(
                            transaction_id,
                            address,
                            xil_axi_len_t'(beat_count - 1),
                            XIL_AXI_SIZE_4BYTE,
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK,
                            xil_axi_cache_t'(cache),
                            protection,
                            xil_axi_region_t'(0),
                            xil_axi_qos_t'(0),
                            '0,
                            payload,
                            write_user,
                            response);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_WRITE_BURST(
                            transaction_id,
                            address,
                            xil_axi_len_t'(beat_count - 1),
                            XIL_AXI_SIZE_4BYTE,
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK,
                            xil_axi_cache_t'(cache),
                            protection,
                            xil_axi_region_t'(0),
                            xil_axi_qos_t'(0),
                            '0,
                            payload,
                            write_user,
                            response);
                    end
                    default: begin
                        `uvm_fatal(
                            "AXI_ATTR_MASTER",
                            $sformatf("%s requires EXT0 or EXT1", operation))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable attribute_write_guard;

        if (!completed) begin
            `uvm_fatal("AXI_ATTR_WRITE_TIMEOUT", operation)
        end else if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_error(
                "AXI_ATTR_WRITE_RESP",
                $sformatf("%s response=%0d", operation, response))
        end
    endtask

    protected task external_read_attributes(
        input dma_master_e                master,
        input logic [AXI_ID_WIDTH-1:0]    transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0]  address,
        input int unsigned                beat_count,
        input logic [3:0]                 cache,
        input logic [2:0]                 protection,
        output bit [8*4096-1:0]           payload,
        output xil_axi_resp_t [255:0]     responses,
        input string                      operation
    );
        xil_axi_data_beat [255:0] read_user;
        bit completed;

        payload = '0;
        foreach (responses[index]) begin
            responses[index] = XIL_AXI_RESP_DECERR;
            read_user[index] = '0;
        end
        completed = 1'b0;

        fork : attribute_read_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_READ_BURST(
                            transaction_id,
                            address,
                            xil_axi_len_t'(beat_count - 1),
                            XIL_AXI_SIZE_4BYTE,
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK,
                            xil_axi_cache_t'(cache),
                            protection,
                            xil_axi_region_t'(0),
                            xil_axi_qos_t'(0),
                            '0,
                            payload,
                            responses,
                            read_user);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_READ_BURST(
                            transaction_id,
                            address,
                            xil_axi_len_t'(beat_count - 1),
                            XIL_AXI_SIZE_4BYTE,
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK,
                            xil_axi_cache_t'(cache),
                            protection,
                            xil_axi_region_t'(0),
                            xil_axi_qos_t'(0),
                            '0,
                            payload,
                            responses,
                            read_user);
                    end
                    default: begin
                        `uvm_fatal(
                            "AXI_ATTR_MASTER",
                            $sformatf("%s requires EXT0 or EXT1", operation))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable attribute_read_guard;

        if (!completed) begin
            `uvm_fatal("AXI_ATTR_READ_TIMEOUT", operation)
        end
    endtask

    protected task run_attribute_case(
        input dma_master_e                master,
        input logic [AXI_ID_WIDTH-1:0]    transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0]  address,
        input int unsigned                beat_count,
        input logic [3:0]                 cache,
        input logic [2:0]                 protection,
        input byte unsigned               seed,
        input string                      operation
    );
        bit [8*4096-1:0] write_payload;
        bit [8*4096-1:0] read_payload;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(
            write_payload, beat_count * AXI_STRB_WIDTH, seed);
        external_write_attributes(
            master,
            transaction_id,
            address,
            beat_count,
            cache,
            protection,
            write_payload,
            $sformatf("%s write", operation));
        external_read_attributes(
            master,
            transaction_id,
            address,
            beat_count,
            cache,
            protection,
            read_payload,
            responses,
            $sformatf("%s read", operation));
        check_read_responses(
            responses, beat_count, $sformatf("%s read", operation));
    endtask

    protected task cover_mem1_fixed_burst();
        bit [8*4096-1:0] payload;
        bit [8*4096-1:0] readback;
        xil_axi_resp_t [255:0] responses;

        build_linear_payload(payload, 16, 8'hE5);
        external_write_shape(
            DMA_MASTER_EXT1,
            4'h9,
            RAM1_BASE_ADDR + 32'h0000_6C00,
            4,
            4,
            XIL_AXI_BURST_TYPE_FIXED,
            payload,
            "MEM1 FIXED-burst cover write");
        external_read_shape(
            DMA_MASTER_EXT1,
            4'h9,
            RAM1_BASE_ADDR + 32'h0000_6C00,
            4,
            4,
            XIL_AXI_BURST_TYPE_FIXED,
            readback,
            responses,
            "MEM1 FIXED-burst cover read");
        check_read_responses(
            responses, 4, "MEM1 FIXED-burst cover read");
    endtask

    virtual task body();
        wait_for_infrastructure();

        run_attribute_case(
            DMA_MASTER_EXT0,
            4'hF,
            RAM0_BASE_ADDR + 32'h0000_AAA8,
            16,
            4'hF,
            3'b111,
            8'hA1,
            "EXT0 high attributes");
        run_attribute_case(
            DMA_MASTER_EXT0,
            4'h0,
            RAM0_BASE_ADDR + 32'h0000_5554,
            1,
            4'h0,
            3'b000,
            8'hB2,
            "EXT0 low attributes");
        run_attribute_case(
            DMA_MASTER_EXT1,
            4'hF,
            RAM1_BASE_ADDR + 32'h0000_AAA8,
            16,
            4'hF,
            3'b111,
            8'hC3,
            "EXT1 high attributes");
        run_attribute_case(
            DMA_MASTER_EXT1,
            4'h0,
            RAM1_BASE_ADDR + 32'h0000_5554,
            1,
            4'h0,
            3'b000,
            8'hD4,
            "EXT1 low attributes");
        cover_mem1_fixed_burst();

        wait_probe_cycles(5);
    endtask
endclass
