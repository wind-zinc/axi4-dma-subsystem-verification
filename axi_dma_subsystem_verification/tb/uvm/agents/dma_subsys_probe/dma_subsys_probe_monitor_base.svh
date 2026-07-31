virtual class dma_subsys_probe_monitor_base extends uvm_monitor;

    virtual dma_subsys_probe_if probe_vif;
    protected longint unsigned cycle_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cycle_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dma_subsys_probe_if)::get(
                this, "", "dma_subsys_probe_vif", probe_vif)) begin
            `uvm_fatal(
                "PROBE_VIF",
                $sformatf("%s did not receive dma_subsys_probe_vif",
                          get_full_name()))
        end
    endfunction

    protected virtual task sample_tick();
        @(probe_vif.mon_cb);
        cycle_count++;
    endtask

endclass
