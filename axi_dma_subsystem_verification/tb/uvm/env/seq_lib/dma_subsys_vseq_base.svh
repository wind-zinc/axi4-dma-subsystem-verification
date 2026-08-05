// Common services for subsystem virtual sequences.
//
// This class drives only public AMD VIP APIs and the virtual sequencer's
// read-only probe VIF. It contains no static testbench hierarchy reference.
class dma_subsys_vseq_base extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(dma_subsys_vseq_base)
    `uvm_declare_p_sequencer(dma_subsys_virtual_sequencer)

    function new(string name = "dma_subsys_vseq_base");
        super.new(name);
    endfunction

    protected task wait_for_infrastructure();
        if (p_sequencer == null) begin
            `uvm_fatal(
                "VSEQ_NO_SEQR",
                "dma_subsys_vseq_base requires dma_subsys_virtual_sequencer")
            return;
        end
        if (p_sequencer.vip_mgr == null) begin
            `uvm_fatal("VSEQ_NO_VIP", "Virtual sequencer has no VIP manager")
            return;
        end
        if (p_sequencer.cfg == null) begin
            `uvm_fatal(
                "VSEQ_NO_CFG",
                "Virtual sequencer has no subsystem environment config")
            return;
        end

        p_sequencer.vip_mgr.wait_until_ready();

        if (p_sequencer.probe_vif == null) begin
            `uvm_fatal("VSEQ_NO_PROBE", "Virtual sequencer has no probe VIF")
            return;
        end

        do begin
            @(p_sequencer.probe_vif.mon_cb);
        end while (!p_sequencer.probe_vif.mon_cb.reset_n);

        wait_probe_cycles(2);
    endtask

    protected task wait_probe_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(p_sequencer.probe_vif.mon_cb);
        end
    endtask

    protected task axil_write32(
        input logic [AXIL_ADDR_WIDTH-1:0] address,
        input logic [AXIL_DATA_WIDTH-1:0] value,
        input string                     operation
    );
        bit [8*8-1:0] data;
        xil_axi_resp_t response;
        bit completed;

        data = '0;
        data[AXIL_DATA_WIDTH-1:0] = value;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : axil_write_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_WRITE_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable axil_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_TIMEOUT",
                $sformatf("%s write timed out at 0x%08h",
                          operation, address))
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXIL_RESP",
                $sformatf(
                    "%s write at 0x%08h returned response %0d",
                    operation, address, response))
        end
    endtask

    protected task axil_read32(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        output logic [AXIL_DATA_WIDTH-1:0] value,
        input  string                     operation
    );
        bit [8*8-1:0] data;
        xil_axi_resp_t response;
        bit completed;

        data = '0;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : axil_read_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_READ_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable axil_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_TIMEOUT",
                $sformatf("%s read timed out at 0x%08h",
                          operation, address))
            value = '0;
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXIL_RESP",
                $sformatf(
                    "%s read at 0x%08h returned response %0d",
                    operation, address, response))
        end
        value = data[AXIL_DATA_WIDTH-1:0];
    endtask

    protected task external_write(
        input dma_master_e                    master,
        input logic [AXI_ADDR_WIDTH-1:0]      address,
        input int unsigned                    beat_count,
        input bit [8*4096-1:0]                payload,
        input string                          operation
    );
        xil_axi_data_beat [255:0] write_user;
        xil_axi_resp_t response;
        bit completed;

        if ((beat_count == 0) || (beat_count > AXI_MAX_BURST_LEN)) begin
            `uvm_fatal(
                "VSEQ_AXI_BEATS",
                $sformatf("%s requested illegal beat_count=%0d",
                          operation, beat_count))
            return;
        end

        foreach (write_user[index]) begin
            write_user[index] = '0;
        end
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : external_write_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_WRITE_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_WRITE_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_MASTER",
                            $sformatf(
                                "%s requires EXT0 or EXT1, got %0d",
                                operation, master))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable external_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_TIMEOUT",
                $sformatf("%s write timed out at 0x%08h",
                          operation, address))
            return;
        end
        if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_fatal(
                "VSEQ_AXI_RESP",
                $sformatf(
                    "%s write at 0x%08h returned response %0d",
                    operation, address, response))
        end
    endtask

    protected task external_read(
        input  dma_master_e                   master,
        input  logic [AXI_ADDR_WIDTH-1:0]     address,
        input  int unsigned                   beat_count,
        output bit [8*4096-1:0]               payload,
        output xil_axi_resp_t [255:0]         response,
        input  string                         operation
    );
        xil_axi_data_beat [255:0] read_user;
        bit completed;

        if ((beat_count == 0) || (beat_count > AXI_MAX_BURST_LEN)) begin
            `uvm_fatal(
                "VSEQ_AXI_BEATS",
                $sformatf("%s requested illegal beat_count=%0d",
                          operation, beat_count))
            return;
        end

        payload = '0;
        foreach (response[index]) begin
            response[index] = XIL_AXI_RESP_DECERR;
            read_user[index] = '0;
        end
        completed = 1'b0;

        fork : external_read_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_READ_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_READ_BURST(
                            0, address, xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'($clog2(AXI_STRB_WIDTH)),
                            XIL_AXI_BURST_TYPE_INCR,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_MASTER",
                            $sformatf(
                                "%s requires EXT0 or EXT1, got %0d",
                                operation, master))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable external_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_TIMEOUT",
                $sformatf("%s read timed out at 0x%08h",
                          operation, address))
        end
    endtask

    protected function void check_read_responses(
        input xil_axi_resp_t [255:0] response,
        input int unsigned            beat_count,
        input string                  operation
    );
        for (int unsigned beat = 0; beat < beat_count; beat++) begin
            if (response[beat] != XIL_AXI_RESP_OKAY) begin
                `uvm_error(
                    "VSEQ_AXI_RRESP",
                    $sformatf(
                        "%s beat %0d returned response %0d",
                        operation, beat, response[beat]))
            end
        end
    endfunction

    protected function logic [AXIL_ADDR_WIDTH-1:0] channel_base(
        input dma_channel_e channel
    );
        return (channel == DMA_CH1)
            ? CH1_CTRL_BASE_ADDR : CH0_CTRL_BASE_ADDR;
    endfunction

    protected function dma_master_e external_master_for_address(
        input logic [AXI_ADDR_WIDTH-1:0] address
    );
        return (address >= RAM1_BASE_ADDR)
            ? DMA_MASTER_EXT1 : DMA_MASTER_EXT0;
    endfunction

    protected function void build_linear_payload(
        output bit [8*4096-1:0] payload,
        input int unsigned      byte_count,
        input byte unsigned     seed,
        input int unsigned      start_index = 0
    );
        payload = '0;
        for (int unsigned index = 0; index < byte_count; index++) begin
            payload[index*8 +: 8] =
                byte'(seed + ((start_index + index) * 8'h1D));
        end
    endfunction

    protected task axil_write32_raw(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        input  logic [AXIL_DATA_WIDTH-1:0] value,
        output xil_axi_resp_t              response,
        input  string                      operation
    );
        bit [8*8-1:0] data;
        bit completed;

        data = '0;
        data[AXIL_DATA_WIDTH-1:0] = value;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;
        fork : raw_axil_write_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_WRITE_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable raw_axil_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_RAW_TIMEOUT",
                $sformatf("%s write timed out at 0x%08h",
                          operation, address))
        end
    endtask

    protected task axil_read32_raw(
        input  logic [AXIL_ADDR_WIDTH-1:0] address,
        output logic [AXIL_DATA_WIDTH-1:0] value,
        output xil_axi_resp_t              response,
        input  string                      operation
    );
        bit [8*8-1:0] data;
        bit completed;

        data = '0;
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;
        fork : raw_axil_read_guard
            begin
                p_sequencer.vip_mgr.axil_cpu.AXI4LITE_READ_BURST(
                    address,
                    XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                    data,
                    response);
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable raw_axil_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXIL_RAW_TIMEOUT",
                $sformatf("%s read timed out at 0x%08h",
                          operation, address))
        end
        value = data[AXIL_DATA_WIDTH-1:0];
    endtask

    protected task expect_axil_response(
        input xil_axi_resp_t actual,
        input xil_axi_resp_t expected,
        input string         operation
    );
        if (actual != expected) begin
            `uvm_error(
                "VSEQ_AXIL_EXPECT",
                $sformatf("%s expected response %0d, observed %0d",
                          operation, expected, actual))
        end
    endtask

    protected task external_write_shape(
        input dma_master_e                   master,
        input logic [AXI_ID_WIDTH-1:0]       transaction_id,
        input logic [AXI_ADDR_WIDTH-1:0]     address,
        input int unsigned                   beat_count,
        input int unsigned                   bytes_per_beat,
        input xil_axi_burst_t                burst,
        input bit [8*4096-1:0]               payload,
        input string                         operation
    );
        xil_axi_data_beat [255:0] write_user;
        xil_axi_resp_t response;
        bit completed;
        int unsigned size_code;

        if ((beat_count == 0) || (beat_count > 256)) begin
            `uvm_fatal(
                "VSEQ_AXI_SHAPE_BEATS",
                $sformatf("%s illegal beat_count=%0d",
                          operation, beat_count))
            return;
        end
        if (!(bytes_per_beat inside {1, 2, 4})) begin
            `uvm_fatal(
                "VSEQ_AXI_SHAPE_SIZE",
                $sformatf("%s illegal bytes_per_beat=%0d",
                          operation, bytes_per_beat))
            return;
        end
        size_code = $clog2(bytes_per_beat);
        foreach (write_user[index]) begin
            write_user[index] = '0;
        end
        response = XIL_AXI_RESP_DECERR;
        completed = 1'b0;

        fork : shaped_write_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_WRITE_BURST(
                            transaction_id, address,
                            xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'(size_code), burst,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_WRITE_BURST(
                            transaction_id, address,
                            xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'(size_code), burst,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, write_user, response);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_SHAPE_MASTER",
                            $sformatf("%s requires EXT0 or EXT1",
                                      operation))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable shaped_write_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_SHAPE_TIMEOUT",
                $sformatf("%s write timed out", operation))
        end else if (response != XIL_AXI_RESP_OKAY) begin
            `uvm_error(
                "VSEQ_AXI_SHAPE_RESP",
                $sformatf("%s write response=%0d", operation, response))
        end
    endtask

    protected task external_read_shape(
        input  dma_master_e                   master,
        input  logic [AXI_ID_WIDTH-1:0]       transaction_id,
        input  logic [AXI_ADDR_WIDTH-1:0]     address,
        input  int unsigned                   beat_count,
        input  int unsigned                   bytes_per_beat,
        input  xil_axi_burst_t                burst,
        output bit [8*4096-1:0]               payload,
        output xil_axi_resp_t [255:0]         response,
        input  string                         operation
    );
        xil_axi_data_beat [255:0] read_user;
        bit completed;
        int unsigned size_code;

        if ((beat_count == 0) || (beat_count > 256)) begin
            `uvm_fatal("VSEQ_AXI_SHAPE_BEATS", operation)
            return;
        end
        if (!(bytes_per_beat inside {1, 2, 4})) begin
            `uvm_fatal("VSEQ_AXI_SHAPE_SIZE", operation)
            return;
        end
        size_code = $clog2(bytes_per_beat);
        payload = '0;
        foreach (response[index]) begin
            response[index] = XIL_AXI_RESP_DECERR;
            read_user[index] = '0;
        end
        completed = 1'b0;

        fork : shaped_read_guard
            begin
                case (master)
                    DMA_MASTER_EXT0: begin
                        p_sequencer.vip_mgr.ext_m0.AXI4_READ_BURST(
                            transaction_id, address,
                            xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'(size_code), burst,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    DMA_MASTER_EXT1: begin
                        p_sequencer.vip_mgr.ext_m1.AXI4_READ_BURST(
                            transaction_id, address,
                            xil_axi_len_t'(beat_count - 1),
                            xil_axi_size_t'(size_code), burst,
                            XIL_AXI_ALOCK_NOLOCK, xil_axi_cache_t'(0),
                            XIL_AXI_PROT_NORMAL_ACCESS_MASK,
                            xil_axi_region_t'(0), xil_axi_qos_t'(0),
                            '0, payload, response, read_user);
                    end
                    default: begin
                        `uvm_fatal(
                            "VSEQ_AXI_SHAPE_MASTER",
                            $sformatf("%s requires EXT0 or EXT1",
                                      operation))
                    end
                endcase
                completed = 1'b1;
            end
            begin
                wait_probe_cycles(p_sequencer.cfg.vip_timeout_cycles);
            end
        join_any
        disable shaped_read_guard;

        if (!completed) begin
            `uvm_fatal(
                "VSEQ_AXI_SHAPE_TIMEOUT",
                $sformatf("%s read timed out", operation))
        end
    endtask

    protected task initialize_region(
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input int unsigned               byte_count,
        input byte unsigned              seed,
        input string                     operation
    );
        bit [8*4096-1:0] payload;
        int unsigned rounded_bytes;
        int unsigned offset;
        int unsigned chunk_bytes;
        int unsigned chunk_beats;

        rounded_bytes = ((byte_count + AXI_STRB_WIDTH - 1)
            / AXI_STRB_WIDTH) * AXI_STRB_WIDTH;
        offset = 0;
        while (offset < rounded_bytes) begin
            chunk_bytes = rounded_bytes - offset;
            if (chunk_bytes > (AXI_MAX_BURST_LEN * AXI_STRB_WIDTH)) begin
                chunk_bytes = AXI_MAX_BURST_LEN * AXI_STRB_WIDTH;
            end
            chunk_beats = chunk_bytes / AXI_STRB_WIDTH;
            build_linear_payload(payload, chunk_bytes, seed, offset);
            external_write(
                external_master_for_address(address + offset),
                address + offset,
                chunk_beats,
                payload,
                $sformatf("%s chunk@+0x%0h", operation, offset));
            offset += chunk_bytes;
        end
    endtask

    protected task publish_dma_intent(
        input string                     name,
        input dma_channel_e              source_ch,
        input dma_channel_e              dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input int unsigned               byte_count,
        input logic [7:0]                software_tag,
        input dma_error_e                expected_error = DMA_ERR_NONE,
        input bit                        expect_accept = 1'b1,
        input bit                        expect_completion = 1'b1,
        input bit                        expect_irq = 1'b1
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
        intent.expected_error = expected_error;
        intent.expect_accept = expect_accept;
        intent.expect_completion = expect_completion;
        intent.expect_irq = expect_irq;
        p_sequencer.publish_intent(intent);
    endtask

    protected task program_dma(
        input dma_channel_e              source_ch,
        input dma_channel_e              dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input int unsigned               byte_count,
        input logic [7:0]                software_tag
    );
        logic [AXIL_ADDR_WIDTH-1:0] base;

        base = channel_base(source_ch);
        axil_write32(base + REG_SRC_ADDR, source_address,
            $sformatf("program %s source", dma_channel_name(source_ch)));
        axil_write32(base + REG_DST_ADDR, destination_address,
            $sformatf("program %s destination", dma_channel_name(source_ch)));
        axil_write32(base + REG_LENGTH, byte_count,
            $sformatf("program %s length", dma_channel_name(source_ch)));
        axil_write32(base + REG_ROUTE,
            (dest_ch == DMA_CH1) ? 32'd1 : 32'd0,
            $sformatf("program %s route", dma_channel_name(source_ch)));
        axil_write32(base + REG_SW_TAG, {24'd0, software_tag},
            $sformatf("program %s tag", dma_channel_name(source_ch)));
    endtask

    protected task set_channel_control(
        input dma_channel_e channel,
        input bit           enable,
        input bit           start,
        input bit           abort_request,
        input bit           clear_status,
        input string        operation
    );
        logic [31:0] value;

        value = '0;
        value[0] = start;
        value[1] = abort_request;
        value[2] = enable;
        value[4] = clear_status;
        axil_write32(channel_base(channel) + REG_CTRL, value, operation);
    endtask

    protected task prepare_subsystem(
        input logic [31:0] irq_enable = 32'h4000_0303
    );
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303,
            "clear global/channel pending status");
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_ENABLE,
            irq_enable,
            "program IRQ enables");
        set_channel_control(
            DMA_CH0, 1'b1, 1'b0, 1'b0, 1'b1,
            "enable and clear CH0");
        set_channel_control(
            DMA_CH1, 1'b1, 1'b0, 1'b0, 1'b1,
            "enable and clear CH1");
        wait_probe_cycles(2);
    endtask

    protected task wait_channel_busy(
        input dma_channel_e channel,
        input bit           expected_busy = 1'b1
    );
        int unsigned index;

        index = (channel == DMA_CH1) ? 1 : 0;
        for (int unsigned cycle = 0;
                cycle < p_sequencer.cfg.status_poll_limit; cycle++) begin
            @(p_sequencer.probe_vif.mon_cb);
            if (p_sequencer.probe_vif.mon_cb.busy[index]
                    == expected_busy) begin
                return;
            end
        end
        `uvm_fatal(
            "VSEQ_BUSY_TIMEOUT",
            $sformatf("%s did not reach busy=%0b",
                      dma_channel_name(channel), expected_busy))
    endtask

    protected task wait_channel_done(
        input  dma_channel_e channel,
        output logic [31:0]  status
    );
        for (int unsigned poll = 0;
                poll < p_sequencer.cfg.status_poll_limit; poll++) begin
            axil_read32(
                channel_base(channel) + REG_STATUS,
                status,
                $sformatf("poll %s status", dma_channel_name(channel)));
            if (status[1]) begin
                return;
            end
            wait_probe_cycles(1);
        end
        `uvm_fatal(
            "VSEQ_DONE_TIMEOUT",
            $sformatf("%s completion status did not assert",
                      dma_channel_name(channel)))
    endtask

    protected task check_channel_error(
        input dma_channel_e channel,
        input dma_error_e   expected_error,
        input bit           expected_aborted,
        input string        operation
    );
        logic [31:0] status;
        logic [31:0] last_error;

        wait_channel_done(channel, status);
        axil_read32(
            channel_base(channel) + REG_LAST_ERROR,
            last_error,
            $sformatf("%s last error", operation));
        if (last_error[7:0] != expected_error) begin
            `uvm_error(
                "VSEQ_DMA_ERROR",
                $sformatf("%s expected error 0x%02h, observed 0x%02h",
                          operation, expected_error, last_error[7:0]))
        end
        if (status[4] != expected_aborted) begin
            `uvm_error(
                "VSEQ_DMA_ABORT",
                $sformatf("%s expected aborted=%0b, status=0x%08h",
                          operation, expected_aborted, status))
        end
    endtask

    protected task clear_channel_result(input dma_channel_e channel);
        set_channel_control(
            channel, 1'b1, 1'b0, 1'b0, 1'b1,
            $sformatf("clear %s result", dma_channel_name(channel)));
        axil_write32(
            GLOBAL_IRQ_BASE_ADDR + REG_IRQ_CLEAR,
            32'h4000_0303,
            "clear global/channel IRQ status");
        wait_probe_cycles(2);
    endtask

    protected task run_dma_case(
        input string                     case_name,
        input dma_channel_e              source_ch,
        input dma_channel_e              dest_ch,
        input logic [AXI_ADDR_WIDTH-1:0] source_address,
        input logic [AXI_ADDR_WIDTH-1:0] destination_address,
        input int unsigned               byte_count,
        input logic [7:0]                software_tag,
        input byte unsigned              payload_seed,
        input dma_error_e                expected_error = DMA_ERR_NONE,
        input bit                        initialize_source = 1'b1,
        input bit                        expected_aborted = 1'b0
    );
        if (initialize_source) begin
            initialize_region(
                source_address, byte_count, payload_seed,
                $sformatf("%s source initialization", case_name));
        end
        publish_dma_intent(
            $sformatf("%s_intent", case_name),
            source_ch, dest_ch, source_address, destination_address,
            byte_count, software_tag, expected_error,
            1'b1, 1'b1, 1'b1);
        program_dma(
            source_ch, dest_ch, source_address, destination_address,
            byte_count, software_tag);
        set_channel_control(
            source_ch, 1'b1, 1'b1, 1'b0, 1'b0,
            $sformatf("start %s", case_name));
        check_channel_error(
            source_ch, expected_error, expected_aborted, case_name);
        clear_channel_result(source_ch);
    endtask

endclass
