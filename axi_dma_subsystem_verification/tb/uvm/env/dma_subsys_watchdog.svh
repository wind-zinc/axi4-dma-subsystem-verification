class dma_subsys_watchdog extends uvm_component;
    `uvm_component_utils(dma_subsys_watchdog)

    dma_subsys_env_cfg cfg;
    virtual dma_subsys_probe_if probe_vif;

    function new(
        string        name   = "dma_subsys_watchdog",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(dma_subsys_env_cfg)::get(
                this, "", "dma_subsys_env_cfg", cfg)) begin
            cfg = dma_subsys_env_cfg::type_id::create("cfg");
        end
        if (!uvm_config_db#(virtual dma_subsys_probe_if)::get(
                this, "", "dma_subsys_probe_vif", probe_vif)) begin
            `uvm_fatal(
                "WATCHDOG_PROBE",
                "Global watchdog did not receive probe VIF")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (!cfg.enable_global_watchdog) begin
            return;
        end
        repeat (cfg.global_watchdog_cycles) begin
            @(probe_vif.mon_cb);
        end
        `uvm_fatal(
            "GLOBAL_WATCHDOG",
            $sformatf(
                "Test exceeded the global limit of %0d clock cycles",
                cfg.global_watchdog_cycles))
    endtask

endclass
