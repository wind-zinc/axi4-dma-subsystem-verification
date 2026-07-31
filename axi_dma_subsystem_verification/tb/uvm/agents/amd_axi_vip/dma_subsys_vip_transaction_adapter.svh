// Converts complete AMD AXI VIP monitor transactions into vendor-neutral
// subsystem transactions.  No AMD transaction class leaves this component.
class dma_subsys_vip_transaction_adapter extends uvm_component;
    `uvm_component_utils(dma_subsys_vip_transaction_adapter)

    dma_subsys_vip_manager vip_mgr;

    uvm_analysis_port #(dma_subsys_reg_tr) reg_ap;
    uvm_analysis_port #(dma_subsys_mem_tr) mem_ap;

    function new(
        string        name   = "dma_subsys_vip_transaction_adapter",
        uvm_component parent = null
    );
        super.new(name, parent);
        reg_ap = new("reg_ap", this);
        mem_ap = new("mem_ap", this);
    endfunction

    protected function dma_axi_resp_e normalize_resp(
        input xil_axi_resp_t response
    );
        case (response)
            XIL_AXI_RESP_OKAY:   return DMA_AXI_OKAY;
            XIL_AXI_RESP_EXOKAY: return DMA_AXI_EXOKAY;
            XIL_AXI_RESP_SLVERR: return DMA_AXI_SLVERR;
            XIL_AXI_RESP_DECERR: return DMA_AXI_DECERR;
            default:             return DMA_AXI_DECERR;
        endcase
    endfunction

    protected function dma_burst_e normalize_burst(
        input xil_axi_burst_t burst
    );
        case (burst)
            XIL_AXI_BURST_TYPE_FIXED: return DMA_BURST_FIXED;
            XIL_AXI_BURST_TYPE_INCR:  return DMA_BURST_INCR;
            XIL_AXI_BURST_TYPE_WRAP:  return DMA_BURST_WRAP;
            default:                  return DMA_BURST_UNKNOWN;
        endcase
    endfunction

    protected function dma_subsys_reg_tr convert_register(
        input axi_monitor_transaction raw
    );
        dma_subsys_reg_tr tr;
        xil_axi_data_beat data_beat;
        xil_axi_strb_beat strb_beat;
        xil_axi_ulong address;

        tr = dma_subsys_reg_tr::type_id::create("normalized_axil");
        tr.record_kind = DMA_RECORD_OBSERVED;
        tr.producer = get_full_name();

        address = raw.get_addr();
        data_beat = raw.get_data_beat(0);
        tr.addr = address[AXIL_ADDR_WIDTH-1:0];
        tr.data = data_beat[AXIL_DATA_WIDTH-1:0];

        if (raw.get_cmd_type() == XIL_AXI_WRITE) begin
            tr.access = DMA_ACCESS_WRITE;
            strb_beat = raw.get_strb_beat(0);
            tr.strb = strb_beat[AXIL_STRB_WIDTH-1:0];
            tr.resp = normalize_resp(raw.get_bresp());
        end else begin
            tr.access = DMA_ACCESS_READ;
            tr.strb = {AXIL_STRB_WIDTH{1'b1}};
            tr.resp = normalize_resp(raw.get_rresp(0));
        end

        tr.normalize();
        tr.stamp(get_full_name());
        return tr;
    endfunction

    protected function dma_axi_resp_e aggregate_read_response(
        input axi_monitor_transaction raw
    );
        dma_axi_resp_e result;
        dma_axi_resp_e beat_response;

        result = DMA_AXI_OKAY;
        for (int beat = 0; beat <= raw.get_len(); beat++) begin
            beat_response = normalize_resp(raw.get_rresp(beat));
            if (beat_response == DMA_AXI_DECERR) begin
                result = DMA_AXI_DECERR;
            end else if ((beat_response == DMA_AXI_SLVERR)
                    && (result != DMA_AXI_DECERR)) begin
                result = DMA_AXI_SLVERR;
            end else if ((beat_response == DMA_AXI_EXOKAY)
                    && (result == DMA_AXI_OKAY)) begin
                result = DMA_AXI_EXOKAY;
            end
        end
        return result;
    endfunction

    protected function dma_subsys_mem_tr convert_memory(
        input axi_monitor_transaction raw,
        input dma_memory_e target
    );
        dma_subsys_mem_tr tr;
        xil_axi_data_beat data_beat;
        xil_axi_strb_beat strb_beat;
        xil_axi_ulong address;
        int unsigned flat_index;

        tr = dma_subsys_mem_tr::type_id::create("normalized_mem");
        tr.record_kind = DMA_RECORD_OBSERVED;
        tr.access = (raw.get_cmd_type() == XIL_AXI_WRITE)
            ? DMA_ACCESS_WRITE : DMA_ACCESS_READ;
        tr.target = target;
        tr.burst = normalize_burst(raw.get_burst());
        tr.axi_id = raw.get_id();
        address = raw.get_addr();
        tr.addr = address[AXI_ADDR_WIDTH-1:0];
        tr.beat_count = raw.get_len() + 1;
        tr.bytes_per_beat = 1 << raw.get_size();
        tr.protocol_error = (tr.burst == DMA_BURST_UNKNOWN);
        if (tr.bytes_per_beat > AXI_STRB_WIDTH) begin
            tr.protocol_error = 1'b1;
            tr.bytes_per_beat = AXI_STRB_WIDTH;
        end
        tr.data = new[tr.beat_count * tr.bytes_per_beat];
        tr.byte_enable = new[tr.data.size()];

        flat_index = 0;
        for (int beat = 0; beat < tr.beat_count; beat++) begin
            // AMD get_*_beat() already packs the significant transaction
            // bytes into the low lanes, independent of the bus lane offset.
            data_beat = raw.get_data_beat(beat);
            if (tr.access == DMA_ACCESS_WRITE) begin
                strb_beat = raw.get_strb_beat(beat);
            end
            for (int byte_index = 0;
                    byte_index < tr.bytes_per_beat; byte_index++) begin
                tr.data[flat_index] =
                    data_beat[byte_index*8 +: 8];
                tr.byte_enable[flat_index] =
                    (tr.access == DMA_ACCESS_READ)
                    ? 1'b1 : strb_beat[byte_index];
                flat_index++;
            end
        end

        if (tr.access == DMA_ACCESS_WRITE) begin
            tr.resp = normalize_resp(raw.get_bresp());
        end else begin
            tr.resp = aggregate_read_response(raw);
        end
        tr.transaction_done = 1'b1;
        tr.normalize();
        tr.stamp(get_full_name());
        return tr;
    endfunction

    protected task capture_axil();
        axi_monitor_transaction raw;
        dma_subsys_reg_tr normalized;

        forever begin
            vip_mgr.axil_cpu.monitor.item_collected_port.get(raw);
            normalized = convert_register(raw);
            reg_ap.write(normalized);
        end
    endtask

    protected task capture_mem0();
        axi_monitor_transaction raw;
        dma_subsys_mem_tr normalized;

        forever begin
            vip_mgr.mem0.monitor.item_collected_port.get(raw);
            normalized = convert_memory(raw, DMA_MEM_RAM0);
            mem_ap.write(normalized);
        end
    endtask

    protected task capture_mem1();
        axi_monitor_transaction raw;
        dma_subsys_mem_tr normalized;

        forever begin
            vip_mgr.mem1.monitor.item_collected_port.get(raw);
            normalized = convert_memory(raw, DMA_MEM_RAM1);
            mem_ap.write(normalized);
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        if (vip_mgr == null) begin
            `uvm_fatal(
                "VIP_ADAPTER",
                "dma_subsys_vip_transaction_adapter has no vip_mgr")
            return;
        end

        vip_mgr.wait_until_ready();
        fork
            capture_axil();
            capture_mem0();
            capture_mem1();
        join
    endtask

endclass
