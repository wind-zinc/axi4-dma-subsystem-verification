class dma_subsys_expected_flow extends uvm_object;
    `uvm_object_utils(dma_subsys_expected_flow)

    dma_subsys_cmd_tr cmd;
    byte unsigned expected_data[];
    bit expected_valid[];
    bit read_seen[];
    bit write_seen[];
    bit route_granted;

    function new(string name = "dma_subsys_expected_flow");
        super.new(name);
        route_granted = 1'b0;
    endfunction

    virtual function void initialize(
        input dma_subsys_cmd_tr     source,
        input dma_subsys_ref_model model
    );
        int unsigned length;

        cmd = dma_subsys_cmd_tr::type_id::create("cmd");
        cmd.copy(source);
        length = int'(cmd.length);
        model.snapshot(
            cmd.src_addr,
            length,
            expected_data,
            expected_valid);
        read_seen = new[length];
        write_seen = new[length];
    endfunction

    virtual function int unsigned uninitialized_count();
        int unsigned count;

        count = 0;
        foreach (expected_valid[index]) begin
            if (!expected_valid[index]) begin
                count++;
            end
        end
        return count;
    endfunction

    virtual function int unsigned observed_write_count();
        int unsigned count;

        count = 0;
        foreach (write_seen[index]) begin
            if (write_seen[index]) begin
                count++;
            end
        end
        return count;
    endfunction

    virtual function int unsigned observed_read_count();
        int unsigned count;

        count = 0;
        foreach (read_seen[index]) begin
            if (read_seen[index]) begin
                count++;
            end
        end
        return count;
    endfunction

endclass

class dma_subsys_scoreboard extends uvm_component;
    `uvm_component_utils(dma_subsys_scoreboard)

    uvm_analysis_imp_intent #(
        dma_subsys_cmd_tr, dma_subsys_scoreboard) intent_imp;
    uvm_analysis_imp_cmd #(
        dma_subsys_cmd_tr, dma_subsys_scoreboard) cmd_imp;
    uvm_analysis_imp_reg #(
        dma_subsys_reg_tr, dma_subsys_scoreboard) reg_imp;
    uvm_analysis_imp_mem #(
        dma_subsys_mem_tr, dma_subsys_scoreboard) mem_imp;
    uvm_analysis_imp_route #(
        dma_subsys_route_tr, dma_subsys_scoreboard) route_imp;
    uvm_analysis_imp_completion #(
        dma_subsys_completion_tr, dma_subsys_scoreboard) completion_imp;
    uvm_analysis_imp_irq #(
        dma_subsys_irq_tr, dma_subsys_scoreboard) irq_imp;
    uvm_analysis_imp_fault #(
        dma_subsys_fault_tr, dma_subsys_scoreboard) fault_imp;
    uvm_analysis_imp_reset #(
        dma_subsys_reset_tr, dma_subsys_scoreboard) reset_imp;

    dma_subsys_ref_model ref_model;

    protected dma_subsys_cmd_tr pending_intents[$];
    protected dma_subsys_expected_flow active_flow [DMA_CH_COUNT];
    protected dma_subsys_expected_flow completed_flows[$];
    protected int owner_by_dest [DMA_CH_COUNT];

    bit require_test_intent = 1'b1;
    bit require_initialized_source = 1'b1;
    protected bit awaiting_reset_clean;

    protected longint unsigned intent_count;
    protected longint unsigned accepted_count;
    protected longint unsigned memory_count;
    protected longint unsigned completion_count;
    protected longint unsigned irq_count;
    protected longint unsigned fault_count;
    protected longint unsigned register_count;

    function new(
        string        name   = "dma_subsys_scoreboard",
        uvm_component parent = null
    );
        super.new(name, parent);
        intent_imp = new("intent_imp", this);
        cmd_imp = new("cmd_imp", this);
        reg_imp = new("reg_imp", this);
        mem_imp = new("mem_imp", this);
        route_imp = new("route_imp", this);
        completion_imp = new("completion_imp", this);
        irq_imp = new("irq_imp", this);
        fault_imp = new("fault_imp", this);
        reset_imp = new("reset_imp", this);
        awaiting_reset_clean = 1'b0;
        foreach (owner_by_dest[index]) begin
            owner_by_dest[index] = -1;
            active_flow[index] = null;
        end
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(bit)::get(
            this, "", "require_test_intent", require_test_intent));
        void'(uvm_config_db#(bit)::get(
            this, "", "require_initialized_source",
            require_initialized_source));
    endfunction

    protected function int channel_index(input dma_channel_e channel);
        case (channel)
            DMA_CH0: return 0;
            DMA_CH1: return 1;
            default: return -1;
        endcase
    endfunction

    protected function int master_channel_index(input dma_master_e master);
        case (master)
            DMA_MASTER_DMA0: return 0;
            DMA_MASTER_DMA1: return 1;
            default: return -1;
        endcase
    endfunction

    protected function bit same_command(
        input dma_subsys_cmd_tr left,
        input dma_subsys_cmd_tr right
    );
        return (left.source_ch == right.source_ch)
            && (left.dest_ch == right.dest_ch)
            && (left.src_addr == right.src_addr)
            && (left.dst_addr == right.dst_addr)
            && (left.length == right.length)
            && (left.sw_tag == right.sw_tag);
    endfunction

    virtual function void write_intent(input dma_subsys_cmd_tr tr);
        dma_subsys_cmd_tr copy;

        copy = dma_subsys_cmd_tr::type_id::create("intent_copy");
        copy.copy(tr);
        copy.record_kind = DMA_RECORD_INTENT;
        copy.ensure_flow_id();
        intent_count++;

        // Rejected software requests (disabled/busy) never cross the
        // cmd_valid/cmd_ready observation point, so there is deliberately no
        // DMA_CMD_ACCEPTED transaction for them.  They still belong in
        // functional coverage, but must not remain as unmatched scoreboard
        // work at end of test.
        if (copy.expect_accept) begin
            pending_intents.push_back(copy);
        end
    endfunction

    virtual function void write_cmd(input dma_subsys_cmd_tr tr);
        dma_subsys_cmd_tr selected;
        dma_subsys_expected_flow flow;
        int source_index;
        int matched_index;
        int unsigned unknown_bytes;

        if (tr.event_kind != DMA_CMD_ACCEPTED) begin
            return;
        end

        source_index = channel_index(tr.source_ch);
        if (source_index < 0) begin
            `uvm_error(
                "SCB_CMD",
                $sformatf("Accepted command has unknown source: %s",
                          tr.convert2string()))
            return;
        end

        matched_index = -1;
        foreach (pending_intents[index]) begin
            if (same_command(pending_intents[index], tr)) begin
                matched_index = index;
                break;
            end
        end

        if (matched_index >= 0) begin
            selected = pending_intents[matched_index];
            pending_intents.delete(matched_index);
            // Test intent owns the expected result; the accepted RTL command
            // supplies the hardware tag allocated for this exact flow.
            selected.hw_tag = tr.hw_tag;
            selected.hw_tag_valid = tr.hw_tag_valid;
        end else begin
            selected = dma_subsys_cmd_tr::type_id::create(
                "unplanned_accepted_cmd");
            selected.copy(tr);
            selected.ensure_flow_id();
            if (require_test_intent) begin
                `uvm_error(
                    "SCB_INTENT",
                    $sformatf("No test intent matched %s",
                              tr.convert2string()))
            end
        end

        if (active_flow[source_index] != null) begin
            `uvm_error(
                "SCB_CMD",
                $sformatf(
                    "Channel %0d accepted a second command before completion",
                    source_index))
            return;
        end

        flow = dma_subsys_expected_flow::type_id::create(
            $sformatf("flow_ch%0d", source_index));
        flow.initialize(selected, ref_model);
        active_flow[source_index] = flow;
        accepted_count++;

        unknown_bytes = flow.uninitialized_count();
        if (require_initialized_source
                && (flow.cmd.expected_error == DMA_ERR_NONE)
                && (unknown_bytes != 0)) begin
            `uvm_error(
                "SCB_REF_INIT",
                $sformatf(
                    "Flow %0d accepted with %0d unknown source bytes",
                    flow.cmd.flow_id, unknown_bytes))
        end
    endfunction

    virtual function void write_reg(input dma_subsys_reg_tr tr);
        register_count++;
    endfunction

    protected function dma_subsys_expected_flow find_write_flow(
        input int                 destination_index,
        input dma_subsys_mem_tr   tr
    );
        int owner;
        longint unsigned address;
        longint unsigned start_address;
        longint unsigned end_address;

        if ((destination_index < 0)
                || (destination_index >= DMA_CH_COUNT)) begin
            return null;
        end

        owner = owner_by_dest[destination_index];
        if ((owner >= 0) && (owner < DMA_CH_COUNT)
                && (active_flow[owner] != null)) begin
            return active_flow[owner];
        end

        address = ref_model.payload_address(tr, 0);
        foreach (active_flow[index]) begin
            if ((active_flow[index] != null)
                    && (channel_index(active_flow[index].cmd.dest_ch)
                        == destination_index)) begin
                start_address = longint'(active_flow[index].cmd.dst_addr);
                end_address = start_address
                    + longint'(active_flow[index].cmd.length);
                if ((address >= start_address) && (address < end_address)) begin
                    return active_flow[index];
                end
            end
        end

        // The AMD VIP publishes a complete transaction at B/R completion.
        // That publication can share a timestep with the RTL completion
        // pulse, so retain completed flows for deterministic late matching.
        for (int index = completed_flows.size() - 1;
                index >= 0; index--) begin
            if (channel_index(completed_flows[index].cmd.dest_ch)
                    == destination_index) begin
                start_address =
                    longint'(completed_flows[index].cmd.dst_addr);
                end_address = start_address
                    + longint'(completed_flows[index].cmd.length);
                if ((address >= start_address)
                        && (address < end_address)) begin
                    return completed_flows[index];
                end
            end
        end
        return null;
    endfunction

    protected function dma_subsys_expected_flow find_read_flow(
        input int                source_index,
        input dma_subsys_mem_tr  tr
    );
        longint unsigned address;
        longint unsigned start_address;
        longint unsigned end_address;

        if ((source_index >= 0) && (source_index < DMA_CH_COUNT)
                && (active_flow[source_index] != null)) begin
            return active_flow[source_index];
        end

        address = ref_model.payload_address(tr, 0);
        for (int index = completed_flows.size() - 1;
                index >= 0; index--) begin
            if (channel_index(completed_flows[index].cmd.source_ch)
                    == source_index) begin
                start_address =
                    longint'(completed_flows[index].cmd.src_addr);
                end_address = start_address
                    + longint'(completed_flows[index].cmd.length);
                if ((address >= start_address)
                        && (address < end_address)) begin
                    return completed_flows[index];
                end
            end
        end
        return null;
    endfunction

    protected function void check_dma_read(
        input dma_subsys_expected_flow flow,
        input dma_subsys_mem_tr        tr
    );
        longint unsigned address;
        longint unsigned start_address;
        longint unsigned end_address;
        int unsigned offset;

        start_address = longint'(flow.cmd.src_addr);
        end_address = start_address + longint'(flow.cmd.length);

        for (int unsigned index = 0; index < tr.data.size(); index++) begin
            if (!tr.byte_enable[index]) begin
                continue;
            end
            address = ref_model.payload_address(tr, index);
            if ((address < start_address) || (address >= end_address)) begin
                // AXI reads have no byte strobe. A legal final full-width
                // beat may contain padding bytes beyond the DMA length.
                continue;
            end

            offset = int'(address - start_address);
            flow.read_seen[offset] = 1'b1;
            if (!flow.expected_valid[offset]) begin
                if (require_initialized_source) begin
                    `uvm_error(
                        "SCB_DMA_READ_UNKNOWN",
                        $sformatf(
                            "Flow %0d read unknown reference byte at 0x%0h",
                            flow.cmd.flow_id, address))
                end
            end else if (tr.data[index] != flow.expected_data[offset]) begin
                `uvm_error(
                    "SCB_DMA_READ_DATA",
                    $sformatf(
                        "Flow %0d read mismatch at 0x%0h expected=0x%02h actual=0x%02h",
                        flow.cmd.flow_id, address,
                        flow.expected_data[offset], tr.data[index]))
            end
        end
    endfunction

    protected function void check_dma_write(
        input dma_subsys_expected_flow flow,
        input dma_subsys_mem_tr        tr
    );
        longint unsigned address;
        longint unsigned start_address;
        longint unsigned end_address;
        int unsigned offset;

        start_address = longint'(flow.cmd.dst_addr);
        end_address = start_address + longint'(flow.cmd.length);

        for (int unsigned index = 0; index < tr.data.size(); index++) begin
            if (!tr.byte_enable[index]) begin
                continue;
            end
            address = ref_model.payload_address(tr, index);
            if ((address < start_address) || (address >= end_address)) begin
                `uvm_error(
                    "SCB_DMA_WRITE_RANGE",
                    $sformatf(
                        "Flow %0d wrote address 0x%0h outside [0x%0h,0x%0h)",
                        flow.cmd.flow_id, address,
                        start_address, end_address))
                continue;
            end

            offset = int'(address - start_address);
            flow.write_seen[offset] = 1'b1;
            if (!flow.expected_valid[offset]) begin
                if (require_initialized_source) begin
                    `uvm_error(
                        "SCB_DMA_WRITE_UNKNOWN",
                        $sformatf(
                            "Flow %0d has no expected byte for 0x%0h",
                            flow.cmd.flow_id, address))
                end
            end else begin
                if (tr.data[index] != flow.expected_data[offset]) begin
                    `uvm_error(
                        "SCB_DMA_WRITE_DATA",
                        $sformatf(
                            "Flow %0d write mismatch at 0x%0h expected=0x%02h actual=0x%02h",
                            flow.cmd.flow_id, address,
                            flow.expected_data[offset], tr.data[index]))
                end

                // Preserve the independent expected state even if DUT wrote a
                // wrong byte; later reads must continue to expose the error.
                ref_model.write_byte(address, flow.expected_data[offset]);
            end
        end
    endfunction

    virtual function void write_mem(input dma_subsys_mem_tr tr);
        dma_subsys_mem_tr normalized;
        dma_subsys_expected_flow flow;
        int channel;
        int unsigned mismatches;
        int unsigned unknown_bytes;

        normalized = dma_subsys_mem_tr::type_id::create(
            "scoreboard_mem_copy");
        normalized.copy(tr);
        normalized.normalize();
        memory_count++;

        if (normalized.protocol_error) begin
            `uvm_error(
                "SCB_MEM_PROTOCOL",
                normalized.convert2string())
        end

        if (!(normalized.resp inside {DMA_AXI_OKAY, DMA_AXI_EXOKAY})) begin
            // Error response correctness is closed by completion/error checks.
            // Do not commit failed traffic into the independent memory model.
            return;
        end

        if (normalized.master inside {
                DMA_MASTER_EXT0, DMA_MASTER_EXT1}) begin
            if (normalized.access == DMA_ACCESS_WRITE) begin
                ref_model.apply_external_write(normalized);
            end else begin
                mismatches = ref_model.compare_read(
                    normalized, unknown_bytes);
                if (mismatches != 0) begin
                    `uvm_error(
                        "SCB_EXT_READ",
                        $sformatf(
                            "%0d external-read byte mismatches: %s",
                            mismatches, normalized.convert2string()))
                end
                if (unknown_bytes != 0) begin
                    `uvm_warning(
                        "SCB_EXT_READ_UNKNOWN",
                        $sformatf(
                            "%0d external-read bytes had no reference value",
                            unknown_bytes))
                end
            end
            return;
        end

        channel = master_channel_index(normalized.master);
        if (channel < 0) begin
            `uvm_error(
                "SCB_MEM_ORIGIN",
                $sformatf("Unknown memory-side master: %s",
                          normalized.convert2string()))
            return;
        end

        if (normalized.access == DMA_ACCESS_READ) begin
            flow = find_read_flow(channel, normalized);
        end else begin
            flow = find_write_flow(channel, normalized);
        end

        if (flow == null) begin
            `uvm_error(
                "SCB_MEM_FLOW",
                $sformatf(
                    "No active DMA flow matched memory transaction: %s",
                    normalized.convert2string()))
            return;
        end

        if (normalized.access == DMA_ACCESS_READ) begin
            check_dma_read(flow, normalized);
        end else begin
            check_dma_write(flow, normalized);
        end
    endfunction

    virtual function void write_route(input dma_subsys_route_tr tr);
        dma_subsys_expected_flow flow;
        int source;
        int destination;

        if ((tr.event_kind == DMA_ROUTE_RELEASED)
                && (tr.source_ch == DMA_CH_UNKNOWN)) begin
            if ((tr.route_active != '0) || (tr.route_matrix != '0)) begin
                `uvm_error(
                    "SCB_RESET_ROUTE",
                    $sformatf(
                        "Route state not idle after reset: %s",
                        tr.convert2string()))
            end
            return;
        end

        source = channel_index(tr.source_ch);
        destination = channel_index(tr.dest_ch);

        case (tr.event_kind)
            DMA_ROUTE_GRANTED: begin
                if ((source < 0) || (destination < 0)) begin
                    `uvm_error("SCB_ROUTE", tr.convert2string())
                    return;
                end
                flow = active_flow[source];
                if (flow == null) begin
                    `uvm_error(
                        "SCB_ROUTE_FLOW",
                        $sformatf(
                            "Route grant has no active source flow: %s",
                            tr.convert2string()))
                end else begin
                    flow.route_granted = 1'b1;
                    if (channel_index(flow.cmd.dest_ch) != destination) begin
                        `uvm_error(
                            "SCB_ROUTE_DEST",
                            $sformatf(
                                "Flow %0d expected destination %0d, granted %0d",
                                flow.cmd.flow_id,
                                channel_index(flow.cmd.dest_ch),
                                destination))
                    end
                end

                if ((owner_by_dest[destination] >= 0)
                        && (owner_by_dest[destination] != source)) begin
                    `uvm_error(
                        "SCB_ROUTE_OWNER",
                        $sformatf(
                            "Destination %0d already owned by source %0d",
                            destination, owner_by_dest[destination]))
                end
                owner_by_dest[destination] = source;
            end

            DMA_ROUTE_RELEASED: begin
                if ((source < 0) || (destination < 0)) begin
                    `uvm_error("SCB_ROUTE_RELEASE", tr.convert2string())
                    return;
                end
                if (owner_by_dest[destination] != source) begin
                    `uvm_error(
                        "SCB_ROUTE_RELEASE",
                        $sformatf(
                            "Source %0d released destination %0d owned by %0d",
                            source, destination,
                            owner_by_dest[destination]))
                end
                owner_by_dest[destination] = -1;
            end

            DMA_ROUTE_FAULT: begin
                fault_count++;
            end

            default: begin end
        endcase
    endfunction

    virtual function void write_completion(
        input dma_subsys_completion_tr tr
    );
        dma_subsys_expected_flow flow;
        int source;

        completion_count++;
        source = channel_index(tr.owner_ch);
        if (source < 0) begin
            `uvm_error("SCB_COMPLETION", tr.convert2string())
            return;
        end

        flow = active_flow[source];
        if (flow == null) begin
            `uvm_error(
                "SCB_COMPLETION_FLOW",
                $sformatf("Completion has no active flow: %s",
                          tr.convert2string()))
            return;
        end

        if (!tr.correlates_with(flow.cmd)) begin
            `uvm_error(
                "SCB_COMPLETION_TAG",
                $sformatf(
                    "Completion does not correlate with flow %0d: %s",
                    flow.cmd.flow_id, tr.convert2string()))
        end

        if (!flow.cmd.expect_completion) begin
            `uvm_error(
                "SCB_UNEXPECTED_COMPLETION",
                $sformatf("Flow %0d expected no completion",
                          flow.cmd.flow_id))
        end

        if (tr.error != flow.cmd.expected_error) begin
            `uvm_error(
                "SCB_COMPLETION_ERROR",
                $sformatf(
                    "Flow %0d expected error 0x%02h, observed 0x%02h",
                    flow.cmd.flow_id, flow.cmd.expected_error, tr.error))
        end

        if (flow.cmd.expected_error == DMA_ERR_NONE) begin
            if (tr.completed_len != flow.cmd.length) begin
                `uvm_error(
                    "SCB_COMPLETION_LEN",
                    $sformatf(
                        "Flow %0d expected length %0d, observed %0d",
                        flow.cmd.flow_id, flow.cmd.length,
                        tr.completed_len))
            end
            if (!flow.route_granted) begin
                `uvm_error(
                    "SCB_COMPLETION_ROUTE",
                    $sformatf(
                        "Flow %0d completed without an observed route grant",
                        flow.cmd.flow_id))
            end

        end

        completed_flows.push_back(flow);
        active_flow[source] = null;
    endfunction

    virtual function void write_irq(input dma_subsys_irq_tr tr);
        logic [DMA_CH_COUNT-1:0] expected_irq_ch;
        bit expected_global_irq;

        irq_count++;
        for (int channel = 0; channel < DMA_CH_COUNT; channel++) begin
            expected_irq_ch[channel] =
                (tr.done_pending[channel] && tr.done_enable[channel])
                || (tr.error_pending[channel]
                    && tr.error_enable[channel]);
        end
        expected_global_irq = (|expected_irq_ch)
            || (tr.fault_pending && tr.fault_enable);

        if (tr.irq_ch != expected_irq_ch) begin
            `uvm_error(
                "SCB_IRQ_CH",
                $sformatf(
                    "Expected irq_ch=%0b, observed=%0b: %s",
                    expected_irq_ch, tr.irq_ch, tr.convert2string()))
        end
        if (tr.global_irq != expected_global_irq) begin
            `uvm_error(
                "SCB_IRQ_GLOBAL",
                $sformatf(
                    "Expected irq=%0b, observed=%0b: %s",
                    expected_global_irq, tr.global_irq,
                    tr.convert2string()))
        end

        if (awaiting_reset_clean) begin
            if ((tr.busy != '0)
                    || (tr.done_pending != '0)
                    || (tr.error_pending != '0)
                    || tr.fault_pending
                    || (tr.irq_ch != '0)
                    || tr.global_irq) begin
                `uvm_error(
                    "SCB_RESET_IRQ",
                    $sformatf(
                        "IRQ/busy state not clean after reset: %s",
                        tr.convert2string()))
            end
            awaiting_reset_clean = 1'b0;
        end
    endfunction

    virtual function void write_fault(input dma_subsys_fault_tr tr);
        fault_count++;
    endfunction

    virtual function void write_reset(input dma_subsys_reset_tr tr);
        if (tr.event_kind == DMA_RESET_ASSERTED) begin
            pending_intents.delete();
            foreach (active_flow[index]) begin
                active_flow[index] = null;
                owner_by_dest[index] = -1;
            end
            awaiting_reset_clean = 1'b1;
        end
        // External RAM contents intentionally survive core reset.
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (pending_intents.size() != 0) begin
            `uvm_error(
                "SCB_PENDING_INTENT",
                $sformatf("%0d test intents were never accepted",
                          pending_intents.size()))
        end
        foreach (active_flow[index]) begin
            if (active_flow[index] != null) begin
                `uvm_error(
                    "SCB_ACTIVE_FLOW",
                    $sformatf(
                        "Channel %0d still has active flow %0d",
                        index, active_flow[index].cmd.flow_id))
            end
            if (owner_by_dest[index] >= 0) begin
                `uvm_error(
                    "SCB_ROUTE_LEAK",
                    $sformatf(
                        "Destination %0d still owned by source %0d",
                        index, owner_by_dest[index]))
            end
        end

        foreach (completed_flows[index]) begin
            if (completed_flows[index].cmd.expected_error
                    == DMA_ERR_NONE) begin
                if (completed_flows[index].observed_read_count()
                        != int'(completed_flows[index].cmd.length)) begin
                    `uvm_error(
                        "SCB_COMPLETED_READ_DATA",
                        $sformatf(
                            "Flow %0d observed %0d/%0d source bytes",
                            completed_flows[index].cmd.flow_id,
                            completed_flows[index].observed_read_count(),
                            completed_flows[index].cmd.length))
                end
                if (completed_flows[index].observed_write_count()
                        != int'(completed_flows[index].cmd.length)) begin
                    `uvm_error(
                        "SCB_COMPLETED_WRITE_DATA",
                        $sformatf(
                            "Flow %0d observed %0d/%0d destination bytes",
                            completed_flows[index].cmd.flow_id,
                            completed_flows[index].observed_write_count(),
                            completed_flows[index].cmd.length))
                end
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            "SCB_SUMMARY",
            $sformatf(
                "intent=%0d accepted=%0d mem=%0d completion=%0d irq=%0d fault=%0d reg=%0d",
                intent_count, accepted_count, memory_count,
                completion_count, irq_count, fault_count,
                register_count),
            UVM_LOW)
    endfunction

endclass
