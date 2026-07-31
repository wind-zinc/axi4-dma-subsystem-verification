class dma_subsys_env extends uvm_env;
    `uvm_component_utils(dma_subsys_env)

    dma_subsys_vip_manager              vip_mgr;
    dma_subsys_memory_behavior_controller memory_behavior_controller;
    dma_subsys_cmd_monitor              cmd_monitor;
    dma_subsys_route_monitor            route_monitor;
    dma_subsys_irq_monitor              irq_monitor;
    dma_subsys_vip_transaction_adapter  vip_transaction_adapter;
    dma_subsys_ref_model                reference_model;
    dma_subsys_scoreboard               scoreboard;
    dma_subsys_coverage                 coverage;
    dma_subsys_axil_sequencer           axil_sequencer;
    dma_subsys_axil_driver              axil_driver;
    dma_subsys_reg_block                ral;
    dma_subsys_reg_adapter              ral_adapter;
    uvm_reg_predictor #(dma_subsys_reg_tr) ral_predictor;
    dma_subsys_watchdog                 watchdog;
    dma_subsys_virtual_sequencer        virtual_sequencer;
    dma_subsys_env_cfg                  cfg;

    function new(
        string        name   = "dma_subsys_env",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(dma_subsys_env_cfg)::get(
                this, "", "dma_subsys_env_cfg", cfg)) begin
            cfg = dma_subsys_env_cfg::type_id::create("cfg");
            uvm_config_db#(dma_subsys_env_cfg)::set(
                this, "*", "dma_subsys_env_cfg", cfg);
        end

        // The memory controller applies slave policy and starts all agents.
        // Standalone VIP-manager smoke tests keep the manager's default
        // auto-start behavior because they do not instantiate this env.
        uvm_config_db#(bit)::set(
            this, "vip_mgr", "vip_auto_start", 1'b0);

        vip_mgr = dma_subsys_vip_manager::type_id::create(
            "vip_mgr", this);
        memory_behavior_controller =
            dma_subsys_memory_behavior_controller::type_id::create(
                "memory_behavior_controller", this);
        cmd_monitor = dma_subsys_cmd_monitor::type_id::create(
            "cmd_monitor", this);
        route_monitor = dma_subsys_route_monitor::type_id::create(
            "route_monitor", this);
        irq_monitor = dma_subsys_irq_monitor::type_id::create(
            "irq_monitor", this);
        vip_transaction_adapter =
            dma_subsys_vip_transaction_adapter::type_id::create(
                "vip_transaction_adapter", this);
        reference_model = dma_subsys_ref_model::type_id::create(
            "reference_model", this);
        scoreboard = dma_subsys_scoreboard::type_id::create(
            "scoreboard", this);
        coverage = dma_subsys_coverage::type_id::create(
            "coverage", this);
        axil_sequencer = dma_subsys_axil_sequencer::type_id::create(
            "axil_sequencer", this);
        axil_driver = dma_subsys_axil_driver::type_id::create(
            "axil_driver", this);
        ral = dma_subsys_reg_block::type_id::create("ral");
        ral.build();
        ral.reset();
        ral_adapter = dma_subsys_reg_adapter::type_id::create(
            "ral_adapter");
        ral_predictor =
            uvm_reg_predictor#(dma_subsys_reg_tr)::type_id::create(
                "ral_predictor", this);
        watchdog = dma_subsys_watchdog::type_id::create(
            "watchdog", this);
        virtual_sequencer =
            dma_subsys_virtual_sequencer::type_id::create(
                "virtual_sequencer", this);

        uvm_config_db#(dma_subsys_reg_block)::set(
            this, "*", "dma_subsys_ral", ral);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        vip_transaction_adapter.vip_mgr = vip_mgr;
        memory_behavior_controller.vip_mgr = vip_mgr;
        axil_driver.vip_mgr = vip_mgr;
        virtual_sequencer.vip_mgr = vip_mgr;
        virtual_sequencer.axil_sequencer = axil_sequencer;
        virtual_sequencer.ral = ral;
        virtual_sequencer.cfg = cfg;
        scoreboard.ref_model = reference_model;

        axil_driver.seq_item_port.connect(
            axil_sequencer.seq_item_export);
        ral.default_map.set_sequencer(axil_sequencer, ral_adapter);
        ral.default_map.set_auto_predict(0);
        ral_predictor.map = ral.default_map;
        ral_predictor.adapter = ral_adapter;

        virtual_sequencer.intent_ap.connect(scoreboard.intent_imp);
        virtual_sequencer.intent_ap.connect(coverage.intent_imp);

        cmd_monitor.cmd_ap.connect(scoreboard.cmd_imp);
        cmd_monitor.cmd_ap.connect(coverage.cmd_imp);

        route_monitor.route_ap.connect(scoreboard.route_imp);
        route_monitor.route_ap.connect(coverage.route_imp);

        irq_monitor.completion_ap.connect(scoreboard.completion_imp);
        irq_monitor.completion_ap.connect(coverage.completion_imp);
        irq_monitor.irq_ap.connect(scoreboard.irq_imp);
        irq_monitor.irq_ap.connect(coverage.irq_imp);
        irq_monitor.fault_ap.connect(scoreboard.fault_imp);
        irq_monitor.fault_ap.connect(coverage.fault_imp);
        irq_monitor.reset_ap.connect(scoreboard.reset_imp);
        irq_monitor.reset_ap.connect(coverage.reset_imp);

        vip_transaction_adapter.reg_ap.connect(scoreboard.reg_imp);
        vip_transaction_adapter.reg_ap.connect(coverage.reg_imp);
        vip_transaction_adapter.reg_ap.connect(ral_predictor.bus_in);
        vip_transaction_adapter.mem_ap.connect(scoreboard.mem_imp);
        vip_transaction_adapter.mem_ap.connect(coverage.mem_imp);
    endfunction

endclass
