`default_nettype none

import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"

class dma_subsys_completion_reorder_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_completion_reorder_test)

    function new(
        string        name   = "dma_subsys_completion_reorder_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void configure();
        // MEM0 carries the first-issued CH0 flow.  A fixed gap on every
        // read-data beat and on the write response makes that flow
        // deterministically slower than the one-beat CH1 flow on MEM1.
        memory_cfg.rdata_delay_min[0] = 12;
        memory_cfg.rdata_delay_max[0] = 12;
        memory_cfg.bresp_delay_min[0] = 12;
        memory_cfg.bresp_delay_max[0] = 12;

        env_cfg.vip_timeout_cycles = 5000;
        env_cfg.status_poll_limit = 5000;
        env_cfg.global_watchdog_cycles = 300000;
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_completion_reorder_vseq vseq;

        phase.raise_objection(this);
        vseq = dma_subsys_completion_reorder_vseq::type_id::create(
            "vseq");
        vseq.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask

endclass

`default_nettype wire

