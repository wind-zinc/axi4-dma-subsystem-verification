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
        int unsigned length,
        dma_error_e expected_error
    );
        option.per_instance = 1;
        cp_source: coverpoint source_ch;
        cp_dest: coverpoint dest_ch;
        cp_length: coverpoint length {
            bins zero = {0};
            bins tiny = {[1:16]};
            bins burst = {[17:256]};
            bins large_transfer = {[257:$]};
        }
        cp_error: coverpoint expected_error;
        cross_route: cross cp_source, cp_dest;
    endgroup

    covergroup memory_cg with function sample(
        dma_master_e master,
        dma_memory_e target,
        dma_access_e access,
        dma_axi_resp_e response
    );
        option.per_instance = 1;
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
        cp_owner: coverpoint owner_ch;
        cp_error: coverpoint error;
        cp_aborted: coverpoint aborted;
        cross_result: cross cp_owner, cp_error, cp_aborted;
    endgroup

    covergroup irq_cg with function sample(
        dma_irq_event_e event_kind,
        bit global_irq,
        logic [DMA_CH_COUNT-1:0] irq_ch
    );
        option.per_instance = 1;
        cp_event: coverpoint event_kind;
        cp_global: coverpoint global_irq;
        cp_channel: coverpoint irq_ch;
    endgroup

    protected longint unsigned intent_samples;
    protected longint unsigned register_samples;
    protected longint unsigned fault_samples;
    protected longint unsigned reset_samples;

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
        command_cg = new();
        memory_cg = new();
        route_cg = new();
        completion_cg = new();
        irq_cg = new();
    endfunction

    virtual function void write_intent(input dma_subsys_cmd_tr tr);
        intent_samples++;
    endfunction

    virtual function void write_cmd(input dma_subsys_cmd_tr tr);
        command_cg.sample(
            tr.source_ch, tr.dest_ch, tr.length, tr.expected_error);
    endfunction

    virtual function void write_reg(input dma_subsys_reg_tr tr);
        register_samples++;
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
        completion_cg.sample(tr.owner_ch, tr.error, tr.aborted);
    endfunction

    virtual function void write_irq(input dma_subsys_irq_tr tr);
        irq_cg.sample(tr.event_kind, tr.global_irq, tr.irq_ch);
    endfunction

    virtual function void write_fault(input dma_subsys_fault_tr tr);
        fault_samples++;
    endfunction

    virtual function void write_reset(input dma_subsys_reset_tr tr);
        reset_samples++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            "COV_SUMMARY",
            $sformatf(
                "command=%0.2f%% memory=%0.2f%% route=%0.2f%% completion=%0.2f%% irq=%0.2f%% intent=%0d reg=%0d fault=%0d reset=%0d",
                command_cg.get_inst_coverage(),
                memory_cg.get_inst_coverage(),
                route_cg.get_inst_coverage(),
                completion_cg.get_inst_coverage(),
                irq_cg.get_inst_coverage(),
                intent_samples, register_samples,
                fault_samples, reset_samples),
            UVM_LOW)
    endfunction

endclass
