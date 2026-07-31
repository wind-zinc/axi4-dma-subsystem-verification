// Vendor-boundary service component for the five AMD AXI VIP agents.
//
// This class deliberately is not a uvm_agent.  AMD AXI VIP already supplies
// the protocol agents; this component owns their construction and lifecycle
// and gives the future subsystem env one stable point of access.
class dma_subsys_vip_manager extends uvm_component;
    `uvm_component_utils(dma_subsys_vip_manager)

    // Public typed handles.  Virtual sequences use the master agents to drive
    // traffic; adapter components use each agent's monitor handle.
    axil_cpu_vip_mst_t axil_cpu;
    ext_m0_vip_mst_t   ext_m0;
    ext_m1_vip_mst_t   ext_m1;
    mem0_vip_slv_mem_t mem0;
    mem1_vip_slv_mem_t mem1;

    // Static top supplies the five parameterized virtual interfaces through
    // uvm_config_db before run_test().  No package code references hierarchy.
    dma_subsys_vip_cfg vip_cfg;

    // The event remains on after trigger, so late waiters cannot miss the
    // transition.  A future virtual sequencer may retain this manager handle
    // and call wait_until_ready() before starting coordinated traffic.
    uvm_event vip_ready;

    // Configuration knobs:
    //   vip_auto_start             default 1
    //   vip_master_no_backpressure default 1
    //
    // Backpressure tests shall set vip_master_no_backpressure to 0 before
    // build_phase, then configure the individual master-agent READY policies.
    bit vip_auto_start             = 1'b1;
    bit vip_master_no_backpressure = 1'b1;

    protected bit agents_created;
    protected bit agents_started;

    function new(
        string        name   = "dma_subsys_vip_manager",
        uvm_component parent = null
    );
        super.new(name, parent);
        vip_ready = new("vip_ready");
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db#(bit)::get(
            this, "", "vip_auto_start", vip_auto_start));
        void'(uvm_config_db#(bit)::get(
            this, "", "vip_master_no_backpressure",
            vip_master_no_backpressure));

        if (!uvm_config_db#(dma_subsys_vip_cfg)::get(
                this, "", "dma_subsys_vip_cfg", vip_cfg)) begin
            `uvm_fatal(
                "VIP_MGR_CFG",
                "dma_subsys_vip_cfg was not supplied by the static testbench")
            return;
        end

        if (!vip_cfg.all_vifs_set()) begin
            `uvm_fatal(
                "VIP_MGR_CFG",
                "dma_subsys_vip_cfg contains at least one null VIF")
            return;
        end

        create_agents();
    endfunction

    // The AMD-generated constructors receive typed VIFs from vip_cfg.  The
    // static hierarchy remains confined to tb_axi_dma_core_amd_vip.
    virtual function void create_agents();
        if (agents_created) begin
            `uvm_warning(
                "VIP_MGR_CREATE",
                "create_agents() ignored because the VIP agents already exist")
            return;
        end

        axil_cpu = new(
            "axil_cpu",
            vip_cfg.axil_cpu_vif);
        ext_m0 = new(
            "ext_m0",
            vip_cfg.ext_m0_vif);
        ext_m1 = new(
            "ext_m1",
            vip_cfg.ext_m1_vif);
        mem0 = new(
            "mem0",
            vip_cfg.mem0_vif);
        mem1 = new(
            "mem1",
            vip_cfg.mem1_vif);

        axil_cpu.set_agent_tag({get_full_name(), ".axil_cpu"});
        ext_m0.set_agent_tag({get_full_name(), ".ext_m0"});
        ext_m1.set_agent_tag({get_full_name(), ".ext_m1"});
        mem0.set_agent_tag({get_full_name(), ".mem0"});
        mem1.set_agent_tag({get_full_name(), ".mem1"});

        agents_created = 1'b1;
        `uvm_info(
            "VIP_MGR_CREATE",
            "Created three AMD AXI master agents and two memory-slave agents",
            UVM_LOW)
    endfunction

    // start_slave() on the generated *_slv_mem_t agents also starts the
    // reactive read/write response loops.  Start memory responders first,
    // followed by the three traffic-producing master agents.
    virtual task start_agents();
        if (agents_started) begin
            `uvm_warning(
                "VIP_MGR_START",
                "start_agents() ignored because the VIP agents are ready")
            return;
        end

        if (!agents_created) begin
            `uvm_fatal(
                "VIP_MGR_START",
                "VIP agents were not created before start_agents()")
            return;
        end

        mem0.start_slave();
        mem1.start_slave();
        axil_cpu.start_master();
        ext_m0.start_master();
        ext_m1.start_master();

        if (vip_master_no_backpressure) begin
            axil_cpu.set_nobackpressure_readies();
            ext_m0.set_nobackpressure_readies();
            ext_m1.set_nobackpressure_readies();
        end

        agents_started = 1'b1;
        vip_ready.trigger();

        `uvm_info(
            "VIP_MGR_READY",
            $sformatf(
                "All AMD AXI VIP agents are ready; master no-backpressure=%0b",
                vip_master_no_backpressure),
            UVM_LOW)
    endtask

    // The manager does not own a run-phase objection.  The test that starts a
    // virtual sequence owns simulation lifetime and waits for this component.
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        if (vip_auto_start) begin
            start_agents();
        end
    endtask

    // wait_on() is intentionally used instead of wait_trigger(): the event's
    // persistent on-state makes this safe even if readiness was triggered
    // before the caller began waiting.
    virtual task wait_until_ready();
        if (!agents_started) begin
            vip_ready.wait_on();
        end
    endtask

    virtual function bit is_ready();
        return agents_started;
    endfunction

    virtual function void require_ready(string caller = "unknown caller");
        if (!agents_started) begin
            `uvm_fatal(
                "VIP_MGR_NOT_READY",
                $sformatf("%s accessed AMD AXI VIP before it was ready", caller))
        end
    endfunction

    // Explicit stop is provided for tests that intentionally restart the VIP.
    // Normal regressions may simply let simulator shutdown terminate the
    // vendor processes.
    virtual task stop_agents();
        if (!agents_started) begin
            return;
        end

        axil_cpu.stop_master();
        ext_m0.stop_master();
        ext_m1.stop_master();
        mem0.stop_slave();
        mem1.stop_slave();

        axil_cpu.stop_monitor();
        ext_m0.stop_monitor();
        ext_m1.stop_monitor();
        mem0.stop_monitor();
        mem1.stop_monitor();

        agents_started = 1'b0;
        vip_ready.reset();
        `uvm_info("VIP_MGR_STOP", "Stopped all AMD AXI VIP agents", UVM_LOW)
    endtask

endclass
