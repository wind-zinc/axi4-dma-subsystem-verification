`default_nettype none
import uvm_pkg::*;
import dma_subsys_env_pkg::*;
`include "uvm_macros.svh"
class dma_subsys_abort_timing_test extends dma_subsys_base_test;
    `uvm_component_utils(dma_subsys_abort_timing_test)
    function new(string name="dma_subsys_abort_timing_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction
    virtual function void configure();
        memory_cfg.rdata_delay_min = '{6, 6};
        memory_cfg.rdata_delay_max = '{6, 6};
        memory_cfg.bresp_delay_min = '{6, 6};
        memory_cfg.bresp_delay_max = '{6, 6};
        env_cfg.status_poll_limit = 12000;
    endfunction
    virtual task run_phase(uvm_phase phase);
        dma_subsys_abort_timing_vseq sequence_h;
        phase.raise_objection(this);
        sequence_h = dma_subsys_abort_timing_vseq::type_id::create("sequence_h");
        sequence_h.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask
endclass
`default_nettype wire
