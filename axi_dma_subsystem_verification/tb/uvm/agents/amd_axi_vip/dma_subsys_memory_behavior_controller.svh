// Applies memory-slave policy before the manager starts the AMD VIP agents.
class dma_subsys_memory_behavior_controller extends uvm_component;
    `uvm_component_utils(dma_subsys_memory_behavior_controller)

    dma_subsys_vip_manager vip_mgr;
    dma_subsys_memory_behavior_cfg cfg;

    function new(
        string        name   = "dma_subsys_memory_behavior_controller",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(dma_subsys_memory_behavior_cfg)::get(
                this, "", "dma_subsys_memory_behavior_cfg", cfg)) begin
            cfg = dma_subsys_memory_behavior_cfg::type_id::create("cfg");
        end
        cfg.validate();
    endfunction

    protected task configure_mem0_ready();
        axi_ready_gen arready;
        axi_ready_gen awready;
        axi_ready_gen wready;

        if (cfg.no_backpressure[0]) begin
            vip_mgr.mem0.set_nobackpressure_readies();
            return;
        end

        arready = new("mem0_arready");
        awready = new("mem0_awready");
        wready = new("mem0_wready");
        arready.set_ready_policy(cfg.ready_policy[0]);
        awready.set_ready_policy(cfg.ready_policy[0]);
        wready.set_ready_policy(cfg.ready_policy[0]);
        arready.set_low_time_range(
            cfg.ready_low_min[0], cfg.ready_low_max[0]);
        awready.set_low_time_range(
            cfg.ready_low_min[0], cfg.ready_low_max[0]);
        wready.set_low_time_range(
            cfg.ready_low_min[0], cfg.ready_low_max[0]);
        arready.set_high_time_range(
            cfg.ready_high_min[0], cfg.ready_high_max[0]);
        awready.set_high_time_range(
            cfg.ready_high_min[0], cfg.ready_high_max[0]);
        wready.set_high_time_range(
            cfg.ready_high_min[0], cfg.ready_high_max[0]);
        vip_mgr.mem0.rd_driver.set_arready_gen(arready);
        vip_mgr.mem0.wr_driver.set_awready_gen(awready);
        vip_mgr.mem0.wr_driver.set_wready_gen(wready);
    endtask

    protected task configure_mem1_ready();
        axi_ready_gen arready;
        axi_ready_gen awready;
        axi_ready_gen wready;

        if (cfg.no_backpressure[1]) begin
            vip_mgr.mem1.set_nobackpressure_readies();
            return;
        end

        arready = new("mem1_arready");
        awready = new("mem1_awready");
        wready = new("mem1_wready");
        arready.set_ready_policy(cfg.ready_policy[1]);
        awready.set_ready_policy(cfg.ready_policy[1]);
        wready.set_ready_policy(cfg.ready_policy[1]);
        arready.set_low_time_range(
            cfg.ready_low_min[1], cfg.ready_low_max[1]);
        awready.set_low_time_range(
            cfg.ready_low_min[1], cfg.ready_low_max[1]);
        wready.set_low_time_range(
            cfg.ready_low_min[1], cfg.ready_low_max[1]);
        arready.set_high_time_range(
            cfg.ready_high_min[1], cfg.ready_high_max[1]);
        awready.set_high_time_range(
            cfg.ready_high_min[1], cfg.ready_high_max[1]);
        wready.set_high_time_range(
            cfg.ready_high_min[1], cfg.ready_high_max[1]);
        vip_mgr.mem1.rd_driver.set_arready_gen(arready);
        vip_mgr.mem1.wr_driver.set_awready_gen(awready);
        vip_mgr.mem1.wr_driver.set_wready_gen(wready);
    endtask

    protected function void configure_mem0_model();
        vip_mgr.mem0.mem_model.set_bresp_delay_policy(
            cfg.bresp_delay_policy[0]);
        vip_mgr.mem0.mem_model.set_bresp_delay_range(
            cfg.bresp_delay_min[0], cfg.bresp_delay_max[0]);
        vip_mgr.mem0.mem_model.set_inter_beat_gap_delay_policy(
            cfg.rdata_delay_policy[0]);
        vip_mgr.mem0.mem_model.set_inter_beat_gap_range(
            cfg.rdata_delay_min[0], cfg.rdata_delay_max[0]);
        vip_mgr.mem0.mem_model.set_memory_fill_policy(
            cfg.fill_policy[0]);
        if (cfg.fill_policy[0] == XIL_AXI_MEMORY_FILL_FIXED) begin
            vip_mgr.mem0.mem_model.set_default_memory_value(
                cfg.default_fill_value[0]);
        end
    endfunction

    protected function void configure_mem1_model();
        vip_mgr.mem1.mem_model.set_bresp_delay_policy(
            cfg.bresp_delay_policy[1]);
        vip_mgr.mem1.mem_model.set_bresp_delay_range(
            cfg.bresp_delay_min[1], cfg.bresp_delay_max[1]);
        vip_mgr.mem1.mem_model.set_inter_beat_gap_delay_policy(
            cfg.rdata_delay_policy[1]);
        vip_mgr.mem1.mem_model.set_inter_beat_gap_range(
            cfg.rdata_delay_min[1], cfg.rdata_delay_max[1]);
        vip_mgr.mem1.mem_model.set_memory_fill_policy(
            cfg.fill_policy[1]);
        if (cfg.fill_policy[1] == XIL_AXI_MEMORY_FILL_FIXED) begin
            vip_mgr.mem1.mem_model.set_default_memory_value(
                cfg.default_fill_value[1]);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (vip_mgr == null) begin
            `uvm_fatal(
                "MEM_CTRL_NO_MGR",
                "Memory behavior controller has no VIP manager")
            return;
        end

        configure_mem0_model();
        configure_mem1_model();
        configure_mem0_ready();
        configure_mem1_ready();
        vip_mgr.start_agents();

        `uvm_info(
            "MEM_CTRL_READY",
            $sformatf(
                "Applied MEM0/MEM1 behavior; no-backpressure=%0b/%0b",
                cfg.no_backpressure[0], cfg.no_backpressure[1]),
            UVM_LOW)
    endtask

endclass
