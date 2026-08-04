class dma_subsys_coverage extends uvm_component;
    `uvm_component_utils(dma_subsys_coverage)

    uvm_analysis_imp_intent #(
        dma_subsys_cmd_tr, dma_subsys_coverage) intent_imp;
    uvm_analysis_imp_cmd #(
        dma_subsys_cmd_tr, dma_subsys_coverage) cmd_imp;
    uvm_analysis_imp_reg #(
        dma_subsys_reg_tr, dma_subsys_coverage) reg_imp;
    uvm_analysis_imp_mem #(
        dma_subsys_mem_tr, dma_subsys_coverage) mem_imp;
    uvm_analysis_imp_route #(
        dma_subsys_route_tr, dma_subsys_coverage) route_imp;
    uvm_analysis_imp_completion #(
        dma_subsys_completion_tr, dma_subsys_coverage) completion_imp;
    uvm_analysis_imp_irq #(
        dma_subsys_irq_tr, dma_subsys_coverage) irq_imp;
    uvm_analysis_imp_fault #(
        dma_subsys_fault_tr, dma_subsys_coverage) fault_imp;
    uvm_analysis_imp_reset #(
        dma_subsys_reset_tr, dma_subsys_coverage) reset_imp;

    covergroup command_cg with function sample(
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned length
    );
        option.per_instance = 1;
        option.name = "command_acceptance_group";
        option.comment = "Commands accepted by the DMA subsystem";
        cp_source: coverpoint source_ch;
        cp_dest: coverpoint dest_ch;
        cp_length: coverpoint length {
            bins zero = {0};
            bins tiny = {[1:16]};
            bins burst = {[17:256]};
            bins large_transfer = {[257:$]};
        }
        cross_route: cross cp_source, cp_dest;
    endgroup

    // Test intent carries the expected result.  Keep it separate from the
    // observed command: cmd_monitor reconstructs what RTL accepted and does
    // not know the test's expected error/completion/IRQ policy.
    covergroup intent_cg with function sample(
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned  length,
        dma_error_e   expected_error,
        bit           expect_accept,
        bit           expect_completion,
        bit           expect_irq
    );
        option.per_instance = 1;
        option.name = "test_intent_group";
        option.comment = "Expected command behavior published by sequences";
        cp_source: coverpoint source_ch;
        cp_dest: coverpoint dest_ch;
        cp_length: coverpoint length {
            bins zero = {0};
            bins sub_beat = {[1:3]};
            bins one_beat = {4};
            bins short = {[5:16]};
            bins one_burst = {[17:64]};
            bins multi_burst = {[65:256]};
            bins large_transfer = {[257:$]};
        }
        cp_error: coverpoint expected_error;
        cp_expect_accept: coverpoint expect_accept;
        cp_expect_completion: coverpoint expect_completion;
        cp_expect_irq: coverpoint expect_irq;
        cross_route_error: cross cp_source, cp_dest, cp_error;
    endgroup

    covergroup register_cg with function sample(
        dma_ctrl_block_e block,
        logic [AXIL_BLOCK_ADDR_WIDTH-1:0] block_offset,
        dma_access_e access,
        logic [AXIL_STRB_WIDTH-1:0] strb,
        dma_axi_resp_e response
    );
        option.per_instance = 1;
        option.name = "register_access_group";
        option.comment = "AXI-Lite register accesses and responses";
        cp_block: coverpoint block;
        cp_offset: coverpoint block_offset {
            bins offset_000 = {12'h000};
            bins offset_004 = {12'h004};
            bins offset_008 = {12'h008};
            bins offset_00c = {12'h00C};
            bins offset_010 = {12'h010};
            bins offset_014 = {12'h014};
            bins offset_018 = {12'h018};
            bins offset_01c = {12'h01C};
            bins offset_020 = {12'h020};
            bins offset_024 = {12'h024};
            bins offset_028 = {12'h028};
            bins offset_02c = {12'h02C};
            bins offset_030 = {12'h030};
            bins other = default;
        }
        cp_access: coverpoint access;
        cp_strb: coverpoint strb iff (access == DMA_ACCESS_WRITE) {
            bins none = {'0};
            bins partial = {[1:(2**AXIL_STRB_WIDTH)-2]};
            bins full = {'1};
        }
        cp_response: coverpoint response;
        cross_register_access: cross cp_block, cp_offset, cp_access;
        cross_block_response: cross cp_block, cp_access, cp_response;
    endgroup

    covergroup memory_cg with function sample(
        dma_master_e master,
        dma_memory_e target,
        dma_access_e access,
        dma_axi_resp_e response
    );
        option.per_instance = 1;
        option.name = "memory_traffic_group";
        option.comment = "Memory-side AXI traffic observed by VIP";
        cp_master: coverpoint master;
        cp_target: coverpoint target;
        cp_access: coverpoint access;
        cp_response: coverpoint response;
        cross_path: cross cp_master, cp_target, cp_access;
    endgroup

    covergroup route_cg with function sample(
        dma_route_event_e event_kind,
        dma_channel_e source_ch,
        dma_channel_e dest_ch,
        int unsigned wait_cycles
    );
        option.per_instance = 1;
        option.name = "route_arbitration_group";
        option.comment = "Route requests, grants and wait time";
        cp_event: coverpoint event_kind;
        cp_source: coverpoint source_ch;
        cp_dest: coverpoint dest_ch;
        cp_wait: coverpoint wait_cycles {
            bins immediate = {0};
            bins short_wait = {[1:4]};
            bins long_wait = {[5:$]};
        }
        cross_grant: cross cp_event, cp_source, cp_dest;
    endgroup

    covergroup completion_cg with function sample(
        dma_channel_e owner_ch,
        dma_error_e error,
        bit aborted
    );
        option.per_instance = 1;
        option.name = "completion_result_group";
        option.comment = "DMA completion owner and result";
        cp_owner: coverpoint owner_ch;
        cp_error: coverpoint error;
        cp_aborted: coverpoint aborted;
        cross_result: cross cp_owner, cp_error, cp_aborted;
    endgroup

    // Completion order is a system-level property across independent DMA
    // channels.  It is deliberately separate from AXI response ordering:
    // each current DMA engine uses one fixed AXI ID and accepts only one
    // active command, while CH0 and CH1 may complete in either issue order.
    covergroup completion_order_cg with function sample(
        dma_channel_e first_issued_ch,
        dma_channel_e completed_ch,
        bit           reordered,
        int unsigned  pending_depth
    );
        option.per_instance = 1;
        option.name = "completion_order_group";
        option.comment = "Cross-channel completion ordering";
        cp_first_issued: coverpoint first_issued_ch;
        cp_completed: coverpoint completed_ch;
        cp_reordered: coverpoint reordered {
            bins in_issue_order = {1'b0};
            bins out_of_issue_order = {1'b1};
        }
        cp_pending_depth: coverpoint pending_depth {
            bins single = {1};
            bins concurrent = {[2:$]};
        }
        cross_order: cross cp_first_issued, cp_completed, cp_reordered;
    endgroup

    covergroup irq_cg with function sample(
        dma_irq_event_e event_kind,
        bit global_irq,
        logic [DMA_CH_COUNT-1:0] irq_ch
    );
        option.per_instance = 1;
        option.name = "irq_behavior_group";
        option.comment = "Per-channel and global IRQ behavior";
        cp_event: coverpoint event_kind;
        cp_global: coverpoint global_irq;
        cp_channel: coverpoint irq_ch;
    endgroup

    protected longint unsigned intent_samples;
    protected longint unsigned register_samples;
    protected longint unsigned fault_samples;
    protected longint unsigned reset_samples;
    protected dma_channel_e issue_order[$];

    function new(
        string        name   = "dma_subsys_coverage",
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
        intent_cg = new();
        command_cg = new();
        register_cg = new();
        memory_cg = new();
        route_cg = new();
        completion_cg = new();
        completion_order_cg = new();
        irq_cg = new();
    endfunction

    virtual function void write_intent(input dma_subsys_cmd_tr tr);
        intent_samples++;
        intent_cg.sample(
            tr.source_ch,
            tr.dest_ch,
            tr.length,
            tr.expected_error,
            tr.expect_accept,
            tr.expect_completion,
            tr.expect_irq);
    endfunction

    virtual function void write_cmd(input dma_subsys_cmd_tr tr);
        command_cg.sample(tr.source_ch, tr.dest_ch, tr.length);
        if (tr.event_kind == DMA_CMD_ACCEPTED) begin
            issue_order.push_back(tr.source_ch);
        end
    endfunction

    virtual function void write_reg(input dma_subsys_reg_tr tr);
        register_samples++;
        register_cg.sample(
            tr.block,
            tr.block_offset(),
            tr.access,
            tr.strb,
            tr.resp);
    endfunction

    virtual function void write_mem(input dma_subsys_mem_tr tr);
        memory_cg.sample(tr.master, tr.target, tr.access, tr.resp);
    endfunction

    virtual function void write_route(input dma_subsys_route_tr tr);
        route_cg.sample(
            tr.event_kind, tr.source_ch, tr.dest_ch, tr.wait_cycles);
    endfunction

    virtual function void write_completion(
        input dma_subsys_completion_tr tr
    );
        dma_channel_e first_issued_ch;
        int matched_index;
        bit reordered;

        first_issued_ch = DMA_CH_UNKNOWN;
        matched_index = -1;
        reordered = 1'b0;

        if (issue_order.size() != 0) begin
            first_issued_ch = issue_order[0];
            foreach (issue_order[index]) begin
                if (issue_order[index] == tr.owner_ch) begin
                    matched_index = index;
                    break;
                end
            end
            reordered = (matched_index > 0);
        end

        completion_cg.sample(tr.owner_ch, tr.error, tr.aborted);
        completion_order_cg.sample(
            first_issued_ch,
            tr.owner_ch,
            reordered,
            issue_order.size());

        if (matched_index >= 0) begin
            issue_order.delete(matched_index);
        end
    endfunction

    virtual function void write_irq(input dma_subsys_irq_tr tr);
        irq_cg.sample(tr.event_kind, tr.global_irq, tr.irq_ch);
    endfunction

    virtual function void write_fault(input dma_subsys_fault_tr tr);
        fault_samples++;
    endfunction

    virtual function void write_reset(input dma_subsys_reset_tr tr);
        reset_samples++;
        if (tr.event_kind == DMA_RESET_ASSERTED) begin
            issue_order.delete();
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            "COV_SUMMARY",
            $sformatf(
                "intent=%0.2f%% command=%0.2f%% register=%0.2f%% memory=%0.2f%% route=%0.2f%% completion=%0.2f%% completion_order=%0.2f%% irq=%0.2f%% intent_samples=%0d reg_samples=%0d fault=%0d reset=%0d",
                intent_cg.get_inst_coverage(),
                command_cg.get_inst_coverage(),
                register_cg.get_inst_coverage(),
                memory_cg.get_inst_coverage(),
                route_cg.get_inst_coverage(),
                completion_cg.get_inst_coverage(),
                completion_order_cg.get_inst_coverage(),
                irq_cg.get_inst_coverage(),
                intent_samples, register_samples,
                fault_samples, reset_samples),
            UVM_LOW)
    endfunction

endclass
