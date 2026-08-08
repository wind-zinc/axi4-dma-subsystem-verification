`default_nettype none
import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"

class dma_subsys_fsm_reset_arc_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_fsm_reset_arc_test)

    function new(
        string name = "dma_subsys_fsm_reset_arc_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void configure();
        env_cfg.vip_timeout_cycles = 20000;
        env_cfg.status_poll_limit = 200000;
        env_cfg.global_watchdog_cycles = 3000000;

        // Hold completion status long enough for WAIT_STATUS to be sampled
        // deterministically before the sequence asserts reset.
        foreach (memory_cfg.rdata_delay_min[index]) begin
            memory_cfg.rdata_delay_policy[index] =
                XIL_AXI_MEMORY_DELAY_FIXED;
            memory_cfg.rdata_delay_min[index] = 24;
            memory_cfg.rdata_delay_max[index] = 24;
            memory_cfg.bresp_delay_policy[index] =
                XIL_AXI_MEMORY_DELAY_FIXED;
            memory_cfg.bresp_delay_min[index] = 24;
            memory_cfg.bresp_delay_max[index] = 24;
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        dma_subsys_fsm_reset_arc_vseq sequence_h;

        phase.raise_objection(this);
        sequence_h =
            dma_subsys_fsm_reset_arc_vseq::type_id::create("sequence_h");
        sequence_h.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask
endclass

`default_nettype wire
