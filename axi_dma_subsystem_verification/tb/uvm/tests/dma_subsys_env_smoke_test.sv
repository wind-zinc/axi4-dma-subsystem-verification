`default_nettype none

import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"

class dma_subsys_env_smoke_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_env_smoke_test)

    function new(
        string        name   = "dma_subsys_env_smoke_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        env.vip_mgr.wait_until_ready();
        do begin
            @(env.virtual_sequencer.probe_vif.mon_cb);
        end while (!env.virtual_sequencer.probe_vif.mon_cb.reset_n);
        repeat (5) @(env.virtual_sequencer.probe_vif.mon_cb);

        `uvm_info(
            "DMA_SUBSYS_ENV_SMOKE",
            "VIP manager, passive monitors, adapter, reference model and scoreboard started",
            UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass

`default_nettype wire
